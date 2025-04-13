#!/bin/bash
echo "Installing required packages with apt-get..."
sudo apt-get -q update
sudo apt-get -q -y install \
    vim bc jq socat sshpass sudo ssl-cert mmc-utils \
    apache2 libapache2-mod-php \
    php php-gd php-curl php-xml php-json \
    git \
    mosquitto mosquitto-clients \
    xserver-xorg x11-xserver-utils openbox lxde-core lxsession lightdm lightdm-gtk-greeter accountsservice \
    chromium chromium-l10n \
    wget curl \
    build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
    libssl-dev libsqlite3-dev libreadline-dev libffi-dev libbz2-dev \
    tk-dev liblzma-dev libgdbm-compat-dev

# We'll install Python from source in the main script
# so we don't need to install python3-pip here

echo "All required packages installed successfully."
