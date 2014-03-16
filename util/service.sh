#!/bin/bash
script="coffee start.coffee"
PIDFILE="./pid"
LOGFILE="./log"
cmd() {
    nohup $script 2>&1 >> $LOGFILE & 
    echo $! > $PIDFILE
}
if [[ -f $PIDFILE ]];then 
    read -r PID < "$PIDFILE"
    # prevent stale pidfiles from hanging around
    if [[ ! -d /proc/$PID ]]; then
	echo 'pid not found. deleteing stale pidfile'
	unset PID
	rm -f "$PIDFILE"
    fi
fi

case "$1" in
    start)
	echo "starting..."
	if [[ $PID ]]
	then
	    echo "already running"
	    echo "fail to start."
	    exit 1
	fi
	cmd
	;;
    stop)
	echo "stopping..."
	if [[ $PID ]]
	then
	    kill $PID && rm -f $PIDFILE
	    echo "stopped successfully"
	    exit 0
	else
	    echo "pid not found"
	    echo "fail to stop"
	    exit 1
	fi
	;;
    restart)
	$0 stop
	sleep 1
	$0 start
	;;
    *)
	echo "usage $0 {start|stop|restart}"
esac
	
