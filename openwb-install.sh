#!/bin/bash
OPENWBBASEDIR=/var/www/html/openWB
OPENWB_USER=openwb
OPENWB_GROUP=openwb
PYTHON_VERSION="3.10.13"  # Specific Python version for compatibility

if (( $(id -u) != 0 )); then
    echo "This script has to be run as user root or with sudo"
    exit 1
fi

echo "Installing openWB 2 into \"${OPENWBBASEDIR}\""

# Detect Debian version
DEBIAN_VERSION=$(cat /etc/debian_version | cut -d'.' -f1)
if [[ "$DEBIAN_VERSION" == "12" ]]; then
    echo "Detected Debian 12 (Bookworm)"
elif [[ "$DEBIAN_VERSION" == "13" ]]; then
    echo "Detected Debian 13 (Trixie)"
else
    echo "Warning: This script is optimized for Debian 12 (Bookworm) or Debian 13 (Trixie). Proceed with caution."
fi

# Install packages using our updated script
curl -s "https://raw.githubusercontent.com/Xerolux/OpenWB2-Bookworm-Trixie/master/runs/install_packages.sh" | bash -s
if [ $? -ne 0 ]; then
    echo "Trying local install_packages.sh..."
    bash ./install_packages.sh
fi

echo "Building and installing Python ${PYTHON_VERSION}..."
# Create a temporary directory for Python compilation
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download and extract Python source
wget "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
tar -xf "Python-${PYTHON_VERSION}.tgz"
cd "Python-${PYTHON_VERSION}"

# Configure and build Python
./configure --enable-optimizations --with-ensurepip=install
make -j $(nproc)
make altinstall

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Create symlinks for the new Python version
ln -sf "/usr/local/bin/python3.10" "/usr/local/bin/python3"
ln -sf "/usr/local/bin/pip3.10" "/usr/local/bin/pip3"

echo "Python ${PYTHON_VERSION} installed successfully"

echo "Create group $OPENWB_GROUP"
# Will do nothing if group already exists:
/usr/sbin/groupadd "$OPENWB_GROUP"
echo "Done"

echo "Create user $OPENWB_USER"
# Will do nothing if user already exists:
/usr/sbin/useradd "$OPENWB_USER" -g "$OPENWB_GROUP" --create-home
echo "Done"

# The user "openwb" is still new and we might need sudo in many places. Thus for now we give the user
# unrestricted sudo. This should be restricted in the future
echo "$OPENWB_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/openwb
chmod 440 /etc/sudoers.d/openwb
echo "Done"

echo "Check for initial git clone..."
if [ ! -d "${OPENWBBASEDIR}/web" ]; then
    mkdir -p "$OPENWBBASEDIR"
    chown "$OPENWB_USER:$OPENWB_GROUP" "$OPENWBBASEDIR"
    sudo -u "$OPENWB_USER" git clone https://github.com/Xerolux/OpenWB2-Bookworm-Trixie.git --branch master "$OPENWBBASEDIR"
    echo "Git cloned from user repository"
else
    echo "OK"
fi

echo -n "Check for ramdisk... "
if grep -Fq "tmpfs ${OPENWBBASEDIR}/ramdisk" /etc/fstab; then
    echo "OK"
else
    mkdir -p "${OPENWBBASEDIR}/ramdisk"
    sudo tee -a "/etc/fstab" <"${OPENWBBASEDIR}/data/config/ramdisk_config.txt" >/dev/null
    mount -a
    echo "Created"
fi

echo -n "Check for crontab... "
if [ ! -f /etc/cron.d/openwb ]; then
    cp "${OPENWBBASEDIR}/data/config/openwb.cron" /etc/cron.d/openwb
    echo "Installed"
else
    echo "OK"
fi

# Check for mosquitto configuration
echo "Updating mosquitto config file"
systemctl stop mosquitto
sleep 2
cp -a "${OPENWBBASEDIR}/data/config/mosquitto/mosquitto.conf" /etc/mosquitto/mosquitto.conf
mkdir -p /etc/mosquitto/conf.d
cp "${OPENWBBASEDIR}/data/config/mosquitto/openwb.conf" /etc/mosquitto/conf.d/openwb.conf
cp "${OPENWBBASEDIR}/data/config/mosquitto/mosquitto.acl" /etc/mosquitto/mosquitto.acl

# Create mosquitto certificates directory if it doesn't exist
mkdir -p /etc/mosquitto/certs
sudo cp /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/mosquitto/certs/openwb.pem
sudo cp /etc/ssl/private/ssl-cert-snakeoil.key /etc/mosquitto/certs/openwb.key
sudo chgrp mosquitto /etc/mosquitto/certs/openwb.key
systemctl start mosquitto

# Check for mosquitto_local instance
if [ ! -f /etc/init.d/mosquitto_local ]; then
    echo "Setting up mosquitto local instance"
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
echo "Mosquitto done"

# Apache
echo -n "Configuring Apache..."
cp "${OPENWBBASEDIR}/data/config/apache/000-default.conf" "/etc/apache2/sites-available/"
cp "${OPENWBBASEDIR}/index.html" /var/www/html/index.html
echo "Done"

echo -n "Fixing upload limit..."
# For Debian 12 (Bookworm) which uses PHP 8.2 or Debian 13 (Trixie) which may use PHP 8.3
if [ -d "/etc/php/8.3/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/8.3/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/8.3/apache2/conf.d/20-uploadlimit.ini
    echo "Done (OS Trixie - PHP 8.3)"
elif [ -d "/etc/php/8.2/" ]; then
    echo "upload_max_filesize = 300M" > /etc/php/8.2/apache2/conf.d/20-uploadlimit.ini
    echo "post_max_size = 300M" >> /etc/php/8.2/apache2/conf.d/20-uploadlimit.ini
    echo "Done (OS Bookworm - PHP 8.2)"
else
    # Try to find any PHP version
    PHP_VER=$(find /etc/php -maxdepth 1 -type d | grep -oP '\d+\.\d+' | sort -r | head -n1)
    if [ -n "$PHP_VER" ]; then
        echo "upload_max_filesize = 300M" > "/etc/php/$PHP_VER/apache2/conf.d/20-uploadlimit.ini"
        echo "post_max_size = 300M" >> "/etc/php/$PHP_VER/apache2/conf.d/20-uploadlimit.ini"
        echo "Done (PHP $PHP_VER)"
    else
        echo "No PHP version found, skipping upload limit configuration"
    fi
fi

echo -n "Enabling Apache SSL module..."
a2enmod ssl
a2enmod proxy_wstunnel
a2dissite default-ssl 2>/dev/null || true
cp "${OPENWBBASEDIR}/data/config/apache/apache-openwb-ssl.conf" /etc/apache2/sites-available/
a2ensite apache-openwb-ssl
echo "Done"

echo -n "Restarting Apache..."
systemctl restart apache2
echo "Done"

echo "Installing Python requirements with our custom Python version..."
PATH="/usr/local/bin:$PATH" pip3 install --upgrade pip
PATH="/usr/local/bin:$PATH" sudo -u "$OPENWB_USER" pip3 install -r "${OPENWBBASEDIR}/requirements.txt"

echo "Installing openWB2 system service..."
# Update the service file to use our custom Python version
sed -i 's|ExecStart=.*|ExecStart=/usr/local/bin/python3 -m openWB.run|' "${OPENWBBASEDIR}/data/config/openwb2.service"
ln -sf "${OPENWBBASEDIR}/data/config/openwb2.service" /etc/systemd/system/openwb2.service
systemctl daemon-reload
systemctl enable openwb2

echo "Installing openWB2 remote support service..."
# Update the service file to use our custom Python version if necessary
sed -i 's|ExecStart=.*python|ExecStart=/usr/local/bin/python3|' "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service"
cp "${OPENWBBASEDIR}/data/config/openwbRemoteSupport.service" /etc/systemd/system/openwbRemoteSupport.service
systemctl daemon-reload
systemctl enable openwbRemoteSupport
systemctl start openwbRemoteSupport

echo "Installation finished, now starting openWB2 service..."
systemctl start openwb2

echo "All done!"
echo "If you want to use this installation for development, add a password for user 'openwb' using: sudo passwd openwb"
echo "Python ${PYTHON_VERSION} has been installed specifically for openWB compatibility"
