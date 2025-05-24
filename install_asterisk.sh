#!/bin/bash

# Script to install Asterisk from source on Ubuntu/Debian
# Must be run as root or with sudo
# Last updated: May 2025

# Colors for messages
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No color

# Function to display error messages and exit
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
    error_exit "This script must be run as root or with sudo"
fi

# Update the system
echo "Updating the system..."
apt update && apt upgrade -y || error_exit "Failed to update the system"

# Install basic dependencies
echo "Installing basic dependencies..."
apt install -y sudo build-essential wget git subversion libssl-dev libncurses5-dev libnewt-dev libxml2-dev linux-headers-$(uname -r) libsqlite3-dev uuid-dev libjansson-dev libedit-dev || error_exit "Failed to install basic dependencies"

# Change to the source directory
cd /usr/src || error_exit "Failed to change to /usr/src directory"

# Download the latest version of Asterisk
echo "Downloading the latest version of Asterisk..."
ASTERISK_VERSION="asterisk-22-current.tar.gz"
wget -q http://downloads.asterisk.org/pub/telephony/asterisk/$ASTERISK_VERSION || error_exit "Failed to download Asterisk"
sudo tar -zxvf $ASTERISK_VERSION || error_exit "Failed to extract Asterisk"
cd asterisk-22* || error_exit "Failed to change to Asterisk directory"

# Install additional dependencies
echo "Installing additional dependencies..."
contrib/scripts/install_prereq install || error_exit "Failed to install additional dependencies"

# Configure the build
echo "Configuring the build..."
./configure || error_exit "Error during configuration"

# Select basic modules (using defaults for chan_pjsip and format_mp3)
echo "Selecting basic modules..."
make menuselect.makeopts
menuselect/menuselect --enable chan_pjsip --enable format_mp3 menuselect.makeopts || error_exit "Error selecting modules"

# Compile Asterisk
echo "Compiling Asterisk (this may take several minutes)..."
make -j$(nproc) || error_exit "Error during compilation"

# Install Asterisk
echo "Installing Asterisk..."
make install || error_exit "Error during installation"

# Install sample configuration files
echo "Installing sample configuration files..."
make samples || error_exit "Error installing configuration files"

# Install startup scripts
echo "Installing startup scripts..."
make config || error_exit "Error installing startup scripts"

# Update system libraries
echo "Updating system libraries..."
ldconfig || error_exit "Error updating libraries"

# Create user and group for Asterisk
echo "Creating user and group for Asterisk..."
groupadd asterisk
useradd -r -d /var/lib/asterisk -g asterisk asterisk || error_exit "Error creating asterisk user"

# Configure Asterisk to run as the asterisk user
echo "Configuring permissions and user for Asterisk..."
echo -e "AST_USER=\"asterisk\"\nAST_GROUP=\"asterisk\"" > /etc/default/asterisk

# Modify asterisk.conf
sed -i 's/;runuser = asterisk/runuser = asterisk/' /etc/asterisk/asterisk.conf
sed -i 's/;rungroup = asterisk/rungroup = asterisk/' /etc/asterisk/asterisk.conf

# Change directory permissions
chown -R asterisk:asterisk /var/spool/asterisk /var/run/asterisk /etc/asterisk /var/lib/asterisk /var/log/asterisk /usr/lib/asterisk
chmod -R 750 /var/spool/asterisk /var/run/asterisk /etc/asterisk /var/lib/asterisk /var/log/asterisk /usr/lib/asterisk

# Start and enable Asterisk service
echo "Starting and enabling Asterisk..."
systemctl start asterisk || error_exit "Failed to start Asterisk"
systemctl enable asterisk || error_exit "Failed to enable Asterisk"

# Configure firewall (if ufw is installed)
if command -v ufw >/dev/null; then
    echo "Configuring firewall rules..."
    ufw allow 5060/udp
    ufw allow 10000:20000/udp
    echo "Firewall rules configured for SIP and RTP"
else
    echo "UFW is not installed. Manually configure the firewall for ports 5060/UDP and 10000-20000/UDP"
fi

# Verify installation
echo "Verifying Asterisk installation..."
asterisk -rx "core show version" && echo -e "${GREEN}Asterisk installed successfully!${NC}" || error_exit "Failed to verify installation"

# Final instructions
echo -e "\n${GREEN}Installation completed.${NC}"
echo "Next steps:"
echo "1. Configure files in /etc/asterisk/ (e.g., pjsip.conf or sip.conf)."
echo "2. Test with a softphone (e.g., Zoiper or Linphone)."
echo "3. Check the official documentation at https://wiki.asterisk.org."
echo "4. To access the Asterisk CLI, use: sudo asterisk -rvvv"
