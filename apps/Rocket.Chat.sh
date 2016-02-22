#!/bin/sh

#. sysutils/mongodb.sh

## Install Dependencies
# SYSTEM CONFIGURATION
$install git curl

cd
# Remove the old server executables
[ $1 = update ] || [ $1 = remove ] && "rm -rf Rocket.Chat"
[ $1 = remove ] && "sh $DIR/sysutils/supervisor remove Rocket.Chat" && whiptail --msgbox "Rocket.Chat removed!" 8 32 && break

# https://github.com/RocketChat/Rocket.Chat.RaspberryPi
if [ $ARCH = arm ] || [ $ARCH = armv6 ]
then
  $install python make g++
  # Get required node and npm
  git clone --depth 1 https://github.com/4commerce-technologies-AG/meteor.git

  ~/meteor/meteor -v
  [ $HDWR = rpi2 ] && echo insecure >> ~/a && ~/meteor/meteor -v && echo secure >> ~/a

  # Download the Rocket.Chat binary for Raspberry Pi
  mkdir Rocket.Chat
  cd Rocket.Chat
  curl https://cdn-download.rocket.chat/build/rocket.chat-pi-develop.tgz -o rocket.chat.tgz
  tar zxvf rocket.chat.tgz

  # Install dependencies and start Rocket.Chat
  cd ~/Rocket.Chat/bundle/programs/server
  ~/meteor/dev_bundle/bin/npm install
  cd ~/Rocket.Chat/bundle

# https://github.com/RocketChat/Rocket.Chat/wiki/Deploy-Rocket.Chat-without-docker
elif [ $ARCH = amd64 ] || [ $ARCH = 86 ]
then
  $install graphicsmagick
  . sysutils/nodejs.sh
  . sysutils/meteor.sh

  # Install a tool to let us change the node version.
  npm install -g n

  # Meteor needs at least this version of node to work.
  n 0.10.41

  ## Install Rocket.Chat
  # Download Stable version of Rocket.Chat

  curl -L https://rocket.chat/releases/latest/download -o rocket.chat.tgz

  tar zxvf rocket.chat.tgz

  mv bundle Rocket.Chat
  cd Rocket.Chat/programs/server
  npm install
  cd ../..
else
    whiptail --msgbox "Your architecture $ARCH isn't supported" 8 48 exit 1
fi

whiptail --yesno --title "[OPTIONAL] Setup MongoDB Replica Set" "Rocket.Chat uses the MongoDB replica set OPTIONALLY to improve performance via Meteor Oplog tailing. Would you like to setup the replica set? " 12 48 \
--yes-button No --no-button Yes
if [ $? = 1 ]
then
  # Mongo 2.4 or earlier
  if [ $mongo_version -lt 25 ]
    then echo replSet=001-rs >> /etc/mongod.conf
  # Mongo 2.6+: using YAML syntax
  else
    echo 'replication:
        replSetName:  "001-rs"' >> /etc/mongod.conf
  fi
  service mongod restart
  mongo

  # Start the MongoDB shell and initiate the replica set
  mongo rs.initiate

  # RESULT EXPECTED
  # {
  #  "info2" : "no configuration explicitly specified -- making one",
  #  "me" : "localhost:27017",
  #  "info" : "Config now saved locally.  Should come online in about a minute.",
  #  "ok" : 1
  # }

  export MONGO_OPLOG_URL=mongodb://localhost:27017/local
fi

# Set environment variables
whiptail --title "Rocket.Chat port" --clear --inputbox "Enter your Rocket.Chat port number. default:[3000]" 8 32 2> /tmp/temp
read port < /tmp/temp
port=${port:-3000}

# Add supervisor process and run the server
if [ $ARCH = amd64 ] || [ $ARCH = 86 ]
  then sh $DIR/sysutils/supervisor.sh Rocket.Chat "sh -c \"ROOT_URL=http://$IP:3000/ MONGO_URL=mongodb://localhost:27017/rocketchat PORT=3000 /root/meteor/dev_bundle/bin/node /root/Rocket.Chat/bundle/main.js\"" /root/Rocket.Chat
elif [ $ARCH = arm ] || [ $ARCH = armv6 ]
  then sh $DIR/sysutils/supervisor.sh Rocket.Chat "sh -c \"ROOT_URL=http://$IP:$port/ MONGO_URL=mongodb://localhost:27017/rocketchat PORT=$port /root/meteor/dev_bundle/bin/node /root/Rocket.Chat/bundle/main.js\"" /root/Rocket.Chat/bundle
fi

whiptail --msgbox "Rocket.Chat successfully installed!

Open http://$IP:$port in your browser and register.

The first users to register will be promoted to administrator." 12 64