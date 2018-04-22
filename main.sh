#!/bin/bash
#set -x
##############################################################################
#Main script will verify if "brother is awake" and will take the decision if 
# stays or goes to sleep!
##############################################################################

#Create log
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/var/log/cluster.log 2>&1

cd "$(dirname "$0")"
. ./cluster.cfg

#Check if brother is alive
timeout 2 bash -c "</dev/tcp/$BROTHER/3333" >/dev/null 2>&1
RC=$(echo $?)
if [ $RC -eq 0 ]
	then
        echo "$DATE Brother $BROTHER is up"
	exit 0
else
	echo "$DATE Brother $BROTHER is down"
	echo "$DATE Checking services if running locally"
	
	#Check if the services are runing on current server
	timeout 2 bash -c "</dev/tcp/$HOSTNAME/3333" >/dev/null 2>&1
	RC=$(echo $?)
	if [[ $RC -eq 0 ]]
        	then
        	echo "$DATE I am alive"
		#Check redis server
        	echo "$DATE Checking redis server"
        	timeout 2 bash -c "</dev/tcp/$HOSTNAME/6379" >/dev/null 2>&1
        	RC=$(echo $?)
			if [[ $RC -eq 0 ]]
                		then
                		echo "$DATE Redis Server is UP"
                		exit 0
        		else
                		echo "$DATE Redis Server is DOWN"
      			fi

	else
		#Check if filesystem is mounted
		ISMOUNT=$(grep -c pool-app /proc/mounts)
		if [[ $ISMOUNT -ne 1 ]]
			then
			#Check what VM manage the disk
			DISKMANAGER=$(az disk list | grep -A 3 $SHAREDDISK | grep -A 2 -w id | grep "managedBy" | awk -F '/' '{print$9}' | tr -d '"' | tr -d ',')
			#If the disk is not managed by me
			if [[ "$DISKMANAGER" != "$HOSTNAME" ]] 
				then
				#Detach disk from brother
				echo "$DATE Detaching $SHAREDDISK from $BROTHER"
				az vm disk detach -g eu-we-prod-rg --vm-name $BROTHER -n $SHAREDDISK
				#Attach and mount disk to me
				echo "$DATE Attaching $SHAREDDISK to $HOSTNAME"
				az vm disk attach -g eu-we-prod-rg --vm-name $HOSTNAME --disk $SHAREDDISK
				/sbin/pvscan
				/sbin/vgscan
				/sbin/lvscan
<<<<<<< HEAD
			fi
			ISVG=$(ls -al /dev/ | grep -c vgcentryspool)
			if  [[ $ISVG -eq 1 ]]
				then
				echo "$DATE Mounting $SHAREDDISK"
				mount /dev/vgcentryspool/lvcentryspool /pool-app
				echo "$DATE File systems is mounted"
			else
				"$DATE Cant mount pool-app. Most probrablly the disk could not be attached"
=======
>>>>>>> 285d1be1a1f2fa0c4142e91091cd995f8582da90
			fi
		fi
				
		#Check if node is up
		timeout 2 bash -c "</dev/tcp/$HOSTNAME/8545" >/dev/null 2>&1
		RC=$(echo $?)
		if [[ $RC -eq 0 ]]
			then
			echo "$DATE Node is up"
		else
			#Stop backroound proccess
			echo "$DATE Node is down..."
			for y in `ps -ef | grep "./aion.sh" | grep -v "grep" | awk '{print $2}'`; do sudo kill -9 $y; done
			for y in `netstat -tenpl | grep -e 8547 -e 8545 -e 8080| awk '{print $9}' | awk -F '/' '{print $1}'`; do kill -9 $y; done
			#Start node services	
			echo "$DATE Starting node"
			cd /pool-app/node
			su -c "./aion.sh" crypto > /dev/null 2>&1 &
		fi
		#Clean up backround proccess
		for y in `netstat -tenpl | grep -v  -e 8547 -e 8545 -e 8080 | grep -e 3333 -e 6379| awk '{print $9}' | awk -F '/' '{print $1}'`; do kill -9 $y; done
		echo "$DATE Aion pool is down"
        	echo "$DATE Starting aion-pool"
        	cd /pool-app/aion-pool
       		su -c "./run.sh" crypto  > /dev/null 2>&1 &
	fi
exit 0

fi
