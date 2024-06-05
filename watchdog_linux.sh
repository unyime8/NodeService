#!/bin/bash

logFile="/tmp/watchdog.log"
saveLog() {
	echo "$(date +"%Y-%m-%d %H:%M:%S"): $*" >> $logFile
}

checkRunning() {
	sudo docker ps -a | grep 'jack0818/watchdog' | grep -v grep | awk '{print $1}' | xargs sudo docker container inspect | grep '"Status": "running"'
        if [ $? -eq 0 ];then
                return 1;
        fi
        return 2;
}

SCRIPT_NAME="$(basename "$0")"
CURRENT_PID=$$
CURRENT_USER=$(whoami)
echo "SCRIPT_NAME: " $SCRIPT_NAME " CURRENT_PID: " $CURRENT_PID " CURRENT_PID1: " $CURRENT_PID1 " CURRENT_USER: " $CURRENT_USER
sudo ps -ef | grep "$SCRIPT_NAME" | grep -v "$CURRENT_PID" | grep -v grep | awk '{print $2}' | xargs sudo kill -9 &> /dev/null

read -p "Please input your wallet address: " wallet
echo "your wallet: " $wallet

#sudo apt install net-tools -y &> /dev/null
#sudo apt install telnet -y &> /dev/null
#sudo yum install -y net-tools &> /dev/null
#sudo yum install -y telnet &> /dev/null
#sudo yum install -y wget &> /dev/null
#sudo apt install wget -y &> /dev/null

archType=`arch`
result1=$(echo $archType | grep "arm")
result2=$(echo $archType | grep "aarch64")
NameSpaceRepo=""
if [[ "$result1" != "" || "$result2" != "" ]]
then
    echo "this is arm cpu " $archType
    NameSpaceRepo="jack0818/watchdog_arm"
   

else
    echo "this is x86 cpu " $archType
    NameSpaceRepo="jack0818/watchdog_x86"
fi

startrun() {
    sudo docker ps -a | grep 'jack0818/watchdog'  | awk '{print $1}' | xargs sudo docker stop 2> /dev/null | xargs sudo docker rm &> /dev/null
    sudo docker pull $NameSpaceRepo:latest
    sudo docker run --log-opt max-size=1000m --log-opt max-file=6 --name=sdn_watchdog -d -e offIdxNode=https://indexedge.sending.network:14431 -e ForbitCacheStoreEndpoint=true -e ForbitIDServer=true  -e disableMdns=true -e port=8128 -e ipfs=false -e name=watchdog  -e mainNet=true -e watchDog=4  -e payWalletEdgeNode=$wallet -e peer=/dns4/node9.sending.network/tcp/9085/ws/p2p/12D3KooWEF152H6MvV1E3wM9zZnQmdNYhpfvvqSYmDG212hY8Gxx,/dns4/node8.sending.network/tcp/9085/ws/p2p/12D3KooWADgj19tnYWRuqGvevvTBCQUmLTWdzssMCMD1TcieUoYF -v ./p2pnode/logs:/p2pnode/logs -v ~/WatchdogNode/run/watchdog:/p2pnode/run/watchdog $NameSpaceRepo:latest
    sudo docker ps -a | grep `sudo docker image ls | grep 'jack0818/watchdog' | grep -v latest  | awk '{print $3}'` | awk '{print $1}' | xargs sudo docker stop | xargs sudo docker rm &> /dev/null
    sudo docker images | grep 'jack0818/watchdog' | grep -v latest | awk '{print $3}' | xargs  sudo docker rmi &> /dev/null
}

StartRun() {
    startrun
    sleep 15
    p=$(sudo docker logs "`sudo docker ps -a | grep 'jack0818/watchdog' | awk '{print $1}'`" 2> /dev/null | tail -n 1000 | grep 'level=fatal')
    echo $p | grep "NATS" &> /dev/null
    if [ $? -eq 0 ];then
       sudo rm -rf ~/WatchdogNode/run/watchdog/jetstream
       saveLog "`date` del NATS files"
    fi
}

installCentosDocker() {
        sudo docker -v
        if [ $? -eq 0 ];then
                echo "docker pg has been installed"
                return 0;
        fi
        sudo yum install -y yum-utils device-mapper-persistent-data lvm2
        if [ $? -ne 0 ];then
                echo "docker install failed 1"
                exit 1;
        fi
        sudo yum-config-manager --add-repo http://download.docker.com/linux/centos/docker-ce.repo
        if [ $? -ne 0 ];then
                echo "docker install failed 2"
                exit 1;
        fi
        sudo yum -y install docker-ce-24.0.5
        if [ $? -ne 0 ];then
                echo "docker install failed 3"
                exit 1;
        fi
        sudo systemctl start docker
        if [ $? -ne 0 ];then
                echo "docker install failed 4"
                exit 1;
        fi
        sudo systemctl enable docker
        if [ $? -ne 0 ];then
                echo "docker install failed 5"
                exit 1;
        fi
}

installUbuntuDocker() {
        sudo docker -v
        if [ $? -eq 0 ];then
                echo "docker pg has been installed"
                return 0;
        fi
        sudo apt-get remove docker docker-engine docker.io containerd runc
        sudo apt update -y && sudo apt upgrade -y
        if [ $? -ne 0 ];then
                echo "docker install failed 2"
                exit 1;
        fi
        sudo apt-get -y install ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common
        if  [ $? -ne 0 ];then
                echo "docker install failed 3"
                exit 1;
        fi
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
        if [ $? -ne 0 ];then
                echo "docker install failed 4"
                exit 1;
        fi
        sudo apt-get -y install docker-ce docker-ce-cli containerd.io
        if [ $? -ne 0 ];then
                echo "docker install failed 5"
                exit 1;
        fi
        sudo usermod -aG docker $USER
        sudo systemctl start docker
        sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
        sudo systemctl enable docker.service
        sudo service docker restart

}

getOsArch() {
	a=`arch`
	strA="x86"
	strB="x86_64"
	strC="aarch"
	result=$(echo $a | grep "${strC}")
	if [[ "$result" != "" ]]
	then
		echo "this is arm cpu arch:" $a
    		return 2;
	else
		echo "this is not arm cpu arch:" $a
    		return 1;
	fi
}

getOsName() {
        a=`uname  -a`
        public_string="Linux"

        D="Darwin"
        C="CentOS"
        U="Ubuntu"

        FILE_EXE=/etc/redhat-release
        if [ -f "$FILE_EXE" ];then
                if [[ `cat /etc/redhat-release` =~ $C ]];then
                        return 2;
                fi
        fi


        if [[ $a =~ $D ]];then
                return 1;
        elif [[ $a =~ $C ]];then
                return 2;
        elif [[ $a =~ $U ]];then
                return 3;
        else
            sudo yum install -y wget
            if [ $? -eq 0 ];then
                echo "this is centos"
                return 2
            fi
            sudo apt-get install -y wget
            if [ $? -eq 0 ];then
                echo "this is ubuntu"
                return 3
            fi
            echo "Error checking system type: only Ubuntu and CentOS are supported."
            return 4;
        fi
}

UpdateVer() {
    sudo rm -rf $logFile &> /dev/null
    image="$archType"
    while true
    do
        sleep 20
        localImageId=`sudo docker images | grep "$NameSpaceRepo" | grep "latest" | awk '{print $3}'`
        sudo docker pull $NameSpaceRepo:latest >> $logFile
        newImageId=`sudo docker images | grep "$NameSpaceRepo" | grep "latest" | awk '{print $3}'`
        if [ "$localImageId" !=  "$newImageId" ];then
            saveLog "need update old image: " $localImageId " new image: " $newImageId
            StartRun
        else
            saveLog echo "no need update image: " $localImageId
        fi
	
	sleep 10
        checkRunning
        if [ $? -eq 2 ];then
            saveLog echo "dog has existed, start" 
            StartRun
        fi
    done
}

getOsName
sysType=$?
echo "sysType:" $sysType
if [ $sysType -eq 2 ];then
        installCentosDocker
elif [ $sysType -eq 3 ];then
        installUbuntuDocker
else
        echo "Unsupported operating system detected. Please select either CentOS or Ubuntu."
        exit 1;
fi
sudo docker ps -a | grep 'jack0818/watchdog'  | awk '{print $1}' | xargs sudo docker stop 2> /dev/null | xargs sudo docker rm 2> /dev/null

StartRun
checkRunning
if [ $? -eq 1 ];then
   echo "The WatchDog node is up and running."
else
    p=$(sudo docker logs "`sudo docker ps -a | grep 'jack0818/watchdog' | awk '{print $1}'`" 2> /dev/null | tail -n 1000 | grep 'level=fatal')
    echo $p | grep "not supported country" &> /dev/null
    if [ $? -eq 0 ];then
        echo "Unable to start Watchdog node. "
	echo "Node service is not supported in this IP country."
    else
        echo $p | grep "IsWhite err" &> /dev/null
        if [ $? -eq 0 ];then
                echo "Unable to start Watchdog node. "
		echo "Please use a whitelisted wallet address."
        else
		echo $p | grep "only one watchdog limit" &> /dev/null
		if [ $? -eq 0 ];then
			echo "Unable to start Watchdog node. "
        		echo "Only one WatchDog node can be run per wallet address."
		else
                	echo "Unable to start Watchdog node."
		fi
        fi
    fi
    exit 1;
fi
UpdateVer &> /dev/null &

