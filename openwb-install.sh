#!/bin/bash
OPENWBBASEDIR=/var/www/html/openWB
OPENWB_USER=openwb
OPENWB_GROUP=openwb
PYTHON_VERSION="3.10.13"  # Spezifische Python-Version für Kompatibilität

# Prüfen, ob das Script als Root ausgeführt wird
if (( $(id -u) != 0 )); then
    echo "Dieses Script muss als Benutzer Root oder mit sudo ausgeführt werden"
    exit 1
fi

echo "Installiere openWB 2 in \"${OPENWBBASEDIR}\""

# Debian-Version erkennen und prüfen auf sid/trixie
DEBIAN_VERSION_RAW=$(cat /etc/debian_version)
echo "Gefundene Debian-Version: $DEBIAN_VERSION_RAW"

# Direkte Erkennung von "trixie/sid" oder anderen Varianten
if [[ "$DEBIAN_VERSION_RAW" == "trixie/sid" ]] || [[ "$DEBIAN_VERSION_RAW" == "sid/trixie" ]]; then
    DEBIAN_VERSION="13"
    echo "Debian Trixie/Sid explizit erkannt, wird als Version 13 behandelt"
# Falls die Version eine reine Zahl ist, nehmen wir sie
elif [[ "$DEBIAN_VERSION_RAW" =~ ^[0-9]+$ ]]; then
    DEBIAN_VERSION=$DEBIAN_VERSION_RAW
# Falls "sid" oder "trixie" im String enthalten ist (case-insensitive), behandeln wir es als Debian 13
elif [[ "${DEBIAN_VERSION_RAW,,}" == *"sid"* ]] || [[ "${DEBIAN_VERSION_RAW,,}" == *"trixie"* ]]; then
    DEBIAN_VERSION="13"
    echo "Debian Sid/Trixie erkannt, wird als Version 13 behandelt"
# Ansonsten nehmen wir die erste Zahl aus dem String
else
    DEBIAN_VERSION=$(echo "$DEBIAN_VERSION_RAW" | grep -o -E '[0-9]+' | head -1)
    # Falls keine Zahl gefunden wurde, behandeln wir es als unbekannte Version
    if [[ -z "$DEBIAN_VERSION" ]]; then
        echo "Warnung: Keine Versionsnummer in '$DEBIAN_VERSION_RAW' gefunden"
        # Setzen wir einen leeren Wert, damit die spätere Prüfung fehlschlägt
        DEBIAN_VERSION=""
    fi
fi

# Funktion zur Anzeige der Warnung und Abfrage der Bestätigung
show_warning() {
    echo "*******************************************************************"
    echo "* ACHTUNG / WARNING *"
    echo "*******************************************************************"
    echo "* Sie möchten eine openWB-Installation auf einem Betriebssystem      *"
    echo "* durchführen, das nur eingeschränkt unterstützt wird. Dies ist eine *"
    echo "* openWB Community Edition ohne Support und ohne Garantie auf        *"
    echo "* Funktion.                                                         *"
    echo "* *"
    echo "* You are about to install openWB on an operating system with        *"
    echo "* limited support. This is an openWB Community Edition without       *"
    echo "* support or warranty of functionality.                              *"
    echo "*******************************************************************"
    echo ""
    echo "Um fortzufahren, geben Sie bitte 'ja' oder 'yes' ein (ohne Anführungszeichen)."
    echo "To continue, please enter 'ja' or 'yes' (without quotes)."
    echo ""
    read -p "Möchten Sie fortfahren? (ja/yes) " confirm
    if [[ "$confirm" != "ja" && "$confirm" != "yes" ]]; then
        echo "Installation abgebrochen."
        exit 1
    fi
    echo "Fortfahren mit der Installation..."
}

# Bedingte Installation basierend auf der Debian-Version
if [[ "$DEBIAN_VERSION" == "11" ]]; then
    echo "Debian 11 (Bullseye) erkannt, verwende das System-Python"
    USE_CUSTOM_PYTHON=false
    apt-get update
    apt-get install -y python3-pip
elif [[ "$DEBIAN_VERSION" == "12" ]]; then
    echo "Debian 12 (Bookworm) erkannt, baue Python 3.10"
    show_warning
    USE_CUSTOM_PYTHON=true
elif [[ "$DEBIAN_VERSION" == "13" ]]; then
    echo "Debian 13 (Trixie) erkannt, baue Python 3.10"
    show_warning
    USE_CUSTOM_PYTHON=true
else
    echo "Nicht unterstützte Debian-Version: $DEBIAN_VERSION_RAW (erkannt als: $DEBIAN_VERSION)"
    echo "Dieses Script unterstützt nur Debian 11 (Bullseye), 12 (Bookworm) oder 13 (Trixie)"
    echo ""
    echo "Falls Sie Debian Trixie/Sid verwenden, sollte dieses Script es erkennen."
    echo "Wenn Sie fortfahren möchten, geben Sie 'yes' ein:"
    read -p "Fortfahren? (yes/no) " force_continue
    if [[ "$force_continue" == "yes" ]]; then
        echo "Fahre fort mit Installation für Debian Trixie/Sid..."
        DEBIAN_VERSION="13"
        USE_CUSTOM_PYTHON=true
        show_warning
    else
        exit 1
    fi
fi

# Rest des Scripts bleibt unverändert...
# Installationspakete über ein aktualisiertes Script installieren
curl -s "https://raw.githubusercontent.com/Xerolux/OpenWB2-Bookworm-Trixie/master/runs/install_packages.sh" | bash -s
if [ $? -ne 0 ]; then
    echo "Versuche lokales install_packages.sh..."
    bash ./install_packages.sh
fi

# Python 3.10 nur für Bookworm und Trixie bauen
if $USE_CUSTOM_PYTHON; then
    echo "Baue und installiere Python ${PYTHON_VERSION}..."
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    # Python-Quelle herunterladen und extrahieren
    wget "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
    tar -xf "Python-${PYTHON_VERSION}.tgz"
    cd "Python-${PYTHON_VERSION}"

    # Python konfigurieren und bauen
    ./configure --enable-optimizations --with-ensurepip=install
    make -j $(nproc)
    make altinstall

    # Aufräumen
    cd /
    rm -rf "$TEMP_DIR"

    # Symlinks für die neue Python-Version erstellen
    ln -sf "/usr/local/bin/python3.10" "/usr/local/bin/python3"
    ln -sf "/usr/local/bin/pip3.10" "/usr/local/bin/pip3"

    echo "Python ${PYTHON_VERSION} erfolgreich installiert"
fi

echo "Erstelle Gruppe $OPENWB_GROUP"
# Macht nichts, wenn die Gruppe bereits existiert
/usr/sbin/groupadd "$OPENWB_GROUP"
echo "Fertig"

echo "Erstelle Benutzer $OPENWB_USER"
# Macht nichts, wenn der Benutzer bereits existiert
/usr/sbin/useradd "$OPENWB_USER" -g "$OPENWB_GROUP" --create-home
echo "Fertig"

# Sudo-Rechte für den Benutzer hinzufügen
echo "$OPENWB_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/openwb
chmod 440 /etc/sudoers.d/openwb
echo "Fertig"

echo "Prüfe initialen Git-Clone..."
if [ ! -d "${OPENWBBASEDIR}/web" ]; then
    mkdir -p "$OPENWBBASEDIR"
    chown "$OPENWB_USER:$OPENWB_GROUP" "$OPENWBBASEDIR"
    sudo -u "$OPENWB_USER" git clone https://github.com/Xerolux/OpenWB2-Bookworm-Trixie.git --branch master "$OPENWBBASEDIR"
    echo "Git aus dem Benutzer-Repository geklont"
else
    echo "OK"
fi

echo -n "Prüfe Ramdisk... "
if grep -Fq "tmpfs ${OPENWBBASEDIR}/ramdisk" /etc/fstab; then
    echo "OK"
else
    mkdir -p "${OPENWBBASEDIR}/ramdisk"
    sudo tee -a "/etc/fstab" <"${OPENWBBASEDIR}/data/config/ramdisk_config.txt" >/dev/null
    mount -a
    echo "Erstellt"
fi

echo -n "Prüfe Crontab... "
if [ ! -f /etc/cron.d/openwb ]; then
    cp "${OPENWBBASEDIR}/data/config/openwb.cron" /etc/cron.d/openwb
    echo "Installiert"
else
    echo "OK"
fi

# Mosquitto-Konfiguration
echo "Aktualisiere Mosquitto-Konfigurationsdatei"
systemctl stop mosquitto
sleep 2
cp -a "${OPENWBBASEDIR}/data/config/mosquitto/mosquitto.conf" /etc/mosquitto/mosquitto.conf
mkdir -p /etc/mosquitto/conf.d
cp "${OPENWBBASEDIR}/data/config/mosquitto/openwb.conf" /etc/mosquitto/conf.d/openwb.conf
cp "${OPENWBBASEDIR}/data/config/mosquitto/mosquitto.acl" /etc/mosquitto/mosquitto.acl

mkdir -p /etc/mosquitto/certs
sudo cp /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/mosquitto/certs/openwb.pem
sudo cp /etc/ssl/private/ssl-cert-snakeoil.key /etc/mosquitto/certs/openwb.key
sudo chgrp mosquitto /etc/mosquitto/certs/openwb.key
systemctl start mosquitto

# Mosquitto_local Instanz
if [ ! -f /etc/init.d/mosquitto_local ]; then
    echo "Richte lokale Mosquitto-Instanz ein"
    install -d -m 0755 -o root -g root /etc/mosquitto/conf_local.d/
    install -d -m 0755 -o mosquitto -g root /var/lib/mosquitto_local
    cp "${OPENWBBASEDIR}/data/config/mosquitto/mosquitto_local_init" /etc/init.d/mosquitto_local
    chown root:root /etc/init.d/mosquitto_local
    chmod 755 /etc/init.d/mosquitto_local
    systemctl daemon-reload
    systemctl enable mosquitto_local
else
    systemctl stop mosquitto_local
    sleep 2
fi
cp -a "${OPENWBBASEDIR}/data/config/mosquitto/mosquitto_local.conf" /etc/mosquitto/mosquitto_local.conf
cp -a "${OPENWBBASEDIR}/data/config/mosquitto/openwb_local.conf" /etc/mosquitto/conf_local.d/
systemctl start mosquitto_local
echo "Mosquitto fertig"

# Apache-Konfiguration
echo -n "Konfiguriere Apache..."
cp "${OPENWBBASEDIR}/data/config/apache/000-default.conf" "/etc/apache2/sites-available/"
cp "${OPENWBBASEDIR}/index.html" /var/www/html/index.html
echo "Fertig"

echo -n "Passe Upload-Limit an..."
if [ -d "/etc/php/7.3/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/7.3/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/7.3/apache2/conf.d/20-uploadlimit.ini
    echo "Fertig (PHP 7.3 - OS Buster)"
elif [ -d "/etc/php/7.4/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/7.4/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/7.4/apache2/conf.d/20-uploadlimit.ini
    echo "Fertig (PHP 7.4 - OS Bullseye)"
elif [ -d "/etc/php/8.2/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/8.2/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/8.2/apache2/conf.d/20-uploadlimit.ini
    echo "Fertig (PHP 8.2 - OS Bookworm)"
elif [ -d "/etc/php/8.3/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/8.3/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/8.3/apache2/conf.d/20-uploadlimit.ini
    echo "Fertig (PHP 8.3 - OS Trixie)"
elif [ -d "/etc/php/8.4/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/8.4/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/8.4/apache2/conf.d/20-uploadlimit.ini
    echo "Fertig (PHP 8.4)"
else
    echo "Keine unterstützte PHP-Version gefunden, überspringe Upload-Limit-Konfiguration"
fi

echo -n "Aktiviere Apache SSL-Modul..."
a2enmod ssl
a2enmod proxy_wstunnel
a2dissite default-ssl 2>/dev/null || true
cp "${OPENWBBASEDIR}/data/config/apache/apache-openwb-ssl.conf" /etc/apache2/sites-available/
a2ensite apache-openwb-ssl
echo "Fertig"

echo -n "Starte Apache neu..."
systemctl restart apache2
echo "Fertig"

# Python-Pfad und Executable basierend auf der Version festlegen
if $USE_CUSTOM_PYTHON; then
    PYTHON_PATH="/usr/local/bin"
    PYTHON_EXEC="/usr/local/bin/python3"
    echo "Installiere Python-Anforderungen mit benutzerdefiniertem Python ${PYTHON_VERSION}..."
else
    PYTHON_PATH="/usr/bin"
    PYTHON_EXEC="/usr/bin/python3"
    echo "Installiere Python-Anforderungen mit System-Python..."
fi

# Python-Anforderungen installieren
PATH="$PYTHON_PATH:$PATH" pip3 install --upgrade pip
sudo -u "$OPENWB_USER" PATH="$PYTHON_PATH:$PATH" pip3 install -r "${OPENWBBASEDIR}/requirements.txt"

echo "Installiere openWB2-Systemdienst..."
# Dienstdatei mit der passenden Python-Version aktualisieren
sed -i "s|ExecStart=.*|ExecStart=$PYTHON_EXEC -m openWB.run|" "${OPENWBBASEDIR}/data/config/openwb2.service"
ln -sf "${OPENWBBASEDIR}/data/config/openwb2.service" /etc/systemd/system/openwb2.service
systemctl daemon-reload
systemctl enable openwb2

echo "Installiere openWB2-Remote-Support-Dienst..."
# Dienstdatei mit der passenden Python-Version aktualisieren
sed -i "s|ExecStart=.*python|ExecStart=$PYTHON_EXEC|" "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service"
cp "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service" /etc/systemd/system/openwbRemoteSupport.service
systemctl daemon-reload
systemctl enable openwbRemoteSupport
systemctl start openwbRemoteSupport

echo "Installation abgeschlossen, starte jetzt den openWB2-Dienst..."
systemctl start openwb2

echo "Alles fertig!"
echo "Falls Sie diese Installation für Entwicklungsarbeiten nutzen möchten, setzen Sie ein Passwort für den Benutzer 'openwb' mit: sudo passwd openwb"
if $USE_CUSTOM_PYTHON; then
    echo "Python ${PYTHON_VERSION} wurde speziell für openWB-Kompatibilität installiert"
fi
