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

# Debian-Version oder Codename erkennen
DEBIAN_VERSION="unknown"
DEBIAN_CODENAME=""

# Zuerst /etc/os-release prüfen (zuverlässiger für moderne Systeme)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DEBIAN_CODENAME=$VERSION_CODENAME
    case "$DEBIAN_CODENAME" in
        "bullseye")
            DEBIAN_VERSION="11"
            ;;
        "bookworm")
            DEBIAN_VERSION="12"
            ;;
        "trixie")
            DEBIAN_VERSION="13"
            ;;
        "sid")
            DEBIAN_VERSION="unstable"
            ;;
        *)
            DEBIAN_VERSION="unknown"
            ;;
    esac
fi

# Fallback auf /etc/debian_version, falls /etc/os-release nicht eindeutig oder nicht vorhanden
if [[ "$DEBIAN_VERSION" == "unknown" && -f /etc/debian_version ]]; then
    DEBIAN_VERSION_RAW=$(cat /etc/debian_version)
    case "$DEBIAN_VERSION_RAW" in
        "11"|"11."*)
            DEBIAN_VERSION="11"
            DEBIAN_CODENAME="bullseye"
            ;;
        "12"|"12."*)
            DEBIAN_VERSION="12"
            DEBIAN_CODENAME="bookworm"
            ;;
        "13"|"13."*)
            DEBIAN_VERSION="13"
            DEBIAN_CODENAME="trixie"
            ;;
        "trixie/sid")
            DEBIAN_VERSION="13"  # Trixie als Debian 13 behandeln
            DEBIAN_CODENAME="trixie"
            ;;
        "sid")
            DEBIAN_VERSION="unstable"
            DEBIAN_CODENAME="sid"
            ;;
        *)
            DEBIAN_VERSION="unknown"
            ;;
    esac
fi

# Fehler, wenn keine Version erkannt wurde
if [[ "$DEBIAN_VERSION" == "unknown" ]]; then
    echo "Fehler: Debian-Version konnte nicht erkannt werden."
    echo "Unterstützte Versionen: Debian 11 (Bullseye), 12 (Bookworm), 13 (Trixie), Unstable (Sid)"
    exit 1
fi

echo "Erkannte Debian-Version: $DEBIAN_VERSION (Codename: $DEBIAN_CODENAME)"

# Zusätzliche Build-Tools für Debian 12, 13 und 14 installieren
if [[ "$DEBIAN_VERSION" == "12" || "$DEBIAN_VERSION" == "13" || "$DEBIAN_VERSION" == "14" ]]; then
    echo "Installiere zusätzliche Build-Tools für Debian $DEBIAN_VERSION..."
    apt-get update
    apt-get install -y autoconf automake build-essential libtool
    echo "Zusätzliche Build-Tools erfolgreich installiert."
fi

# Installiere notwendige Netzwerk- und Firewall-Pakete
echo "Installiere notwendige Netzwerk- und Firewall-Pakete..."
apt-get install -y iptables dhcpcd5 dnsmasq
echo "Pakete erfolgreich installiert."

# Funktion zur Anzeige der Warnung mit 10 Sekunden Verzögerung
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
    echo "Installation wird in 10 Sekunden fortgesetzt..."
    sleep 10
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
elif [[ "$DEBIAN_VERSION" == "unstable" ]]; then
    echo "Debian Unstable (Sid) erkannt, baue Python 3.10 (experimentell)"
    show_warning
    USE_CUSTOM_PYTHON=true
else
    echo "Nicht unterstützte Debian-Version: $DEBIAN_VERSION (Codename: $DEBIAN_CODENAME)"
    echo "Dieses Script unterstützt nur Debian 11 (Bullseye), 12 (Bookworm), 13 (Trixie) oder Unstable (Sid)"
    exit 1
fi

# Installationspakete über ein aktualisiertes Script installieren
curl -s "https://raw.githubusercontent.com/Xerolux/OpenWB2-Bookworm-Trixie/master/runs/install_packages.sh" | bash -s
if [ $? -ne 0 ]; then
    echo "Versuche lokales install_packages.sh..."
    bash ./install_packages.sh
fi

# Python 3.10 nur für Bookworm, Trixie und Sid bauen, falls nicht bereits installiert
if $USE_CUSTOM_PYTHON; then
    PYTHON_BINARY="/usr/local/bin/python${PYTHON_VERSION%.*}"  # z. B. /usr/local/bin/python3.10
    if [ -x "$PYTHON_BINARY" ] && "$PYTHON_BINARY" --version | grep -q "$PYTHON_VERSION"; then
        echo "Python ${PYTHON_VERSION} ist bereits installiert, überspringe Installation."
    else
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
        ln -sf "/usr/local/bin/python${PYTHON_VERSION%.*}" "/usr/local/bin/python3"
        ln -sf "/usr/local/bin/pip${PYTHON_VERSION%.*}" "/usr/local/bin/pip3"

        echo "Python ${PYTHON_VERSION} erfolgreich installiert"
    fi
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
    PIP_EXEC="/usr/local/bin/pip3"
    echo "Installiere Python-Anforderungen mit benutzerdefiniertem Python ${PYTHON_VERSION}..."
else
    PYTHON_PATH="/usr/bin"
    PYTHON_EXEC="/usr/bin/python3"
    PIP_EXEC="/usr/bin/pip3"
    echo "Installiere Python-Anforderungen mit System-Python..."
fi

# Python-Anforderungen installieren
echo "Aktualisiere pip..."
sudo -u "$OPENWB_USER" PATH="$PYTHON_PATH:$PATH" $PIP_EXEC install --upgrade pip

echo "Installiere Python-Abhängigkeiten..."
# Prüfe, ob requirements.txt existiert
if [ ! -f "${OPENWBBASEDIR}/requirements.txt" ]; then
    echo "Fehler: requirements.txt nicht gefunden in ${OPENWBBASEDIR}"
    exit 1
fi

if [[ "$DEBIAN_VERSION" == "12" || "$DEBIAN_VERSION" == "13" || "$DEBIAN_VERSION" == "unstable" ]]; then
    echo "Für Debian $DEBIAN_VERSION: Installiere Abhängigkeiten aus requirements.txt zusammen mit der neuesten Version von jq..."
    # Erstelle eine temporäre requirements-Liste im Home-Verzeichnis von openwb
    TEMP_REQ="/home/$OPENWB_USER/temp_requirements.txt"
    sudo -u "$OPENWB_USER" bash -c "grep -v '^jq' ${OPENWBBASEDIR}/requirements.txt > $TEMP_REQ"
    sudo -u "$OPENWB_USER" bash -c "echo 'jq' >> $TEMP_REQ"
    # Debugging: Zeige den Inhalt der temporären Datei
    echo "Inhalt der temporären requirements.txt:"
    sudo -u "$OPENWB_USER" cat "$TEMP_REQ"
    # Installiere die Abhängigkeiten
    sudo -u "$OPENWB_USER" PATH="$PYTHON_PATH:$PATH" $PIP_EXEC install --user -r "$TEMP_REQ"
    # Prüfe, ob jq installiert wurde
    if ! sudo -u "$OPENWB_USER" PATH="$PYTHON_PATH:$PATH" $PIP_EXEC show jq > /dev/null; then
        echo "Fehler: Python-Paket jq konnte nicht installiert werden"
        # Versuche, jq separat zu installieren, um den Fehler zu identifizieren
        echo "Versuche, jq separat zu installieren..."
        sudo -u "$OPENWB_USER" PATH="$PYTHON_PATH:$PATH" $PIP_EXEC install --user jq
        if [ $? -ne 0 ]; then
            echo "Fehler: Installation von jq fehlgeschlagen"
            exit 1
        fi
    fi
    rm -f "$TEMP_REQ"
else
    echo "Installiere Abhängigkeiten aus requirements.txt..."
    sudo -u "$OPENWB_USER" PATH="$PYTHON_PATH:$PATH" $PIP_EXEC install --user -r "${OPENWBBASEDIR}/requirements.txt"
    # Prüfe, ob jq installiert wurde
    if ! sudo -u "$OPENWB_USER" PATH="$PYTHON_PATH:$PATH" $PIP_EXEC show jq > /dev/null; then
        echo "Fehler: Python-Paket jq konnte nicht installiert werden"
        exit 1
    fi
fi

echo "Installiere openWB2-Systemdienst..."
# Dienstdatei mit der passenden Python-Version aktualisieren
sed -i "s|ExecStart=.*|ExecStart=$PYTHON_EXEC -m openWB.run|" "${OPENWBBASEDIR}/data/config/openwb2.service"
# Setze PYTHONPATH für den Dienst
sed -i "/ExecStart=/i Environment=\"PYTHONPATH=/home/$OPENWB_USER/.local/lib/python3.10/site-packages\"" "${OPENWBBASEDIR}/data/config/openwb2.service"
ln -sf "${OPENWBBASEDIR}/data/config/openwb2.service" /etc/systemd/system/openwb2.service
systemctl daemon-reload
systemctl enable openwb2

echo "Installiere openWB2-Remote-Support-Dienst..."
# Dienstdatei mit der passenden Python-Version aktualisieren
sed -i "s|ExecStart=.*python|ExecStart=$PYTHON_EXEC|" "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service"
# Setze PYTHONPATH für den Dienst
sed -i "/ExecStart=/i Environment=\"PYTHONPATH=/home/$OPENWB_USER/.local/lib/python3.10/site-packages\"" "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service"
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
