#!/bin/bash
set -ox

VERSION=$(lsb_release -c -s)
sudo apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A

# Add the right repository
case $PT_OSC_VERSION in
  DEVELOPMENT) echo "deb http://repo.percona.com/apt $VERSION main testing" | sudo tee -a /etc/apt/sources.list; ;;
  *) echo "deb http://repo.percona.com/apt $VERSION main" | sudo tee -a /etc/apt/sources.list; ;;
esac

# Update
sudo apt-get update -qq

# Install the right version
case $PT_OSC_VERSION in
  LATEST|DEVELOPMENT) sudo apt-get install -y percona-toolkit; ;;
  *) sudo apt-get install -y percona-toolkit=$PT_OSC_VERSION; ;;
esac

