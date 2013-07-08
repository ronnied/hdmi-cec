#!/bin/bash
#
# Set up a fifo and connect cec-client to it
#
# By Will Cooke.  http://www.whizzy.org
# It's a very hacky solution, but it seems to just about work.
#
# Version 1.  Does the job.  November 2012
#

CECLOG=/tmp/cec.log
CECDEV=/dev/ttyACM0
CECFIFO=/tmp/cec.fifo
CECCLIENT="/usr/local/bin/cec-client -d 8 -p 1 -b 5 -t p -o MythTV -f $CECLOG $CECDEV"

log(){
    echo "SERVER:  $1" >> $CECLOG
}


stop(){
    # Kill the right proceses
    log "Begin shutting down..."
    # Using this hacky grep so that we only match those tail processes looking 
    # at /dev/null rather than, say, syslog
    declare -a TAILPIDS=(`ps aux | grep 'tailf /dev/null' | egrep -v grep | awk '{print $2}'`)
    declare -a CATPIDS=(`ps aux | grep 'cat $CECFIFO' | egrep -v grep | awk '{print $2}'`)
    if [ ${#TAILPIDS[@]} -gt 0 ]
        then
            # Found some old tail processes to kill
            log "Found some tail processes..."
            for i in "${TAILPIDS[@]}"
            do
                log "Killing $i"
                kill $i
            done
    fi

    if [ ${#CATPIDS[@]} -gt 0 ]
        then
            # Found some old cat processes to kill
            # It's unlikely we will ever get in here, because the previous tail
            # processes have been killed and so shut down this end of the pipe
            # already.
            log "Found some cat processes..."
            for i in "${CATPIDS[@]}"
            do
                log "Killing $i"
                kill $i
            done
    fi

    log "Asking cec-client to stop if it's running..."
    # Using signal 2, the same as a ctrl-c
    killall -s 2 cec-client 2> $CECLOG
    log "Trying to remove FIFO..."
    rm $CECFIFO 2> $CECLOG
    log "Done shutting down."
}

case "${1}" in
    start|restart)
        log "Starting server.  Since only one server can run at a time, stopping first."
        stop
        log "Done stopping, now starting..."
        log "Setting up FIFOs..."
        # We use a FIFO to pass in CEC commands to the cec-client which comes
        # with libcec.
        mkfifo $CECFIFO
        log "Open pipe for writing..."
        # We use tailf /dev/null because it doesn't disconnect from stdin when
        # put in the background and it doesn't cause any load when running.
        tailf /dev/null > $CECFIFO &
        log "Opening pipe for reading and start cec-client..."
        # Since we're writing to a log file anyway we don't need the output from
        # cec-client.  Put the whole thing in brackets to background the lot.
        (cat $CECFIFO | $CECCLIENT &) > /dev/null
        log "Start up complete."
    ;;
    
    stop)
        stop
    ;;

    *)
        echo $"Usage: $0 {start|stop|restart}"
        exit 1
esac

exit 0

