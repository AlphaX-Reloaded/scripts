#!/bin/bash
###################################################################
#                                                                 #
# Author: AlphaX                                                  #
#                                                                 #
# Script to:                                                      #
#   Install Qortal Core on Ubuntu 20.04 with all needed packages! #
#   v0.1 (updated July, 2024)                                     #
#                                                                 #
###################################################################
## Add function.sh ##

echo '
ESC_SEQ="\x1b["
COL_RESET=$ESC_SEQ"39;49;00m"
RED=$ESC_SEQ"31;01m"
GREEN=$ESC_SEQ"32;01m"
YELLOW=$ESC_SEQ"33;01m"
BLUE=$ESC_SEQ"34;01m"
MAGENTA=$ESC_SEQ"35;01m"
CYAN=$ESC_SEQ"36;01m"

function spinner {
	local pid=$!
	local delay=0.75
	local spinstr="/-\|"

 	while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do

	local temp=${spinstr#?}
 	printf " [%c]  " "$spinstr"
 	local spinstr=$temp${spinstr%"$temp"}
 	sleep $delay
 	printf "\b\b\b\b\b\b"
 	done
 	printf "    \b\b\b\b"
}

function spinner2 {
    sleep 7 &
    PID=$!
    i=1
    sp="/-\|"
    echo -n ' '
    while [ -d /proc/$PID ]
    do
        printf "\b${sp:i++%${#sp}:1}"
    done
}

function hide_output {
	OUTPUT=$(tempfile)
	$@ &> $OUTPUT & spinner
	E=$?
	if [ $E != 0 ]; then
	echo
	echo FAILED: $@
	echo -----------------------------------------
	cat $OUTPUT
	echo -----------------------------------------
	exit $E
	fi
	rm -f $OUTPUT
}

function apt_get_quiet {
	DEBIAN_FRONTEND=noninteractive hide_output sudo apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" "$@"
}

function apt_install {
	PACKAGES=$@
	apt_get_quiet install $PACKAGES
}

function ufw_allow {
	if [ -z "$DISABLE_FIREWALL" ]; then
	sudo ufw allow $1 > /dev/null;
	fi
}

function restart_service {
	hide_output sudo service $1 restart
}

function message_box {
	dialog --title "$1" --msgbox "$2" 0 0
}

function input_box {
	declare -n result=$4
	declare -n result_code=$4_EXITCODE
	result=$(dialog --stdout --title "$1" --inputbox "$2" 0 0 "$3")
	result_code=$?
}

function input_menu {
	declare -n result=$4
	declare -n result_code=$4_EXITCODE
	local IFS=^$'\n'
	result=$(dialog --stdout --title "$1" --menu "$2" 0 0 0 $3)
	result_code=$?
}

function get_publicip_from_web_service {
	curl -$1 --fail --silent --max-time 15 icanhazip.com 2>/dev/null
}

function get_default_privateip {
	target=8.8.8.8

	if [ "$1" == "6" ]; then target=2001:4860:4860::8888; fi
	route=$(ip -$1 -o route get $target | grep -v unreachable)
	address=$(echo $route | sed "s/.* src \([^ ]*\).*/\1/")
	if [[ "$1" == "6" && $address == fe80:* ]]; then
	interface=$(echo $route | sed "s/.* dev \([^ ]*\).*/\1/")
	address=$address%$interface
	fi

	echo $address
}
' | sudo -E tee /etc/functions.sh >/dev/null 2>&1

source /etc/functions.sh

echo -e "$GREEN => Done creating functions! $COL_RESET"

sleep 2

output() {
	printf "\E[0;33;40m"
	echo $1
	printf "\E[0m"
}

displayErr() {
	echo
	echo $1;
	echo
	exit 1;
}

## Add user group sudo and no password ##
if [ "$USER" = "root" ]; then
	echo -e "$GREEN You are root user no need passwordless sudo functionality! $COL_RESET"
else
	echo -e "$GREEN This script needs passwordless sudo functionality!$COL_RESET"
	whoami=`whoami`
	sudo usermod -aG sudo ${whoami}
	echo '# Qprtal
	# It needs passwordless sudo functionality.
	'""''"${whoami}"''""' ALL=(ALL) NOPASSWD:ALL
	' | sudo -E tee /etc/sudoers.d/${whoami} >/dev/null 2>&1
fi

sleep 2

clear

echo
echo -e "$GREEN***********************************************************$COL_RESET"
echo -e "$GREEN*                                                         *$COL_RESET"
echo -e "$GREEN* Qortal Core Install Script v0.1                         *$COL_RESET"
echo -e "$GREEN* Install Ortal Core on Ubuntu 20.04                      *$COL_RESET"
echo -e "$GREEN* Install Java 11 JDK, Maven, Perl, Mono, Wine and NodeJS *$COL_RESET"
echo -e "$GREEN*                                                         *$COL_RESET"
echo -e "$GREEN***********************************************************$COL_RESET"
echo
sleep 2


## Update package and Upgrade Ubuntu ##
echo
echo
echo -e "$CYAN => Updating system and installing required packages... $COL_RESET"
echo 
sleep 2

hide_output sudo apt -y update 
hide_output sudo apt -y upgrade
hide_output sudo apt -y autoremove
apt_install software-properties-common build-essential apt-transport-https ca-certificates
apt_install git curl screen nginx htop unzip openjdk-11-jdk maven libfile-slurp-perl
apt_install dirmngr certbot python3-certbot-nginx libjson-perl rpm gnupg
apt_install certbot python3-certbot-nginx dialog
echo -e "$GREEN => Done... $COL_RESET"


## Configure Perl ##
echo
echo
echo -e "$CYAN => Configure Perl... $COL_RESET"
echo
sleep 2

echo "yes" | hide_output sudo cpan JSON
hide_output sudo cpan Crypt::RIPEMD160
echo -e "$GREEN => Done... $COL_RESET"


## Installing Mono ##
echo
echo
echo -e "$CYAN => Installing Mono... $COL_RESET"
echo
sleep 2

hide_output sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
hide_output sudo apt-add-repository 'deb https://download.mono-project.com/repo/ubuntu stable-focal main'
hide_output sudo apt update
apt_install mono-complete mono-dbg
echo -e "$GREEN => Done... $COL_RESET"


## Installing Wine ##
echo
echo
echo -e "$CYAN => Installing Wine... $COL_RESET"
echo
sleep 2

hide_output sudo dpkg --add-architecture i386
hide_output wget -nc https://dl.winehq.org/wine-builds/winehq.key
hide_output sudo apt-key add winehq.key
hide_output sudo apt-add-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ focal main'
hide_output sudo apt update
apt_install --install-recommends winehq-stable
echo -e "$GREEN => Done... $COL_RESET"


## Installing NodeJS ##
echo
echo
echo -e "$CYAN => Installing NodeJS and NPM... $COL_RESET"
echo
sleep 2

hide_output rm -rf ~/.nvm
hide_output curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
hide_output source ~/.profile
hide_output sudo nvm install v18.20.3
hide_output sudo npm install -g npm@10.8.1
echo -e "$GREEN => Done... $COL_RESET"


# Installing Fail2Ban
echo
echo
echo -e "$CYAN => Installing Fail2Ban... $COL_RESET"
echo
sleep 2

apt_install fail2ban
sleep 3
sudo systemctl status fail2ban | sed -n "1,3p"
echo
echo -e "$GREEN => Done... $COL_RESET"


## Making Nginx a bit hard ##
echo
echo
echo -e "$CYAN => Configure Nginx... $COL_RESET"
echo
sleep 2

echo 'map $http_user_agent $blockedagent {
default         0;
~*malicious     1;
~*bot           1;
~*backdoor      1;
~*crawler       1;
~*bandit        1;
}
' | sudo -E tee /etc/nginx/blockuseragents.rules >/dev/null 2>&1
hide_output sudo systemctl restart nginx
slwwp 2
sudo systemctl status nginx | sed -n "1,3p"
echo
echo -e "$GREEN => Done... $COL_RESET"


## Generating API key ##
echo
echo
echo -e "$CYAN => Generate Strong API key for Qortal Core... $COL_RESET"
echo
sleep 2

mkdir -p qortal
apikey=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 22 | head -n 1`
sleep 2
echo ''"${apikey}"'' | sudo -E tee $HOME/qortal/apikey.txt >/dev/null 2>&1
echo -e "$GREEN => Done... $COL_RESET"


## Generating settings json ##
echo
echo
echo -e "$CYAN => Generate settings file for Qortal Core... $COL_RESET"
echo
sleep 2
echo '{
  "listenPort": 12392,
  "apiPort": 12391,
  "apiEnabled": true,
  "apiKeyDisabled": true,
  "apiRestricted": false,
  "apiDocumentationEnabled": true,
  "qdnAuthBypassEnabled": true,
  "uiLocalServers": [
    "localhost",
    "127.0.0.1",
    "0.0.0.0/0",
    "::/0"
  ],
  "apiWhitelist": [
    "localhost",
    "127.0.0.1",
    "0.0.0.0/0",
    "::/0"
  ]
}
' | sudo -E tee $HOME/qortal1/settings.json >/dev/null 2>&1
echo -e "$GREEN => Done... $COL_RESET"


## Installing Qortal Core ##
echo
echo
echo -e "$CYAN => Installing Qortal Core... $COL_RESET"
echo
sleep 2

cd
cd qortal
hide_output wget https://github.com/Qortal/qortal/blob/master/start.sh
hide_output wget https://github.com/Qortal/qortal/blob/master/stop.sh
hide_output wget https://github.com/Qortal/qortal/releases/latest/download/qortal.jar
cd
chmod -R +x qortal/
echo -e "$GREEN => Done... $COL_RESET"


## Installing UFW ##
echo
echo
echo -e "$CYAN => Installing UFW... $COL_RESET"
echo
sleep 2

apt_install ufw
hide_output ufw_allow ssh
hide_output ufw_allow 'Nginx Full'
hide_output ufw_allow 12388
hide_output ufw_allow 12391
hide_output ufw_allow 12392
hide_output sudo ufw --force enable
sleep 3
sudo systemctl status ufw | sed -n "1,3p"
echo
echo -e "$GREEN => Done... $COL_RESET"


## Starting Qortal Core ##
echo
echo
echo -e "$CYAN => Starting Qortal Core... $COL_RESET"
echo
sleep 2

cd
cd qortal
hide_output bash start.sh
cd
echo -e "$GREEN => Done... $COL_RESET"


echo
echo
echo -e "$GREEN***********************************$COL_RESET"
echo -e "$GREEN*                                 *$COL_RESET"
echo -e "$GREEN* Qortal Core Install Script v0.1 *$COL_RESET"
echo -e "$GREEN* Finished !!!                    *$COL_RESET"
echo -e "$GREEN*                                 *$COL_RESET"
echo -e "$GREEN***********************************$COL_RESET"
echo 
echo
echo -e "$CYAN WoW that was fun, just some reminders. $COL_RESET"
echo
echo -e "$RED Your API key is "$apikey" $COL_RESET"
echo
echo
