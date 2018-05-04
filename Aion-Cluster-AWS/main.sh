#!/bin/bash
#set -x
##############################################################################
#Main script will verify if "brother is awake" and will take the decision if 
# stays or goes to sleep!
##############################################################################

cd "$(dirname "$0")"
. ./cluster.cfg

ISMOUNT=$(grep -c -e pool-app -e nfs /etc/mtab)

#Check if brother is alive
timeout 2 bash -c "</dev/tcp/$BROTHER/3333" >/dev/null 2>&1
RC=$(echo $?)
if [ $RC -eq 0 ]
        then
        echo "$DATE Brother $BROTHER is up" >> $LOGFILE
        echo "$DATE Checkling NFS" >> $LOGFILE
        if [[ $ISMOUNT -eq 0 ]]
                then
                echo "$DATE Good..NFS not mounted" >> $LOGFILE
        else
                echo "$DATE Found..NFS as  mounted" >> $LOGFILE
                echo "$DATE Unmounting..." >> $LOGFILE
                /usr/local/bin/aionmount stop
                exit 0
        fi

else
	echo "$DATE Brother $BROTHER is down" >> $LOGFILE
	echo "$DATE Checking services if running locally" >> $LOGFILE
	
	#Check if the services are runing on current server
	timeout 2 bash -c "</dev/tcp/$HOSTNAME/3333" >/dev/null 2>&1
	RC=$(echo $?)
	if [[ $RC -eq 0 ]]
        	then
        	echo "$DATE I am alive" >> $LOGFILE
		#Check redis server
        	echo "$DATE Checking redis server" >> $LOGFILE
        	timeout 2 bash -c "</dev/tcp/$HOSTNAME/6379" >/dev/null 2>&1
        	RC=$(echo $?)
			if [[ $RC -eq 0 ]]
                		then
                		echo "$DATE Redis Server is UP" >> $LOGFILE
                		exit 0
        		else
                		echo "$DATE Redis Server is DOWN" >> $LOGFILE
      			fi

	else
		#Check if filesystem is mounted
		ISMOUNT=$(grep -c -e pool-app -e nfs /etc/mtab)
		if [[ $ISMOUNT -ne 1 ]]
			then
			#Attach and mount disk to me
			echo "$DATE Mounting $SHAREDDISK" >> $LOGFILE
			/usr/local/bin/aionmount start	
		else
			echo "$DATE Cant mount pool-app. Most probrablly the disk could not be attached" >> $LOGFILE
		fi
				
		#Check if node is up
		timeout 2 bash -c "</dev/tcp/$HOSTNAME/8545" >/dev/null 2>&1
		RC=$(echo $?)
		if [[ $RC -eq 0 ]]
			then
			echo "$DATE Node is up"  >> $LOGFILE
		else
			#Restart node
			 echo "$DATE Starting node" >> $LOGFILE
			systemctl restart  nodepool
		fi
		#Restart Aion Pool
		echo "$DATE Starting node"  >> $LOGFILE
		systemctl restart aionpool
		
	fi
exit 0

fi
