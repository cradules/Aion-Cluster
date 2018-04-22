#!/bin/bash
#set -x
##############################################################################
#Main script will verify if "brother is awake" and will take the decision if 
# stays or goes to sleep!
##############################################################################

#Create log
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/var/log/cluster.log 2>&1


. ./cluster.cfg

#Check if brother is alive
timeout 2 bash -c "</dev/tcp/$BROTHER/3333" >/dev/null 2>&1
RC=$(echo $?)
if [ $RC -eq 0 ]
	then
        echo "Brother $BROTHER is up"
else
	echo "Brother $BROTHER down"
	echo "Checking services local"
	
	#Check if the services are runing on current server
	timeout 2 bash -c "</dev/tcp/$HOSTNAME/3333" >/dev/null 2>&1
	RC=$(echo $?)
	if [[ $RC -eq 0 ]]
        	then
        	echo "I am alive"
		#Check redis server
        	echo "Checking redis server"
        	timeout 2 bash -c "</dev/tcp/$HOSTNAME/6379" >/dev/null 2>&1
        	RC=$(echo $?)
			if [[ $RC -eq 0 ]]
                		then
                		echo "Redis Server is UP"
                		exit 0
        		else
                		echo "Redis Server is DOWN"
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
				az vm disk detach -g eu-we-prod-rg --vm-name $BROTHER -n $SHAREDDISK
				#Attach and mount disk to me
				az vm disk attach -g eu-we-prod-rg --vm-name $HOSTNAME --disk $SHAREDDISK
				pvscan
				vgscan
				lvscan
			fi
			mount /dev/vgcentryspool/lvcentryspool /pool-app
			echo "File systems is mounted"
		fi
				
		#Check if node is up
		timeout 2 bash -c "</dev/tcp/$HOSTNAME/8545" >/dev/null 2>&1
		RC=$(echo $?)
		if [[ $RC -eq 0 ]]
			then
			echo "Node is up"
		else
			#Stop backround proccess
			for y in `ps -ef | grep "./aion.sh" | grep -v "grep" | awk '{print $2}'`; do sudo kill -9 $y; done
			for y in `netstat -tenpl | grep -e 8547 -e 8545 -e 8080| awk '{print $9}' | awk -F '/' '{print $1}'`; do kill -9 $y; done
			#Start node services	
			echo "Starting node"
			cd /pool-app/node
			su -c "./aion.sh" crypto > /dev/null 2>&1 &
		fi
		#Clean up backround proccess
		for y in `netstat -tenpl | grep -v  -e 8547 -e 8545 -e 8080 | grep -e 3333 -e 6379| awk '{print $9}' | awk -F '/' '{print $1}'`; do kill -9 $y; done
		echo "Aion pool is down"
        	echo "Starting aion-pool"
        	cd /pool-app/aion-pool
       		su -c "./run.sh" crypto  > /dev/null 2>&1 &
	fi
exit 0

fi
