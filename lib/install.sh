#!/bin/bash

# install sox
if ! command -v sox &> /dev/null
then
	echo "installing sox"
	sudo apt-get install -y sox
fi
if ! command -v sox &> /dev/null
then
	echo "installing sox from static compiled version"
	cd /tmp && wget https://github.com/schollz/makebreakbeat/releases/download/v0.1.0/sox && chmod +x sox && sudo mv sox /usr/local/bin/
fi

# install portedplugins if not already
FILEO=/usr/share/SuperCollider/Extensions/PortedPlugins/AnalogTape_scsynth.so
FILE=/home/we/.local/share/SuperCollider/Extensions/PortedPlugins/AnalogTape_scsynth.so
if [ -f "$FILEO" ]; then 
	echo "have ported plugins" > /dev/null
else
	if [ -f "$FILE" ]; then 
		echo "have ported plugins" > /dev/null
	else
		echo "installing PortedPlugins..."
		mkdir -p /home/we/.local/share/SuperCollider/Extensions/
		cd /tmp && wget https://github.com/schollz/tapedeck/releases/download/PortedPlugins/PortedPlugins.tar.gz && tar -xvzf PortedPlugins.tar.gz && rm PortedPlugins.tar.gz && sudo rsync -avrP PortedPlugins /home/we/.local/share/SuperCollider/Extensions/
	fi
fi

# download sendosc if not already
mkdir -p /home/we/dust/data/sampswap
SENDOSC=/home/we/dust/data/sampswap/sendosc
if [ -f "$SENDOSC" ]; then 
	echo "have sendosc" > /dev/null 
else 
	echo "downloading sendosc..."
	cd /home/we/dust/data/sampswap && wget https://github.com/schollz/sampswap/releases/download/startup/sendosc && chmod +x sendosc
fi

# download amen_resampled if not already
mkdir -p /home/we/dust/audio/sampswap
STARTUPMUSIC=/home/we/dust/audio/sampswap/amen_resampled.wav
if [ -f "$STARTUPMUSIC" ]; then 
	echo "have startupmusic" > /dev/null 
else 
	echo "downloading starting sample..."
	cd /home/we/dust/audio/sampswap && wget https://github.com/schollz/sampswap/releases/download/startup/amen_resampled.wav
fi

## cleanup
rm -rf /tmp/sampswap
mkdir -p /tmp/sampswap
