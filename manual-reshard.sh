#!/bin/sh
### author: guweitao
### date: 2017-03-21
### func: migrate slots from src node to dest node
### [note]:when migrate slots,the keys from src to dest retain its expiretime.
### redis version:3.0.7 linux: centos 6.6


## src_server 10.11.11.11:6991
## dest_server 10.11.11.12:6992
## start_slot 5460
## end_slot   6000

rediscli=/usr/local/redis30/bin/redis-cli
#redistrib=/usr/local/redis30/bin/redis-trib.rb
redistrib=/usr/local/redis30/bin/check_trib.rb

function usage()
{
echo "
USAGE:
        migrate slot from src node to dest node
OPTION:
        -s src_server
        -d dest_server
        -S start_slot
        -E end_slot
        -a action
           value:check|run
           check:check cluster nodes & info
           run:migrate slot
           default value is check
        -h help

i.e. $0 -s 10.0.0.1:6991 -d 10.0.0.2:6992 -S 5000 -E 6000
i.e. $0 -s 10.0.0.1:6991 -d 10.0.0.2:6992 -S 5000 -E 6000 -a run
"
exit 1
}

while getopts s:d:S:E:a:h OPTION
do
   case "$OPTION" in
       s)src_server=$OPTARG
       ;;
       d)dest_server=$OPTARG
       ;;
       S)start_slot=$OPTARG
       ;;
       E)end_slot=$OPTARG
       ;;
       a)action=$OPTARG
       ;;
       h)usage;
         exit 0
       ;;
       *)usage;
         exit 1
       ;;
   esac
done

if [ -z $src_server ] || [ -z $dest_server ] || [ -z $start_slot ] || [ -z $end_slot ]
then
        usage
fi

if [ -z $action ]
then
        action=check
else
        if [ "$action" != "run" ] && [ "$action" != "check" ]
        then
                echo "[ERROR]: invalid option,please check!"
                usage
        fi
fi

src_host=`echo $src_server|awk -F':' '{print $1}'`
src_port=`echo $src_server|awk -F':' '{print $2}'`

dest_host=`echo $dest_server|awk -F':' '{print $1}'`
dest_port=`echo $dest_server|awk -F':' '{print $2}'`

src_nodeid=`$rediscli -p $src_port -h $src_host  cluster myid |awk -F'"' '{print $1}'`
dest_nodeid=`$rediscli -p $dest_port -h $dest_host  cluster myid | awk -F'"' '{print $1}'`

if [ -z $src_nodeid ]
then
        echo "[ERROR]: please input src master of $src_oort,exit now!"
        exit 1
fi

if [ -z $dest_nodeid ]
then
        echo "[ERROR]: please input dest master of $dest_port,exit now!"
        exit 1

fi

function dest_import()
{

for slot in `seq ${start_slot} ${end_slot}`
do
        errmsg=`$rediscli -c -p $dest_port -h $dest_host  cluster setslot ${slot} IMPORTING  $src_nodeid`
        if [ ! -z "`echo "$errmsg"|egrep ERR`"  ]
        then
                echo $errmsg
                exit 1
        else
                echo "[info]: importing $slot OK"
        fi
done

}

function src_migrating()
{
for slot in `seq ${start_slot} ${end_slot}`
do
        #$rediscli -c -p  $src_port -h $src_host  cluster setslot ${slot} MIGRATING $dest_nodeid
        errmsg=`$rediscli -c -p  $src_port -h $src_host  cluster setslot ${slot} MIGRATING $dest_nodeid`
        if [ ! -z "`echo $errmsg|egrep ERR`" ]
        then
		echo $errmsg
                exit 1
        else
                echo "[info]: migrating $slot OK"

        fi
done

}

function src_migrate_key()
{
for slot in `seq ${start_slot} ${end_slot}`
do
	while true
	do
		allkeys=`$rediscli -c -p $src_port -h $src_host cluster getkeysinslot ${slot} 20`
		if [  -z "${allkeys}" ]  
		then
                        break
                else
                        for key in ${allkeys}
                        do
                                echo "slot:${slot} key: ${key}"
                                $rediscli -c -p $src_port -h $src_host  MIGRATE $dest_host $dest_port  ${key} 0 7200
                                if [ $? -ne 0 ]
                                then
                                        echo "[ERROR]: $src_server migrate $key to $dest_server failed,please check!"
                                        exit 1
                                else
                                        echo "[info]: $src_server migrate $key to $dest_server OK"
                                fi
                        done
                fi
        done
done


}

function node_slot()
{
for slot in `seq ${start_slot} ${end_slot}`
do
	for node in `$rediscli -p $src_port -h $src_host cluster nodes |egrep master |awk '{print $2}'`
	do
		host=`echo $node|awk -F':' '{print $1}'`
		port=`echo $node|awk -F':' '{print $2}'`
		errmst=`$rediscli -p $port -h $host cluster setslot ${slot} NODE $dest_nodeid`

		if [ -z "`echo \"$errmst\" |egrep OK`"  ]
		then
			echo "[ERROR]: ${host}:${port} $errmst"
		else
			echo "[info]: node $slot OK on  $node"
		fi

	done
done
}

function check_nodes()
{
echo ""
echo "Now we will check nodes,please wait..."
sleep 3
echo "[from $src_server]"
#$rediscli -p $src_port -h $src_host cluster saveconfig
$redistrib check $src_server
$rediscli -p $src_port -h $src_host cluster info
echo ""
echo "*	*	*"
echo ""
echo "[from $dest_server]"
$redistrib check $dest_server
$rediscli -p $dest_port -h $dest_host cluster info

}


main()
{
if [ $action = check ]
then
        check_nodes
elif [ $action = run ];then
        dest_import
        src_migrating
        src_migrate_key
	node_slot
        check_nodes
fi
}

main

