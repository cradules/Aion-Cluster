#!/bin/bash
#set -x
cd "$(dirname "$0")"
. ./cluster.cfg

ISMOUNT=$(grep -c -e pool-app -e nfs /etc/mtab)
ROLE=$(ls /usr/local/cluster/role/)

countdown() {
	row=2
	col=2
        msg="Making sure master is not runnig, pleae be pacient ${1}..."
        clear
        tput cup $row $col
        echo -n "$msg"
        l=${#msg}
        l=$(( l+$col ))
        for x in {30..1}
        do
                tput cup $row $l
                echo -n "$x"
                sleep 1
        done
	clear
}
start(){

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
				echo "NFS is already mounted"
			fi
			
			timeout 2 bash -c "</dev/tcp/localhost/8545" >/dev/null 2>&1
			RC=$(echo $?)
			if [[ $RC -ne 0 ]]
				then
				systemctl restart nodepool
			else
				echo "Node is already running"
			fi
			timeout 2 bash -c "</dev/tcp/localhost/3333" >/dev/null 2>&1
			RC=$(echo $?)
			 if [[ $RC -ne 0 ]]
				then
				systemctl restart aionpool
			else
				echo "Pool is already running"
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
			ping -c 2 $BROTHER > /dev/null 2>&1 
			RC=$(echo $?)
			#If is not up wait 60 secounds and check again
			if [[ $RC -ne 0 && $i -ne 2 ]]
				then
				#sleep 60
				countdown
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
						#sleep 60
						countdown
					#If the application is not up in 120 secounds on master start on slave
					elif [[ $RC -ne 0 && $y -eq 2 ]]
						then
						#Mount NFS
						#Check if NFS is mounted
                       				 if [[ $ISMOUNT -eq 0 ]]
                                			then
                                			/usr/local/bin/aionmount start
                        			else
                                			echo "NFS is already mounted..."
                        			fi
						#Start node
						timeout 2 bash -c "</dev/tcp/localhost/8545" >/dev/null 2>&1
						RC=$(echo $?)
						if [[ $RC -ne 0 ]]
							then
							systemctl restart nodepool
						else
							echo "Node is already running..."
						fi
						#Start Pool
						timeout 2 bash -c "</dev/tcp/localhost/3333" >/dev/null 2>&1
						RC=$(echo $?)
						if [[ $RC -ne 0 ]]
							then
							systemctl restart aionpool
						else
							echo "Pool is already running..."
						fi
						exit 0
					else 
						echo "Application is running on master"
						exit 0
					fi
				done
			
			fi
		done

		
	fi
}

stop(){
#Start Pool
systemctl stop aionpool

#Stop node
systemctl stop nodepool

#Umount NFS
/usr/local/bin/aionmount stop
}


case "$1" in
        start)
		echo "Starting services..."
		sleep 1 
		start
        ;;
        stop)
                echo "Stopping services.." >&2
                stop
        ;;
        retart)
                echo "Stopping services.." >&2
                stop
                echo 'Starting service…' >&2
                start
        ;;
  *)
        echo "Usage: $0 {start|stop|restart}"
esac

