# redis-reshard
migrate slots manually on redis cluster



sh manual-reshard.sh -h
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


i.e. /usr/local/redis30/bin/manual-reshard.sh -s 10.0.0.1:6991 -d 10.0.0.2:6992 -S 5000 -E 6000
i.e. /usr/local/redis30/bin/manual-reshard.sh -s 10.0.0.1:6991 -d 10.0.0.2:6992 -S 5000 -E 6000 -a run

manual-reshard.sh will call check_trib.rb   





