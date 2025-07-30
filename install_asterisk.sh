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
apt install linux-headers-generic
apt install -y sudo curl build-essential wget git subversion libssl-dev libncurses5-dev libnewt-dev libxml2-dev linux-headers-$(uname -r) libsqlite3-dev uuid-dev libjansson-dev libedit-dev || error_exit "Failed to install basic dependencies"

# Change to the source directory
cd /usr/src || error_exit "Failed to change to /usr/src directory"

# Download the latest version of Asterisk
echo "Downloading the latest version of Asterisk..."
ASTERISK_URL="http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz"
wget -q $ASTERISK_URL || error_exit "Failed to download Asterisk"
ASTERISK_FILE=$(basename $ASTERISK_URL)

# Check if the Asterisk directory already exists
ASTERISK_DIR=$(tar -tzf $ASTERISK_FILE | head -1 | cut -f1 -d"/")
if [ -d "$ASTERISK_DIR" ]; then
    echo "Asterisk directory $ASTERISK_DIR already exists, skipping extraction..."
else
    echo "Extracting Asterisk..."
    tar -zxvf $ASTERISK_FILE || error_exit "Failed to extract Asterisk"
fi

# Change to the Asterisk directory
cd "$ASTERISK_DIR" || error_exit "Failed to change to Asterisk directory"

# Install additional dependencies
echo "Installing additional dependencies..."
contrib/scripts/install_prereq install || error_exit "Failed to install additional dependencies"

# Download MP3 decoder source if format_mp3 is to be enabled
echo "Downloading MP3 decoder source for format_mp3..."
contrib/scripts/get_mp3_source.sh || error_exit "Failed to download MP3 decoder source"

# Configure the build
echo "Configuring the build..."
./configure || error_exit "Error during configuration"

# Select basic modules (using defaults for chan_pjsip and format_mp3)
echo "Selecting basic modules..."
make menuselect.makeopts
menuselect/menuselect --enable chan_pjsip --enable format_mp3 --enable app_cdr menuselect.makeopts || error_exit "Error selecting modules"

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
echo -e "************************************************************"
echo -e "*                 Installation Completed!                  *"
echo -e "************************************************************"
