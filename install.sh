#!/bin/bash

clear

# Set these to change the version of Trittium to install
TARBALLURL="https://github.com/Trittium/trittium/releases/download/2.1.0/Trittium-2.1.0-Ubuntu-daemon.tgz"
TARBALLNAME="Trittium-2.1.0-Ubuntu-daemon.tgz"
TRTTVERSION="2.1.0"

#!/bin/bash

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

# Check if we have enough memory
if [[ `free -m | awk '/^Mem:/{print $2}'` -lt 850 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# Check if we have enough disk space
if [[ `df -k --output=avail / | tail -n1` -lt 10485760 ]]; then
  echo "This installation requires at least 10GB of free disk space.";
  exit 1
fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"

EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`

clear

echo "

  ------- TRITTIUM MASTERNODE INSTALLER v2.1.1--------+
 |                                                  |
 |                                                  |::
 |       The installation will install and run      |::
 |        the masternode under a user tritt.     |::
 |                                                  |::
 |        This version of installer will setup      |::
 |           fail2ban and ufw for your safety.      |::
 |                                                  |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::

"

sleep 5

USER=tritt

adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null

echo "" && echo 'Added user "tritt"' && echo ""
sleep 1


USERHOME=`eval echo "~$USER"`


read -e -p "Enter Masternode Private Key (e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h # THE KEY YOU GENERATED EARLIER) : " KEY



clear

# Generate random passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget htop unzip
apt-get -qq install build-essential && apt-get -qq install libtool libevent-pthreads-2.0-5 autotools-dev autoconf automake && apt-get -qq install libssl-dev && apt-get -qq install libboost-all-dev && apt-get -qq install software-properties-common && add-apt-repository -y ppa:bitcoin/bitcoin && apt update && apt-get -qq install libdb4.8-dev && apt-get -qq install libdb4.8++-dev && apt-get -qq install libminiupnpc-dev && apt-get -qq install libqt4-dev libprotobuf-dev protobuf-compiler && apt-get -qq install libqrencode-dev && apt-get -qq install git && apt-get -qq install pkg-config && apt-get -qq install libzmq3-dev
apt-get -qq install aptitude

  aptitude -y -q install fail2ban
  service fail2ban restart

  apt-get -qq install ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow 30001/tcp
  yes | ufw enable

# Install Trittium daemon
#wget $TARBALLURL && unzip $TARBALLNAME -d $USERHOME/  && rm $TARBALLNAME
wget $TARBALLURL && tar -xvf $TARBALLNAME -C $USERHOME/  && rm $TARBALLNAME
cp $USERHOME/trittiumd /usr/local/bin
cp $USERHOME/trittium-cli /usr/local/bin
cp $USERHOME/trittium-tx /usr/local/bin
rm $USERHOME/trittium*
chmod 755 /usr/local/bin/trittium*
# Create .trittium2 directory
mkdir $USERHOME/.trittium2



#cat > /etc/systemd/system/trittiumd.service << EOL
#[Unit]
#Description=trittiumd
#After=network.target
#[Service]
#Type=forking
#User=${USER}
#WorkingDirectory=${USERHOME}
#ExecStart=/usr/local/bin/trittiumd -conf=${USERHOME}/.trittium2/trittium2.conf -datadir=${USERHOME}/.trittium2
#ExecStop=/usr/local/bin/trittium-cli -conf=${USERHOME}/.trittium2/trittium2.conf -datadir=${USERHOME}/.trittium2 stop
#Restart=on-abort
#[Install]
#WantedBy=multi-user.target
#EOL
#sudo systemctl enable trittiumd
#sudo systemctl stop trittiumd
killall tritt*
sleep 6


# Create trittium2.conf
touch $USERHOME/.trittium2/trittium2.conf
cat > $USERHOME/.trittium2/trittium2.conf << EOL
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
maxconnections=256
rpcport=30002
masternodeaddr=${EXTERNALIP}:30001
masternodeprivkey=${KEY}
masternode=1
EOL
chmod 0600 $USERHOME/.trittium2/trittium2.conf
chown -R $USER:$USER $USERHOME/.trittium2

sleep 1


#sudo systemctl start trittiumd
su - $USER -c trittiumd

clear

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window." && echo ""
BLOCKCOUNT=0

until su -c "trittium-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\" : true' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 2
    BLOCKCOUNT=`su -l -c "trittium-cli getblockcount" $USER`
	echo -en "${CHARS:$i:1}" "$BLOCKCOUNT" "\r"
  done
done

clear

cat << EOL

Now, you need to start your masternode. Please go to your desktop wallet and
add next string to masternode.cogf file:
MN ${EXTERNALIP}:30001 [50k desposit transaction id. 'masternode outputs'] [50k desposit transaction index. 'masternode outputs']
Then restart wallet and wait full sync.

enter the following line into your debug console (Tools->Debug console):
startmasternode "alias" "0" "MN"


EOL

read -p "Press Enter to continue after you've done that. " -n1 -s

clear

sleep 1
sleep 1
clear
su -c "/usr/local/bin/trittium-cli masternode status" $USER
sleep 5

echo "" && echo "If you see @Masternode successfully started@ - Masternode setup completed." && echo ""

