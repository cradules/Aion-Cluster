#!/bin/bash
set -x
cd "$(dirname "$0")"
. ./cluster.cfg

ISMOUNT=$(grep -c -e pool-app -e nfs /etc/mtab)
ROLE=$(ls /usr/local/cluster/role/)

	if [[ $ROLE = "master" ]]
		then
		#Check if slave is down
		timeout 2 bash -c "</dev/tcp/$BROTHER/3333" >/dev/null 2>&1
		RC=$(echo $?)
		if [[ $RC -ne 0 ]]
			then
			#Check if NFS mont
			if [[ $ISMOUNT -eq 0 ]]
				then
				/usr/local/bin/aionmount start
			else
				echo "NFS is mounted"
			fi
			
			timeout 2 bash -c "</dev/tcp/localhost/8545" >/dev/null 2>&1
			RC=$(echo $?)
			if [[ $RC -ne 0 ]]
				then
				systemctl restart nodepool
			else
				echo "Node is up"
			fi
			timeout 2 bash -c "</dev/tcp/localhost/3333" >/dev/null 2>&1
			RC=$(echo $?)
			 if [[ $RC -ne 0 ]]
				then
				systemctl restart aionpool
			else
				echo "Pool is up"
			fi
		else
			echo "$BROTHER is up"
			exit 0
		fi
	elif [[ $ROLE = "slave" ]]
		then
		#Check if Master VM is up
		for ((i=0; i<2; i++))
		do
			ping -c 2 $BROTHER
			RC=$(echo $?)
			#If is not up wait 60 secounds and check again
			if [[ $RC -ne 0 && $i -ne 2 ]]
				then
				sleep 60
			#If the VM respond to ping check application
			elif [[ $RC -eq 0 ]] 
				then
				for ((y=0; y<=2; y++))
				do
					timeout 2 bash -c "</dev/tcp/$BROTHER/3333" >/dev/null 2>&1
					RC=$(echo $?)
					#If the application is not up wait 60 secounds and check again
					if [[ $RC -ne 0 && $y -ne 2 ]] 
						then
						sleep 60
					#If the application is not up in 120 secounds on master start on slave
					elif [[ $RC -ne 0 && $y -eq 2 ]]
						then
						#Mount NFS
						/usr/local/bin/aionmount start
						#Start node
						systemctl start nodepool
						#Start Pool
						systemctl start aionpool
						exit 0
					else 
						echo "Application is running on master"
						exit 0
					fi
				done
			
			fi
		done

		
	fi
