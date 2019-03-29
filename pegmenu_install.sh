#!/bin/bash

if [  -f "/usr/local/bin/pegasusd" ] ;  then
  exit 1
fi

COIN_REPO='https://github.com/peg-dev/pegasus/releases/download/V1/peg-linux-daemon.rar'
COIN_RAR='peg-linux-daemon.rar'

IPV4=$(ip addr show eth0 | grep -vw "inet6" | grep "global" | grep -w "inet" | cut -d/ -f1 | awk '{ print $2 }')
echo "Pegasus binaries not yet installed"
apt-get -y install wget nano htop jq dialog unrar
apt-get -y install libzmq3-dev
apt-get -y install libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev
apt-get -y install libevent-dev
apt -y install software-properties-common
add-apt-repository ppa:bitcoin/bitcoin -y
apt-get -y update
apt-get -y install libdb4.8-dev libdb4.8++-dev
apt-get -y install libminiupnpc-dev

wget -nc $COIN_REPO
unrar e -o+ $COIN_RAR
cp pegasus* /usr/local/bin
chmod +x  /usr/local/bin/pegasusd
chmod +x  /usr/local/bin/pegasus-cli

if [ ! -f "/usr/local/bin/pegasusd" ] ; then
   echo "Pegasusd installation failed"
   exit 1
fi

if [ ! -f "/usr/local/bin/pegasus-cli" ] ; then
   echo "Pegasus-cli installation failed"
   exit 1
fi

# make root masternode
mkdir /root/.pegasus
RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)

cat << EOF > /root/.pegasus/pegasus.conf
  rpcuser=$RPCUSER
  rpcpassword=$RPCPASSWORD
  rpcallowip=127.0.0.1
  listen=1
  server=1
  daemon=1
  port=1515
EOF

pegasusd
sleep 5
pegasus-cli getinfo
privkey=$( pegasus-cli createmasternodekey )
echo $privkey
pegasus-cli stop
sleep 5


RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
RPCPORT=1400
cat << EOF > /root/.pegasus/pegasus.conf
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$RPCPORT
listen=1
server=1
daemon=1
port=1515
logintimestamps=1
maxconnections=64
masternode=1
bind=$IPV4
externalip=$IPV4
masternodeprivkey=$privkey
addnode=188.130.251.200:1515
addnode=94.177.229.203:1515
addnode=85.214.222.42:1515
addnode=95.179.195.169:1515
addnode=46.101.90.99:1515
addnode=213.141.134.205:1515
EOF

  # /ect/systemd/systenm service erstellen
cat << EOF > /etc/systemd/system/PEGASUS.service
    [Unit]
    Description=PEGASUS service
    After=network.target
    [Service]
    User=root
    Group=root
    Type=forking
    ExecStart=/usr/local/bin/pegasusd -conf=/root/.pegasus/pegasus.conf -datadir=/root/.pegasus
    ExecStop=-/usr/local/bin/pegasus-cli  -conf=/root/.pegasus/pegasus.conf -datadir=/root/.pegasus stop
    Restart=always
    PrivateTmp=true
    TimeoutStopSec=60s
    TimeoutStartSec=10s
    StartLimitInterval=120s
    StartLimitBurst=5
    [Install]
    WantedBy=multi-user.target
EOF

systemctl daemon-reload
sleep 3
systemctl enable pegasus-root.service
sleep 3
systemctl start pegasus-root.service
echo 
echo "Copy/Paste the line below in your  masternode configuration file on your PC:"
echo
echo "MN0 $IPV4 $privkey"
echo
echo "Then goto your wallet, make your 10K payment and add the txid and outputindex to the line"
echo "Save the file and restart your wallet on the PC to start your masternode."
echo "Press <Enter> to start the menu."
read

