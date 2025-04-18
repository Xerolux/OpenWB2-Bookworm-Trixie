#!/bin/bash
OPENWBBASEDIR=/var/www/html/openWB
OPENWB_USER=openwb
OPENWB_GROUP=openwb
VENV_DIR="${OPENWBBASEDIR}/venv"
TEMP_REQ="/home/$OPENWB_USER/temp_requirements.txt"

# Lösche temporäre Datei bei Skript-Abbruch
trap 'rm -f "$TEMP_REQ"' EXIT

# Prüfen, ob das Script als Root ausgeführt wird
if (( $(id -u) != 0 )); then
    echo "this script has to be run as user root or with sudo"
    exit 1
fi

echo "installing openWB 2 into \"${OPENWBBASEDIR}\""

# Setze UTF-8 Locale und Zeitzone Berlin
echo "Setze UTF-8 Locale und Zeitzone Europe/Berlin..."
if ! locale -a | grep -q "de_DE.utf8"; then
    echo "Generiere de_DE.UTF-8 Locale..."
    apt-get update
    apt-get install -y locales
    locale-gen de_DE.UTF-8
fi
update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8
timedatectl set-timezone Europe/Berlin
echo "Locale und Zeitzone erfolgreich gesetzt."

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

# Fallback auf /etc/debian_version
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
            DEBIAN_VERSION="13"
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

# Erweitere Dateisystem auf Raspberry Pi
if [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model; then
    echo "Erkenne Raspberry Pi, erweitere Dateisystem..."
    if command -v raspi-config >/dev/null; then
        raspi-config nonint do_expand_rootfs
        echo "Dateisystem mit raspi-config erfolgreich erweitert."
    else
        echo "raspi-config nicht gefunden, versuche manuelle Erweiterung..."
        ROOT_PART=$(mount | grep "on / " | awk '{print $1}' | sed 's/p[0-9]$//')
        ROOT_PART_NUM=$(mount | grep "on / " | awk '{print $1}' | grep -o '[0-9]$')
        if [ -n "$ROOT_PART" ] && [ -n "$ROOT_PART_NUM" ]; then
            echo -e "d\n$ROOT_PART_NUM\nn\np\n$ROOT_PART_NUM\n\n\nw" | fdisk "$ROOT_PART"
            partprobe
            resize2fs "${ROOT_PART}p${ROOT_PART_NUM}"
            echo "Dateisystem manuell erfolgreich erweitert."
        else
            echo "Fehler: Root-Partition konnte nicht erkannt werden, überspringe Erweiterung."
        fi
    fi
else
    echo "Kein Raspberry Pi erkannt, überspringe Dateisystemerweiterung."
fi

# Installiere python3-pip für Debian 11
if [[ "$DEBIAN_VERSION" == "11" ]]; then
    echo "Installiere python3-pip für Debian 11..."
    apt-get update
    apt-get install -y python3-pip
    echo "python3-pip erfolgreich installiert."
fi

# Installationspakete über Script installieren
curl -s "https://raw.githubusercontent.com/Xerolux/OpenWB2-Bookworm-Trixie/master/runs/install_packages.sh" | bash -s
if [ $? -ne 0 ]; then
    echo "Versuche lokales install_packages.sh..."
    bash ./install_packages.sh
fi

# Installiere Build-Tools und python3-dev für Debian 12, 13 und unstable
if [[ "$DEBIAN_VERSION" == "12" || "$DEBIAN_VERSION" == "13" || "$DEBIAN_VERSION" == "unstable" ]]; then
    echo "Installiere Build-Tools und python3-dev für Debian $DEBIAN_VERSION..."
    apt-get update
    apt-get install -y autoconf automake build-essential libtool python3-dev
    echo "Build-Tools und python3-dev erfolgreich installiert."
fi

# Installiere libxml2, libxslt und Entwicklungspakete für Debian 12, 13, 14 und höher
if [[ "$DEBIAN_VERSION" =~ ^[0-9]+$ ]] && [[ "$DEBIAN_VERSION" -ge 12 ]]; then
    echo "Installiere libxml2, libxslt und Entwicklungspakete für Debian $DEBIAN_VERSION..."
    apt-get install -y libxml2 libxslt1.1 libxml2-dev libxslt1-dev
    echo "libxml2, libxslt und Entwicklungspakete erfolgreich installiert."
fi

# Installiere Netzwerk- und Firewall-Pakete
echo "Installiere Netzwerk- und Firewall-Pakete..."
apt-get install -y iptables dhcpcd5 dnsmasq
echo "Netzwerk- und Firewall-Pakete erfolgreich installiert."

# Warnung für Debian 12, 13 und unstable
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

if [[ "$DEBIAN_VERSION" == "12" || "$DEBIAN_VERSION" == "13" || "$DEBIAN_VERSION" == "unstable" ]]; then
    show_warning
fi

echo "create group $OPENWB_GROUP"
/usr/sbin/groupadd "$OPENWB_GROUP"
echo "done"

echo "create user $OPENWB_USER"
/usr/sbin/useradd "$OPENWB_USER" -g "$OPENWB_GROUP" --create-home
echo "done"

echo "$OPENWB_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/openwb
chmod 440 /etc/sudoers.d/openwb
echo "done"

echo "check for initial git clone..."
if [ ! -d "${OPENWBBASEDIR}/web" ]; then
    mkdir -p "$OPENWBBASEDIR"
    chown "$OPENWB_USER:$OPENWB_GROUP" "$OPENWBBASEDIR"
    sudo -u "$OPENWB_USER" git clone https://github.com/Xerolux/OpenWB2-Bookworm-Trixie.git --branch master "$OPENWBBASEDIR"
    echo "git cloned"
else
    echo "ok"
fi

echo -n "check for ramdisk... "
if grep -Fq "tmpfs ${OPENWBBASEDIR}/ramdisk" /etc/fstab; then
    echo "ok"
else
    mkdir -p "${OPENWBBASEDIR}/ramdisk"
    sudo tee -a "/etc/fstab" <"${OPENWBBASEDIR}/data/config/ramdisk_config.txt" >/dev/null
    mount -a
    echo "created"
fi

echo -n "check for crontab... "
if [ ! -f /etc/cron.d/openwb ]; then
    cp "${OPENWBBASEDIR}/data/config/openwb.cron" /etc/cron.d/openwb
    echo "installed"
else
    echo "ok"
fi

echo "updating mosquitto config file"
systemctl stop mosquitto
sleep 2
cp -a "${OPENWBBASEDIR}/data/config/mosquitto/mosquitto.conf" /etc/mosquitto/mosquitto.conf
mkdir -p /etc/mosquitto/conf.d
cp "${OPENWBBASEDIR}/data/config/mosquitto/openwb.conf" /etc/mosquitto/conf.d/openwb.conf
cp "${OPENWBBASEDIR}/data/config/mosquitto/mosquitto.acl" /etc/mosquitto/mosquitto.acl
sudo cp /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/mosquitto/certs/openwb.pem
sudo cp /etc/ssl/private/ssl-cert-snakeoil.key /etc/mosquitto/certs/openwb.key
sudo chgrp mosquitto /etc/mosquitto/certs/openwb.key
systemctl start mosquitto

if [ ! -f /etc/init.d/mosquitto_local ]; then
    echo "setting up mosquitto local instance"
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
echo "mosquitto done"

echo -n "replacing apache default page..."
cp "${OPENWBBASEDIR}/data/config/apache/000-default.conf" "/etc/apache2/sites-available/"
cp "${OPENWBBASEDIR}/index.html" /var/www/html/index.html
echo "done"
echo -n "fix upload limit..."
if [ -d "/etc/php/7.3/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/7.3/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/7.3/apache2/conf.d/20-uploadlimit.ini
    echo "done (PHP 7.3 - OS Buster)"
elif [ -d "/etc/php/7.4/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/7.4/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/7.4/apache2/conf.d/20-uploadlimit.ini
    echo "done (PHP 7.4 - OS Bullseye)"
elif [ -d "/etc/php/8.2/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/8.2/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/8.2/apache2/conf.d/20-uploadlimit.ini
    echo "done (PHP 8.2 - OS Bookworm)"
elif [ -d "/etc/php/8.3/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/8.3/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/8.3/apache2/conf.d/20-uploadlimit.ini
    echo "done (PHP 8.3 - OS Trixie)"
elif [ -d "/etc/php/8.4/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/8.4/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/8.4/apache2/conf.d/20-uploadlimit.ini
    echo "done (PHP 8.4 - OS Sid or later)"
else
    echo "Fehler: Keine unterstützte PHP-Version gefunden, überspringe Upload-Limit-Konfiguration"
fi
echo -n "enabling apache ssl module..."
a2enmod ssl
a2enmod proxy_wstunnel
a2dissite default-ssl 2>/dev/null || true
cp "${OPENWBBASEDIR}/data/config/apache/apache-openwb-ssl.conf" /etc/apache2/sites-available/
a2ensite apache-openwb-ssl
echo "done"
echo -n "restarting apache..."
systemctl restart apache2
echo "done"

if [[ "$DEBIAN_VERSION" == "12" || "$DEBIAN_VERSION" == "13" || "$DEBIAN_VERSION" == "unstable" ]]; then
    USE_VENV=true
else
    USE_VENV=false
fi

if $USE_VENV; then
    if [ ! -d "$VENV_DIR" ]; then
        echo "Erstelle virtuelle Umgebung in ${VENV_DIR}..."
        sudo -u "$OPENWB_USER" /usr/bin/python3 -m venv "$VENV_DIR"
        echo "Virtuelle Umgebung erfolgreich erstellt."
    fi
    PYTHON_EXEC="$VENV_DIR/bin/python"
    PIP_EXEC="$VENV_DIR/bin/pip"
else
    PYTHON_EXEC="/usr/bin/python3"
    PIP_EXEC="/usr/bin/pip3"
fi

echo "installing python requirements..."
if $USE_VENV; then
    sudo -u "$OPENWB_USER" "$PIP_EXEC" install --upgrade pip
    if [[ "$DEBIAN_VERSION" == "12" || "$DEBIAN_VERSION" == "13" || "$DEBIAN_VERSION" == "unstable" ]]; then
        echo "Für Debian $DEBIAN_VERSION: Installiere Abhängigkeiten aus requirements.txt zusammen mit der neuesten Version von jq..."
        sudo -u "$OPENWB_USER" bash -c "grep -v '^jq' ${OPENWBBASEDIR}/requirements.txt > $TEMP_REQ"
        sudo -u "$OPENWB_USER" bash -c "echo 'jq' >> $TEMP_REQ"
        sudo -u "$OPENWB_USER" "$PIP_EXEC" install -r "$TEMP_REQ"
        if ! sudo -u "$OPENWB_USER" "$PIP_EXEC" show jq > /dev/null; then
            echo "Fehler: Python-Paket jq konnte nicht installiert werden. Überprüfe die requirements.txt und die Netzwerkverbindung."
            exit 1
        fi
    else
        sudo -u "$OPENWB_USER" "$PIP_EXEC" install -r "${OPENWBBASEDIR}/requirements.txt"
    fi
else
    sudo -u "$OPENWB_USER" "$PIP_EXEC" install --user --upgrade pip
    sudo -u "$OPENWB_USER" "$PIP_EXEC" install --user -r "${OPENWBBASEDIR}/requirements.txt"
fi

if [ $? -ne 0 ]; then
    echo "Fehler bei der Installation der Python-Abhängigkeiten. Überprüfe die requirements.txt und die Paketquellen."
    exit 1
fi

echo "installing openwb2 system service..."
sed -i "s|ExecStart=.*|ExecStart=$PYTHON_EXEC -m openWB.run|" "${OPENWBBASEDIR}/data/config/openwb2.service"
if ! $USE_VENV; then
    PYTHON_MAJOR_MINOR=$("$PYTHON_EXEC" --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    sed -i "/ExecStart=/i Environment=\"PYTHONPATH=/home/$OPENWB_USER/.local/lib/python${PYTHON_MAJOR_MINOR}/site-packages\"" "${OPENWBBASEDIR}/data/config/openwb2.service"
fi
ln -sf "${OPENWBBASEDIR}/data/config/openwb2.service" /etc/systemd/system/openwb2.service
systemctl daemon-reload
systemctl enable openwb2

echo "installing openwb2 remote support service..."
sed -i "s|ExecStart=.*python|ExecStart=$PYTHON_EXEC|" "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service"
if ! $USE_VENV; then
    sed -i "/ExecStart=/i Environment=\"PYTHONPATH=/home/$OPENWB_USER/.local/lib/python${PYTHON_MAJOR_MINOR}/site-packages\"" "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service"
fi
cp "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service" /etc/systemd/system/openwbRemoteSupport.service
systemctl daemon-reload
systemctl enable openwbRemoteSupport
systemctl start openwbRemoteSupport

echo "installation finished, now starting openwb2.service..."
systemctl start openwb2

# Systemoptimierung
echo "Optimiere System..."
# APT aufräumen
apt-get autoclean
apt-get autoremove -y
echo "APT Cache und ungenutzte Pakete bereinigt."

# Python-Cache löschen
find "$OPENWBBASEDIR" -type d -name "__pycache__" -exec rm -rf {} +
find "/home/$OPENWB_USER/.local" -type d -name "__pycache__" -exec rm -rf {} +
find "$OPENWBBASEDIR" -type f -name "*.pyc" -delete
find "$OPENWBBASEDIR" -type f -name "*.pyo" -delete
find "/home/$OPENWB_USER/.local" -type f -name "*.pyc" -delete
find "/home/$OPENWB_USER/.local" -type f -name "*.pyo" -delete
echo "Python-Cache erfolgreich gelöscht."

# Speicheroptimierungen
echo "vm.swappiness=10" > /etc/sysctl.d/99-openwb.conf
echo "vm.vfs_cache_pressure=200" >> /etc/sysctl.d/99-openwb.conf
sysctl -p /etc/sysctl.d/99-openwb.conf
echo "Speicheroptimierungen (Swappiness, VFS Cache) angewendet."

# Journal-Logs bereinigen
journalctl --vacuum-time=7d
echo "Systemd Journal-Logs älter als 7 Tage bereinigt."

# Deaktiviere unnötige Dienste auf Raspberry Pi
if [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model; then
    if systemctl is-active --quiet bluetooth; then
        systemctl disable bluetooth
        systemctl stop bluetooth
        echo "Bluetooth-Dienst deaktiviert."
    fi
fi

# Konfiguriere tmpfs für /tmp und /var/log
if ! grep -q "/tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev 0 0" >> /etc/fstab
fi
if ! grep -q "/var/log" /etc/fstab; then
    echo "tmpfs /var/log tmpfs defaults,noatime,nosuid,nodev 0 0" >> /etc/fstab
fi
mount -a
echo "tmpfs für /tmp und /var/log konfiguriert."

echo "Systemoptimierung abgeschlossen."
echo "all done"
echo "if you want to use this installation for development, add a password for user 'openwb' with: sudo passwd openwb"
