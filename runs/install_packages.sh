#!/bin/bash

# Prüfen, ob das Script als Root ausgeführt wird
if (( $(id -u) != 0 )); then
    echo "this script has to be run as user root or with sudo"
    exit 1
fi

echo "Installing required packages with apt-get..."

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
        "forky")  # Annahme für Debian 14
            DEBIAN_VERSION="14"
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
        "14"|"14."*)
            DEBIAN_VERSION="14"
            DEBIAN_CODENAME="forky"  # Annahme für Debian 14
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
    echo "Unterstützte Versionen: Debian 11 (Bullseye), 12 (Bookworm), 13 (Trixie), 14 (Forky), Unstable (Sid)"
    exit 1
fi

echo "Erkannte Debian-Version: $DEBIAN_VERSION (Codename: $DEBIAN_CODENAME)"

# Definiere PHP-Pakete basierend auf der Debian-Version
case "$DEBIAN_VERSION" in
    "11")
        PHP_FPM_PKG="php7.4-fpm"
        PHP_MODULES="php7.4-gd php7.4-curl php7.4-xml php7.4-json"
        ;;
    "12")
        PHP_FPM_PKG="php8.2-fpm"
        PHP_MODULES="php8.2-gd php8.2-curl php8.2-xml php8.2-json"
        ;;
    "13"|"14"|"unstable")
        PHP_FPM_PKG="php8.3-fpm"
        PHP_MODULES="php8.3-gd php8.3-curl php8.3-xml php8.3-json"
        ;;
    *)
        echo "Fehler: Keine unterstützte PHP-Version für Debian $DEBIAN_VERSION definiert."
        exit 1
        ;;
esac

# Installiere Pakete
echo "Installiere Pakete für Debian $DEBIAN_VERSION..."
sudo apt-get -q update
sudo apt-get -q -y install \
    vim bc jq socat sshpass sudo ssl-cert mmc-utils \
    nginx \
    "$PHP_FPM_PKG" $PHP_MODULES \
    git \
    mosquitto mosquitto-clients \
    xserver-xorg x11-xserver-utils openbox lxde-core lxsession lightdm lightdm-gtk-greeter accountsservice \
    chromium chromium-l10n \
    wget curl \
    build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
    libssl-dev libsqlite3-dev libreadline-dev libffi-dev libbz2-dev \
    tk-dev liblzma-dev libgdbm-compat-dev

# Prüfe, ob die Installation erfolgreich war
if [ $? -ne 0 ]; then
    echo "Fehler: Installation der Pakete fehlgeschlagen. Überprüfe die Paketquellen und Internetverbindung."
    exit 1
fi

# Prüfe, ob die PHP-Module installiert wurden
for module in $PHP_MODULES; do
    if ! dpkg -l | grep -q "$module"; then
        echo "Fehler: PHP-Modul $module konnte nicht installiert werden."
        exit 1
    fi
done

echo "All required packages installed successfully."
