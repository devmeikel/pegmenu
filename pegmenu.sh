#!/bin/bash


if [ ! -f "/usr/local/bin/pegasusd" ] ;  then
  bash pegmenu_install.sh
fi


INPUT=/tmp/menu.sh.$$

export NCURSES_NO_UTF8_ACS=1

# Storage file for displaying cal and date command output
OUTPUT=/tmp/output.sh.$$

# get text editor or fall back to vi_editor
vi_editor=${EDITOR-vi}

# trap and delete temp files
trap "rm $OUTPUT; rm $INPUT; exit" SIGHUP SIGINT SIGTERM

#Verzeichnisse einlesen
#rm peg_nodes.txt

echo "/root"  > peg_nodes.txt

if [ -d "/home/peg1" ] ;  then
  #echo "press enter"
  #read
  folder=( $(find /home/peg*  -maxdepth 0  -type d) )
  for i in "${folder[@]}"; do
    IFS="_"
    set -- $i
    echo "$1"  >> peg_nodes.txt
  done
fi


ALIAS="/root"

#
# Purpose - display output using msgbox
#  $1 -> set msgbox height
#  $2 -> set msgbox width
#  $3 -> set msgbox title
#
function display_output(){
        local h=${1-15}                 # box height default 10
        local w=${2-41}                 # box width default 41
        local t=${3-Output}     # box title
        dialog --backtitle "Pegasus Menu" --title "${t}" --clear --msgbox "$(<$OUTPUT)" ${h} ${w}
}
###########################################
# install new masternode
#
function new_masternode(){
# adduser
userpass=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1) 
adduser --gecos "" peg$1 <<EOF
$userpass
$userpass
EOF

# get IPv6 address
ip addr show eth0 | grep -vw "inet" | grep "global" | grep -w "inet6" | cut -d/ -f1 | awk '{ print $2 }' | tail -n -1  >ipv6_address
IP=$(head -n 1 ipv6_address)
echo $IP
IFS=':' read -r -a array <<< $IP
IP=${array[0]}:${array[1]}:${array[2]}:${array[3]}:${array[4]}:$1



# create privkey 
privkey=$('pegasus-cli createmasternodekey')


CONFIGFOLDER=/home/peg$1/.pegasus
mkdir $CONFIGFOLDER 



# create pegasus.conf
RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
if [ $1 -gt 9 ] 
then 
  RPCPORT=14$1
else
  RPCPORT=140$1
fi
cat << EOF > $CONFIGFOLDER/pegasus.conf
rpcuser=$RPCUSER
rpcpassword=RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$RPCPORT
listen=1
server=1
daemon=1
port=1515
logintimestamps=1
maxconnections=32
masternode=1
bind=[$IP]
externalip=[$IP]
masternodeprivkey=$privkey
addnode=188.130.251.200:1515
addnode=94.177.229.203:1515
addnode=85.214.222.42:1515
addnode=95.179.195.169:1515
addnode=46.101.90.99:1515
addnode=213.141.134.205:1515
EOF

# create /ect/systemd/system service 
cat << EOF > /etc/systemd/system/peg$1.service
[Unit]
Description=peg$1 service
After=network.target
[Service]
User=peg$1
Group=peg$1
Type=forking
ExecStart=/usr/local/bin/pegasusd -conf=/home/peg$1/.pegasus/pegasus.conf -datadir=/home/peg$1/.pegasus
ExecStop=-/usr/local/bin/pegasus-cli  -conf=/home/peg$1/.pegasus/pegasus.conf -datadir=/home/peg$1/.pegasus stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

chown -R peg$1:peg$1 /home/peg$1
clear
echo "Please wait...service is registered and starting"
systemctl daemon-reload
sleep 3
systemctl enable peg$1.service   
sleep 5
systemctl start peg$1.service
echo
echo "Put the line below in your masternode.conf on your PC"
echo C3-MN$1 [$IP]:1515 $privkey
echo
echo "Then goto your wallet, make your 10K payment and add the txid and outputindex to the line"
echo "Save the file and restart your wallet on the PC to start your masternode."
echo "Press <ENTER> for back to the menu"
read input
ALIAS="/home/peg$1"

folder=( $(find /home/peg*  -maxdepth 0  -type d) )
echo "/root"  > peg_nodes.txt
for i in "${folder[@]}"; do
  IFS="_"
  set -- $i
  echo "$1"  >> peg_nodes.txt
done
}
#
# set infinite loop
#
while true
do

### display main menu ###
dialog --clear  --help-button --backtitle "Pegasus Menu 1.0 Beta" \
--title "[ Masternode: ${ALIAS} ]" \
--menu "" 20 60 20 \
1  "Show pegasus.conf" \
2  "Edit pegasus.conf" \
3  "Start masternode" \
4  "Stop  masternode" \
5  "Server Masternode Status" \
6  "Server Getinfo" \
7  "Show Services" \
8  "Select another masternode" \
9  "Install another masternode" \
A  "Show IPs" \
0  "Exit" 2>"${INPUT}"

menuitem=$(<"${INPUT}")


# make decsion
case $menuitem in
        1) cd ~
           FILE="${ALIAS}/.pegasus/pegasus.conf"
           dialog --textbox "${FILE}" 0 0
           ;;
        2) cd ~
           nano "${ALIAS}/.pegasus/pegasus.conf"
        ;;
        3) cd ~
           A="$(cut -d'/' -f3 <<<$ALIAS)" 
           if [ $ALIAS == "/root" ] ; then 
             A="PEGASUS"
           fi 
           systemctl start $A
           echo -e "Press <ENTER> to continue \c"
           read input
        ;;
        4) cd ~
           A="$(cut -d'/' -f3 <<<$ALIAS)"
           if [ $ALIAS == "/root" ] ; then
             A="PEGASUS"
           fi
           systemctl stop $A
           echo -e "Press <ENTER> to continue \c"
           read input
        ;;
        5) rm $ALIAS/mnstatus.txt
           rm $ALIAS/failed.txt 
           #echo "Masternode Status: ${ALIAS}" > $ALIAS/mnstatus.txt
           #chmod 777 $ALIAS/mnstatus.txt
           A="$(cut -d'/' -f3 <<<$ALIAS)"
           su $A -c 'pegasus-cli  masternode status >> ~/mnstatus.txt 2>~/failed.txt'
           #echo -e "Press <ENTER> to continue "
           #read input
           fs=$(stat -c %s $ALIAS/mnstatus.txt)
           if  [ $fs -gt 0 ] ;  then 
             dialog --textbox "$ALIAS/mnstatus.txt" 0 0
           fi
           fs=$(stat -c %s $ALIAS/failed.txt)
           if  [ $fs -gt 0 ] ;  then
             dialog --textbox "$ALIAS/failed.txt" 0 0
           fi
        ;;
        6) rm $ALIAS/mnstatus.txt
           rm $ALIAS/failed.txt
           #echo "Masternode Getinfo: ${ALIAS}" > $ALIAS/mnstatus.txt
           #chmod 777 $ALIAS/mnstatus.txt
           A="$(cut -d'/' -f3 <<<$ALIAS)"
           su $A -c 'pegasus-cli  getinfo >> ~/mnstatus.txt 2>~/failed.txt'
            fs=$(stat -c %s $ALIAS/mnstatus.txt)
           if [ $fs -gt 0 ] ;  then
             dialog --textbox "$ALIAS/mnstatus.txt" 0 0
           fi
           fs=$(stat -c %s $ALIAS/failed.txt)
           if  [ $fs -gt 0 ] ;  then
             dialog --textbox "$ALIAS/failed.txt" 0 0
           fi
        ;;
        7) folder=( $(find /etc/systemd/system/*.service  -maxdepth 0  -type f) )
           for i in "${folder[@]}"; do
           IFS="_"
           set -- $i
           echo "$1" > services.txt
           done
           dialog --textbox "services.txt" 0 0  
           ;;
        8) declare -a array
           i=1 #Index counter for adding to array
           j=1 #Option menu value generator
          while read line
          do
             array[ $i ]=$j
             (( j++ ))
             array[ ($i + 1) ]=$line
             (( i=($i+2) ))
         done < <(cat peg_nodes.txt)

         #Define parameters for menu
         TERMINAL=$(tty) #Gather current terminal session for appropriate redirection
         HEIGHT=20
         WIDTH=76
         CHOICE_HEIGHT=16
         BACKTITLE="Back_Title"
         TITLE="Dynamic Dialog"
         MENU="Choose a file:"

         #Build the menu with variables & dynamic content
         CHOICE=$(dialog --clear \
                 --backtitle "$BACKTITLE" \
                 --title "$TITLE" \
                 --menu "$MENU" \
                 $HEIGHT $WIDTH $CHOICE_HEIGHT \
                 "${array[@]}" \
                 2>&1 >$TERMINAL)
         i=$CHOICE
         k=$(($i+$i))
         ALIAS=${array[ $k ]}
         ;;
        9)A="$(wc -l peg_nodes.txt | cut -d ' ' -f 1 )" 
          dialog --title "Install new Masternode" \
          --backtitle "" \
          --yesno "Are you sure you want to install \nnew Masternode number $A ?" 7 40

          # Get exit status
          # 0 means user hit [yes] button.
          # 1 means user hit [no] button.
          # 255 means user hit [Esc] key.
          response=$?
          case $response in
            0) new_masternode $A  ;;
          esac
          ;;
        A) echo "IPV4 Address:" > ip_address
           ip addr show eth0 | grep -vw "inet6" | grep "global" | grep -w "inet" | cut -d/ -f1 | awk '{ print $2 }'  >> ip_address 
           echo " " >>ip_address
           echo "IPV6 Address:" >> ip_address
           ip addr show eth0 | grep -vw "inet" | grep "global" | grep -w "inet6" | cut -d/ -f1 | awk '{ print $2 }'  >> ip_address
           dialog --textbox "ip_address" 0 0           
           ;;
        0) break;;
esac

done

# if temp files found, delete em
[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT
