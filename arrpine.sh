#!/bin/sh
# Drew's Media Server (DMS) Setup Script for Alpine Linux

# Clear the screen for a clean start
clear

# Display logo
echo ""
echo "    ██████╗ ███╗   ███╗███████╗"
echo "    ██╔══██╗████╗ ████║██╔════╝"
echo "    ██║  ██║██╔████╔██║███████╗"
echo "    ██║  ██║██║╚██╔╝██║╚════██║"
echo "    ██████╔╝██║ ╚═╝ ██║███████║"
echo "    ╚═════╝ ╚═╝     ╚═╝╚══════╝"
echo ""
echo "==== Drew's Media Server Setup ===="
echo "==================================="
echo "Designed with Alpine Linux Standard"
echo "-------Tested with v3.21.3---------"
echo ""
sleep 1

# Initialize variables
USE_FILE_SERVER="n"
FILE_SERVER_IP=""
MEDIA_FOLDER=""
SMB_USER=""
SMB_USER_PASSWORD=""
VPN_SERVICE=""
VPN_USER=""
VPN_PASSWORD=""
USER_TIMEZONE=""
MOUNT_SUCCESS=false

# Prompt for file server details
echo "Do you have an existing file server? (y/n)"
read -r USE_FILE_SERVER

if [ "$USE_FILE_SERVER" = "y" ] || [ "$USE_FILE_SERVER" = "Y" ]; then
    mkdir -p /tmp/dms_test # Create test directory
    
    # Start a loop to allow credential retries
    SMB_CONNECTION_SUCCESSFUL=false
    while [ "$SMB_CONNECTION_SUCCESSFUL" = "false" ]; do
        echo "Enter the file server IP address:"
        read -r FILE_SERVER_IP
        
        echo "Enter the media folder share name:"
        read -r MEDIA_FOLDER
        # Remove leading slash if present
        MEDIA_FOLDER=$(echo "$MEDIA_FOLDER" | sed 's|^/||')
        
        echo "Enter the SMB username:"
        read -r SMB_USER
        
        echo "Enter the SMB password: (input will be hidden)"
        stty -echo
        read -r SMB_USER_PASSWORD
        stty echo
        echo ""  # Add a newline since read -s doesn't add one
        
        echo "Testing connection to file server..."
        # Try to mount and capture error message
        MOUNT_OUTPUT=$(mount -t cifs //$FILE_SERVER_IP/$MEDIA_FOLDER /tmp/dms_test -o username=$SMB_USER,password=$SMB_USER_PASSWORD,vers=3.0 2>&1)
        MOUNT_STATUS=$?
        
        if [ $MOUNT_STATUS -eq 0 ]; then
            echo "✓ Connection successful!"
            SMB_CONNECTION_SUCCESSFUL=true
            umount /tmp/dms_test 2>/dev/null  # Unmount test directory
        else
            echo "✗ Connection failed: $MOUNT_OUTPUT"
            echo ""
            echo "Options:"
            echo "1) Try again with different credentials"
            echo "2) Continue without file server"
            echo "Enter choice (1 or 2):"
            read -r RETRY_CHOICE
            
            if [ "$RETRY_CHOICE" = "2" ]; then
                echo "Continuing without file server."
                USE_FILE_SERVER="n"
                break
            fi
            # If choice was 1 or anything else, loop continues
            echo ""
        fi
    done
    
    rmdir /tmp/dms_test 2>/dev/null  # Clean up test directory
    sleep 1
fi
echo ""
echo "===================================="
echo ""
# Prompt for VPN details
echo "Follow this link to see a list of Gluetun supported providers."
echo "https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers"
echo ""
echo "Enter the VPN service provider (with spaces):"
read -r VPN_SERVICE

echo "Enter the VPN username:"
read -r VPN_USER

echo "Enter the VPN password: (input will be hidden)"
stty -echo
read -r VPN_PASSWORD
stty echo
echo ""  # Add a newline since read -s doesn't add one

sleep 1
echo ""
echo "===================================="
echo ""
# Prompt for timezone
echo "Enter your timezone (e.g., America/New_York):"
read -r USER_TIMEZONE

echo ""
echo ">>>>> Starting DMS installation <<<<<"
echo ""
sleep 3

# Add all needed APKs
echo ">>> Installing required packages..."
sleep 2
apk add --no-cache --upgrade docker docker-compose cifs-utils
sleep 2

# Add Docker to autostart on boot
echo ">>> Setting up Docker to start on boot..."
sleep 2
rc-update add docker default
sleep 2

# Start Docker service
echo ">>> Starting Docker service..."
sleep 2
/etc/init.d/docker start
sleep 2

# Handle file server setup if needed
if [ "$USE_FILE_SERVER" = "y" ] || [ "$USE_FILE_SERVER" = "Y" ]; then
    echo ">>> Setting up file server mount..."
    sleep 2
    
    # Create media directory
    mkdir -p /opt/dms/media
    
    # Using proper octal notation for file and directory modes
    # First, try to umount if already mounted
    umount /opt/dms/media 2>/dev/null
    
    # Mount media server (with error capture but showing error this time)
    MOUNT_OUTPUT=$(mount -t cifs //$FILE_SERVER_IP/$MEDIA_FOLDER /opt/dms/media -o username=$SMB_USER,password=$SMB_USER_PASSWORD,vers=3.0,uid=1000,gid=1000,file_mode=0755,dir_mode=0755 2>&1)
    MOUNT_STATUS=$?
    
    if [ $MOUNT_STATUS -eq 0 ]; then
        echo "File server mounted successfully. ✓"
        MOUNT_SUCCESS=true
    else
        echo "Could not mount file server. Will create local directories instead."
        echo "Reason: $MOUNT_OUTPUT"
        # Don't set MOUNT_SUCCESS to true
    fi

    # Add mount to fstab for persistence upon reboot
    # Remove existing line if present
    sed -i "\|//$FILE_SERVER_IP/$MEDIA_FOLDER|d" /etc/fstab
    
    # Add new fstab entry with proper octal notation
    cat >> /etc/fstab << EOF
//$FILE_SERVER_IP/$MEDIA_FOLDER /opt/dms/media cifs username=$SMB_USER,password=$SMB_USER_PASSWORD,vers=3.0,uid=1000,gid=1000,file_mode=0755,dir_mode=0755,_netdev 0 0
EOF
    sleep 2
else
    echo ">>> Creating local media directories..."
    sleep 2
    mkdir -p /opt/dms/media
    sleep 1
fi

# Create file server directories
echo ">>> Creating media directories..."
sleep 2
mkdir -p /opt/dms/media/blackhole
mkdir -p /opt/dms/media/books
mkdir -p /opt/dms/media/downloads
mkdir -p /opt/dms/media/movies
mkdir -p /opt/dms/media/music
mkdir -p /opt/dms/media/torrents
mkdir -p /opt/dms/media/tvshows
sleep 1

# Create arruser with arruser group
echo ">>> Setting up user accounts..."
sleep 2
adduser -D arruser 2>/dev/null

# Give Permissions to arruser
chown -R arruser:arruser /opt/dms
chmod -R 775 /opt/dms

# Add root to arruser group
adduser root arruser 2>/dev/null
sleep 2

# Create docker-compose.yaml
echo ">>> Creating docker-compose.yaml..."
sleep 2
cat > /opt/dms/docker-compose.yaml << 'EOF'
services:
  # Jellyfin is the media service
  jellyfin:
    image: lscr.io/linuxserver/${MEDIA_SERVICE}
    container_name: ${MEDIA_SERVICE}
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - VERSION=docker
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${MEDIA_DIRECTORY}:/data
      - ${INSTALL_DIRECTORY}/config/${MEDIA_SERVICE}:/config
    ports:
      - 8096:8096
    restart: unless-stopped

  # qBitorrent is used to download torrents
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent
    container_name: qbittorrent
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - WEBUI_PORT=8081
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${MEDIA_DIRECTORY}:/data
      - ${INSTALL_DIRECTORY}/config/qbittorrent:/config
    restart: unless-stopped
    network_mode: "service:gluetun"
    depends_on:
      - gluetun

  # Sonarr is used to query, add downloads to the download queue and index TV shows
  # https://sonarr.tv/
  sonarr:
    image: lscr.io/linuxserver/sonarr
    container_name: sonarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${MEDIA_DIRECTORY}:/data
      - ${INSTALL_DIRECTORY}/config/sonarr:/config
    ports:
      - 8989:8989
    restart: unless-stopped

  # Radarr is used to query, add downloads to the download queue and index Movies
  # https://radarr.video/
  radarr:
    image: lscr.io/linuxserver/radarr
    container_name: radarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${MEDIA_DIRECTORY}:/data
      - ${INSTALL_DIRECTORY}/config/radarr:/config
    ports:
      - 7878:7878
    restart: unless-stopped

  # Lidarr is used to query, add downloads to the download queue and index Music
  # https://lidarr.audio/
  lidarr:
    image: lscr.io/linuxserver/lidarr
    container_name: lidarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${MEDIA_DIRECTORY}:/data
      - ${INSTALL_DIRECTORY}/config/lidarr:/config
    ports:
      - 8686:8686
    restart: unless-stopped

  # Readarr is used to query, add downloads to the download queue and index Audio and Ebooks
  # https://readarr.com/
  readarr:
    image: lscr.io/linuxserver/readarr:develop
    container_name: readarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${MEDIA_DIRECTORY}:/data
      - ${INSTALL_DIRECTORY}/config/readarr:/config
    ports:
      - 8787:8787
    restart: unless-stopped

  # Bazarr is used to download and categorize subtitles
  # https://www.bazarr.media/
  bazarr:
    image: lscr.io/linuxserver/bazarr
    container_name: bazarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${MEDIA_DIRECTORY}:/data
      - ${INSTALL_DIRECTORY}/config/bazarr:/config
    ports:
      - 6767:6767
    restart: unless-stopped

  # Prowlarr is our torrent indexer/searcher. Sonarr/Radarr use Prowlarr as a source
  # https://prowlarr.com/
  prowlarr:
    image: lscr.io/linuxserver/prowlarr
    container_name: prowlarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${INSTALL_DIRECTORY}/config/prowlarr:/config
    ports:
      - 9696:9696
    restart: unless-stopped

  # Gluetun is our VPN, so you can download torrents safely
  gluetun:
    image: qmcgaw/gluetun:v3
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - 8888:8888/tcp # HTTP proxy
      - 8388:8388/tcp # Shadowsocks
      - 8388:8388/udp # Shadowsocks
      - 8003:8000/tcp # Admin
      - 8081:8081/tcp # qBittorrent
    environment:
      - FIREWALL_OUTBOUND_SUBNETS=172.18.0.0/24
      - VPN_SERVICE_PROVIDER=${VPN_SERVICE}
      - VPN_TYPE=openvpn
      - OPENVPN_USER=${VPN_USER}
      - OPENVPN_PASSWORD=${VPN_PASSWORD}
      - OPENVPN_CIPHERS=AES-256-GCM
      - PORT_FORWARD_ONLY=on
      - VPN_PORT_FORWARDING=on
    restart: unless-stopped

  # Portainer helps debugging and monitors the containers
  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    ports:
      - 9000:9000
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${INSTALL_DIRECTORY}/config/portainer:/data
    restart: unless-stopped
    
  # Jellyseerr to allow very simple requests
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
    volumes:
      - ${INSTALL_DIRECTORY}/config/jellyseerr:/app/config
    ports:
      - 5055:5055
    restart: unless-stopped

  # Homarr to allow a simple homepage setup
  homarr:
    image: ghcr.io/homarr-labs/homarr:latest
    container_name: homarr
    environment:
      - SECRET_ENCRYPTION_KEY=573bbb8597c6317e905056c21872426ef0e15671f031dfe68e7cf09731de8766
      - TZ=${TZ}
    volumes:
      - ${INSTALL_DIRECTORY}/config/homarr:/appdata
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - 7575:7575
    restart: unless-stopped

  # Decluttarr to prevent stalled or broken downloads getting stuck
  decluttarr:
    image: ghcr.io/manimatter/decluttarr:latest
    container_name: decluttarr
    restart: always
    environment:
      TZ: $TZ
      PUID: $PUID
      PGID: $PGID

      ## General
      # TEST_RUN: True
      # SSL_VERIFICATION: False
      LOG_LEVEL: INFO

      ## Features
      REMOVE_TIMER: 120
      REMOVE_FAILED: True
      REMOVE_FAILED_IMPORTS: True
      REMOVE_METADATA_MISSING: True
      REMOVE_MISSING_FILES: True
      REMOVE_ORPHANS: True
      REMOVE_SLOW: False
      REMOVE_STALLED: True
      REMOVE_UNMONITORED: True
      RUN_PERIODIC_RESCANS: '
        {
        "SONARR": {"MISSING": true, "CUTOFF_UNMET": true, "MAX_CONCURRENT_SCANS": 3, "MIN_DAYS_BEFORE_RESCAN": 7},
        "RADARR": {"MISSING": true, "CUTOFF_UNMET": true, "MAX_CONCURRENT_SCANS": 3, "MIN_DAYS_BEFORE_RESCAN": 7}
        }'

      # Feature Settings
      PERMITTED_ATTEMPTS: 3
      NO_STALLED_REMOVAL_QBIT_TAG: Don't Kill
      MIN_DOWNLOAD_SPEED: 100
      FAILED_IMPORT_MESSAGE_PATTERNS: '
        [
        "Not a Custom Format upgrade for existing",
        "Not an upgrade for existing"
        ]'

      ## Radarr
      RADARR_URL: http://radarr:7878
      RADARR_KEY: $RADARR_API_KEY

      ## Sonarr
      SONARR_URL: http://sonarr:8989
      SONARR_KEY: $SONARR_API_KEY

      ## Lidarr
      LIDARR_URL: http://lidarr:8686
      LIDARR_KEY: $LIDARR_API_KEY

      ## Readarr
      READARR_URL: http://readarr:8787
      READARR_KEY: $READARR_API_KEY

      ## qBitorrent
      QBITTORRENT_URL: http://gluetun:8081
    depends_on:
      - radarr
      - sonarr
      - lidarr
      - readarr
      - gluetun

  # FlareSolverr to get passed basic CloudFlare blocks for Indexers
  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      - LOG_LEVEL=${LOG_LEVEL:-info}
      - LOG_HTML=${LOG_HTML:-false}
      - CAPTCHA_SOLVER=${CAPTCHA_SOLVER:-none}
      - TZ=${TZ}
    ports:
      - "${PORT:-8191}:8191"
    restart: unless-stopped

  # Watchtower is going to keep our instances updated
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    environment:
      - WATCHTOWER_CLEANUP=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
EOF
sleep 2

# Create .env file
echo ">>> Creating .env file..."
sleep 2
cat > /opt/dms/.env << EOF
# Base configuration
PUID=1000
PGID=1000
MEDIA_DIRECTORY=/opt/dms/media
INSTALL_DIRECTORY=/opt/dms/
MEDIA_SERVICE=jellyfin

# VPN configuration
VPN_ENABLED=y
VPN_SERVICE=$VPN_SERVICE
VPN_USER=$VPN_USER
VPN_PASSWORD=$VPN_PASSWORD

# API Keys
RADARR_API_KEY=
SONARR_API_KEY=
LIDARR_API_KEY=
READARR_API_KEY=

# Time Zone Var
TZ=$USER_TIMEZONE
EOF
sleep 1

# Re-permission new files
echo ">>> Setting file permissions..."
sleep 2
chown -R arruser:arruser /opt/dms
chmod -R 775 /opt/dms
sleep 1

# Navigate to docker-compose.yaml
cd /opt/dms

# Create tun module
echo ">>> Setting up network modules for VPN..."
sleep 2
modprobe tun
echo "tun" >> /etc/modules
mkdir -p /dev/net
mknod /dev/net/tun c 10 200 2>/dev/null
chmod 600 /dev/net/tun
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
echo "net.ipv4.conf.all.forwarding = 1" >> /etc/sysctl.conf
sysctl -p
sleep 2

# Compose docker-compose.yaml
echo ">>> Starting Docker containers..."
sleep 2
docker compose up -d
sleep 2

# Add loading bar to wait for containers to fully boot
echo ">>> Waiting for containers to fully boot up..."
total=15
for i in $(seq 1 $total); do
    # Calculate the number of filled blocks
    blocks=$((i * 30 / total))
    
    # Create the progress bar
    bar="["
    for j in $(seq 1 $blocks); do
        bar="${bar}#"
    done
    for j in $(seq $blocks 29); do
        bar="${bar} "
    done
    bar="${bar}]"
    
    # Print the progress bar with a countdown
    printf "\r%s %d%% - %d seconds remaining" "$bar" "$((i * 100 / total))" "$((total - i))"
    sleep 1
done
printf "\nContainers are ready!\n"
sleep 2
clear
echo "======================================"
# Check qBittorrent VPN Status
echo ">>> Checking VPN status..."
sleep 2
HOST_IP=$(wget -qO- https://api.ipify.org)
VPN_IP=$(docker exec gluetun wget -qO- https://api.ipify.org)
echo "Host IP: $HOST_IP"
echo "qBittorrent/VPN IP: $VPN_IP"
if [ "$HOST_IP" != "$VPN_IP" ]; then
  echo "VPN Working: YES - IPs are different ✓"
else
  echo "VPN Working: NO - Same IP address ✗"
fi
sleep 2
echo "======================================"
# Get qBittorrent temp password - fixed to work with BusyBox grep
echo ">>> qBittorrent temporary password:"
docker logs qbittorrent 2>&1 | grep "temporary password" | tail -n 1
echo "======================================"

# Check file server mount status
if [ "$USE_FILE_SERVER" = "y" ] || [ "$USE_FILE_SERVER" = "Y" ]; then
    echo ">>> Checking file server mount status:"
    if mountpoint -q /opt/dms/media; then
        echo "File server mounted: YES ✓"
        echo "Mount point: //$(grep "//$FILE_SERVER_IP/$MEDIA_FOLDER" /etc/fstab | head -1)"
    else
        echo "File server mounted: NO ✗"
        echo "Please check your file server settings and try mounting manually:"
        echo "mount -t cifs //$FILE_SERVER_IP/$MEDIA_FOLDER /opt/dms/media -o username=$SMB_USER,password=YOUR_PASSWORD,vers=3.0"
    fi
fi

# Get server IP for URL display - more reliable IP detection
SERVER_IP=$(ip -4 addr show | grep -v 127.0.0.1 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | head -n 1)
# Fallback to hostname command if ip command fails
if [ -z "$SERVER_IP" ]; then
    # Try another method
    SERVER_IP=$(hostname -i 2>/dev/null || ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n 1)
fi
# If still no IP, use localhost
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="localhost"
fi

echo "======================================"
echo "      DMS Setup Complete!      "
echo "======================================"
echo ""
echo "Access your media server services:"
echo ""
echo "Jellyfin:     http://$SERVER_IP:8096"
echo "Sonarr:       http://$SERVER_IP:8989"
echo "Radarr:       http://$SERVER_IP:7878"
echo "Lidarr:       http://$SERVER_IP:8686"
echo "Readarr:      http://$SERVER_IP:8787"
echo "Bazarr:       http://$SERVER_IP:6767"
echo "Prowlarr:     http://$SERVER_IP:9696"
echo "qBittorrent:  http://$SERVER_IP:8081"
echo "Portainer:    http://$SERVER_IP:9000"
echo "Jellyseerr:   http://$SERVER_IP:5055"
echo "Homarr:       http://$SERVER_IP:7575"
echo ""
echo "Enjoy your new media server!"
echo "===================================="
