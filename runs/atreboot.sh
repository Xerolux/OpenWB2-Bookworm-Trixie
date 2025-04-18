#!/bin/bash
OPENWBBASEDIR=/var/www/html/openWB
OPENWB_USER=openwb
OPENWB_GROUP=openwb
VENV_DIR="${OPENWBBASEDIR}/venv"

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

# Setze USE_VENV basierend auf der Debian-Version
if [[ "$DEBIAN_VERSION" == "12" || "$DEBIAN_VERSION" == "13" || "$DEBIAN_VERSION" == "unstable" ]]; then
    USE_VENV=true
else
    USE_VENV=false
fi

# Installiere zusätzliche Build-Tools für Debian 12, 13 und unstable
if [[ "$DEBIAN_VERSION" == "12" || "$DEBIAN_VERSION" == "13" || "$DEBIAN_VERSION" == "unstable" ]]; then
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

# Zeige Warnung für Debian 12, 13 und unstable
if [[ "$DEBIAN_VERSION" == "12" || "$DEBIAN_VERSION" == "13" || "$DEBIAN_VERSION" == "unstable" ]]; then
    show_warning
fi

# Installationspakete über ein aktualisiertes Script installieren
curl -s "https://raw.githubusercontent.com/Xerolux/OpenWB2-Bookworm-Trixie/master/runs/install_packages.sh" | bash -s
if [ $? -ne 0 ]; then
    echo "Versuche lokales install_packages.sh..."
    bash ./install_packages.sh
fi

# Setze PYTHON_EXEC und PIP_EXEC
if $USE_VENV; then
    if [ ! -d "$VENV_DIR" ]; then
        echo "Erstelle virtuelle Umgebung in ${VENV_DIR}..."
        sudo -u "$OPENWB_USER" /usr/bin/python3 -m venv "$VENV_DIR"
        echo "Virtuelle Umgebung erstellt."
    fi
    PYTHON_EXEC="$VENV_DIR/bin/python"
    PIP_EXEC="$VENV_DIR/bin/pip"
else
    PYTHON_EXEC="/usr/bin/python3"
    PIP_EXEC="/usr/bin/pip3"
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

# Python-Anforderungen installieren
echo "Aktualisiere pip..."
if $USE_VENV; then
    sudo -u "$OPENWB_USER" "$PIP_EXEC" install --upgrade pip
else
    sudo -u "$OPENWB_USER" "$PIP_EXEC" install --user --upgrade pip
fi

echo "Installiere Python-Abhängigkeiten..."
# Prüfe, ob requirements.txt existiert
if [ ! -f "${OPENWBBASEDIR}/requirements.txt" ]; then
    echo "Fehler: requirements.txt nicht gefunden in ${OPENWBBASEDIR}"
    exit 1
fi

if $USE_VENV; then
    sudo -u "$OPENWB_USER" "$PIP_EXEC" install -r "${OPENWBBASEDIR}/requirements.txt"
else
    sudo -u "$OPENWB_USER" "$PIP_EXEC" install --user -r "${OPENWBBASEDIR}/requirements.txt"
fi

echo "Installiere openWB2-Systemdienst..."
# Dienstdatei mit der passenden Python-Version aktualisieren
sed -i "s|ExecStart=.*|ExecStart=$PYTHON_EXEC -m openWB.run|" "${OPENWBBASEDIR}/data/config/openwb2.service"
if ! $USE_VENV; then
    PYTHON_MAJOR_MINOR=$("$PYTHON_EXEC" --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    sed -i "/ExecStart=/i Environment=\"PYTHONPATH=/home/$OPENWB_USER/.local/lib/python${PYTHON_MAJOR_MINOR}/site-packages\"" "${OPENWBBASEDIR}/data/config/openwb2.service"
fi
ln -sf "${OPENWBBASEDIR}/data/config/openwb2.service" /etc/systemd/system/openwb2.service
systemctl daemon-reload
systemctl enable openwb2

echo "Installiere openWB2-Remote-Support-Dienst..."
# Dienstdatei mit der passenden Python-Version aktualisieren
sed -i "s|ExecStart=.*python|ExecStart=$PYTHON_EXEC|" "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service"
if ! $USE_VENV; then
    sed -i "/ExecStart=/i Environment=\"PYTHONPATH=/home/$OPENWB_USER/.local/lib/python${PYTHON_MAJOR_MINOR}/site-packages\"" "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service"
fi
cp "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service" /etc/systemd/system/openwbRemoteSupport.service
systemctl daemon-reload
systemctl enable openwbRemoteSupport
systemctl start openwbRemoteSupport

echo "Installation abgeschlossen, starte jetzt den openWB2-Dienst..."
systemctl start openwb2

echo "Alles fertig!"
echo "Falls Sie diese Installation für Entwicklungsarbeiten nutzen möchten, setzen Sie ein Passwort für den Benutzer 'openwb' mit: sudo passwd openwb"
