#!/bin/sh

if [ $1 = update ]
then
  cd /home/stackedit
  git pull
  whiptail --msgbox "StackEdit updated!" 8 32
  break
fi
[ $1 = remove ] && sh sysutils/services.sh remove StackEdit && userdel -r stackedit && whiptail --msgbox "StackEdit removed!" 8 32 && break

# Define port
port=$(whiptail --title "StackEdit port" --inputbox "Set a port number for StackEdit" 8 48 "8050" 3>&1 1>&2 2>&3)

# Create stackedit user
useradd -m stackedit

# Go to stackedit user directory
cd /home/stackedit

. sysutils/NodeJS.sh

# Pre-requisites
git clone https://github.com/benweet/stackedit .
npm i -g gulp bower

# Download development tools
npm install

# Download dependencies
bower install --allow-root

# Change the owner from root to git
chown -R stackedit /home/stackedit

# Add SystemD process
cat > /etc/systemd/system/stackedit.service <<EOF
[Unit]
Description=StackEdit Server
After=network.target
[Service]
Type=simple
Environment=PORT=$port
WorkingDirectory=/home/stackedit
ExecStart=/usr/bin/node server.js
User=stackedit
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Start the service and enable it to start up on boot
systemctl start stackedit
systemctl enable stackedit

whiptail --msgbox "StackEdit installed!

Open http://$URL:$port in your browser" 10 64
