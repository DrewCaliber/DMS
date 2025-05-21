https://alpinelinux.org/downloads/
https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86/alpine-standard-3.21.3-x86.iso

Install steps here are a little half ass. YT video maybe coming soon idk. Ignore any YAMS commands, this version doesn't use YAMS. Just reference the pictures.

Do a standard setup with setup-alpine, but DO NOT create an additional user when prompted. The script relies on the fact that it's 1. Ran as root. And 2. That it's creating the first user.

Made and tested with Alpine Linux 3.21.3

Terminal:
apk add git
git clone https://github.com/DrewCaliber/DMS /tmp/dms
sh /tmp/dms/arrpine.sh

Follow the prompts, then:

Setup the user for Portainer - It times out, so just reboot if it does. Reboot command is just reboot. IPs and ports should have been given at the end of install. If not, then all containers use the default ports anyways. i.e. Google "Portainer default port", etc.

Setup qBittorrent (There's a bad step in the guide, the downloads should go into /data/downloads - NOT /data/downloads/torrents/) (Also ignore the YAMS commands, they're irrelevant, just follow the pictures).
https://yams.media/config/qbittorrent/#setting-up-qbittorrent
Ignore the "Final VPN Check" YAMS commands do not apply here, just the app setup pictures.

You'll also want to add the docker containers to the "Bypass authentication for clients in whitelisted IP subnets" under WebUI.
Usually they're under the "172.18.0.0/24" network. Check Portainer > Containers to be sure. Sometimes they'll fall under "192.168.1.0/24".

Setup Radar (Store the API key in a notepad, you'll need it later).
https://yams.media/config/radarr/

Setup Sonarr (Store the API key in a notepad, you'll need it later).
https://yams.media/config/sonarr/

Setup Prowlarr
https://yams.media/config/prowlarr/

Setup Bazarr
https://yams.media/config/bazarr/

Setup Jellyfin
https://yams.media/config/jellyfin/

Once you're done, grab all the API keys for Radar, Sonarr, Lidarr (Optional), and Readarr (Optional).

Edit the .env in /opt/dms/

Add the API keys. Reboot the server. Reboot command is just reboot.
