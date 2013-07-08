#!/bin/bash
#
# Execute some fairly simple CEC commands
# Can use the "server" if its already running for faster execution
# or will fall back to starting the cec-client in "single pass" mode.
#
# Another terrible hack from Will Cooke.  http://www.whizzy.org
#
# Handy site: http://www.cec-o-matic.com/
# 
# Version 1.  Seems to work. Nov. 2012
#

CECLOG=/tmp/cec.log
CECDEV=/dev/ttyACM0
CECFIFO=/tmp/cec.fifo
CECCLIENT="/usr/local/bin/cec-client -s -d 8 -p 1 -b 5 -t p -o MythTV $CECDEV"


log(){
    echo "SIMPLE CLIENT:  $1" >> $CECLOG
}

send_command(){
    if [ $CECCLIENTAVAIL == true ]
        then
            # We've tested for the "server", and it seems to be running
            # Basically we dont have to start cec-client from scratch which
            # saves about 4 seconds, so things like volume control are a bit
            # more responsive.
            log "Using server to send CEC packets $1 ..."
            echo $1 > $CECFIFO
        else
            # Server wasn't found to be running, so start cec-client
            # just for this one command.
            # Why is this here?  Well, sometimes when you come out of suspend
            # the cec-client, and so the "server" drops the connection to the
            # USB CEC device and so quits.  This means that we can always send
            # commands regarless of the state of the server.
            log "Using single run cec-client to send packets ( $1 ) ..."
            echo $1 | $CECCLIENT
    fi
}

# We should check if the server is running, because if it is we should use it.
CECCLIENTPID=`pidof cec-client`
if [ $? -lt 1 ]
    then
        # cec-client is /probably/ running ok
        CECCLIENTAVAIL=true
        log "Main server seems to be alive.  We will use that instead."
    else
        CECCLIENTAVAIL=false
fi


# Here are the commands we know how to support

case "${1}" in
    tvon)
        # "on" is supported by cec-client, it's a kind of short cut to the
        # hex codes.  0 is always the destination address of the TV.
        send_command "on 0"
        # Make sure something appears on the TV we've just switched on
	    xscreensaver-command -deactivate
    ;;
    
    tvoff)
        # "standby" is also supported by cec-client
        send_command "standby 0"
    ;;

    ampon)
        #address 5 is the "audio system" in an HDMI network
        send_command "on 5"
    ;;

    ampoff)
        # My Sony Amp doesn't support "standby" for some reason, so instead
        # I poke it like this...
        send_command "tx 45 44 6C"
        # 45 means from 4 (me, the playback device) to 5(amp)
        # 44 6C means "the user pressed the power off button, nap time"
    ;;

    allon)
        # address f is the broadcast address.  Haven't actually tested this.
        send_command "on f"
    ;;

    alloff)
        # same
        send_command "standby f"
    ;;

    activesrc)
        # Me (4) to broadcast (f) -> I am now the active source, switch to me.
        # 82 "switch to", 1100 = address 1.1.0.0 the first device on dev 1 (amp)
        # 1.2.0.0 would be the 2nd sub device on device 1
        # 2.1.0.0 would be the 1st sub device on device 2
        send_command "tx 4F 82 11 00"
    ;;
	
    mute)
        # Me to TV -> user pressed mute
		send_command "tx 40 44 43"
	;;
	
    volup)
        # Me to TV -> user pressed vol up
		send_command "tx 40 44 41"
	;;
   
	voldown)
        # Me to TV -> user pressed vol down
		send_command "tx 40 44 42"
	;;

    *)
        echo $"Usage: $0 {tvon|tvoff|ampon|ampoff|allon|alloff|activesrc|mute|volup|voldown}"
        exit 1
    ;;
esac

exit 0

