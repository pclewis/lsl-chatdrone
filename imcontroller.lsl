integer IM_CHANNEL      = -12610699; // channel to request IMs on
integer SLAVE_CHANNEL   = -12610000; // starting channel for slaves
vector  FIRST_POS       = <194.5, 139.0, 24.5>;
vector  OFFSET          = <0.0, -2.0, 0.0>;
integer PING_CHECK      = 15;
integer PING_TIMEOUT    = 30;

integer MAX_SLAVES      = 5;
list    pings           = [-1, -1, -1, -1, -1];
integer current_slave   = 0;

default {
    state_entry() {
        llListen(IM_CHANNEL, "", NULL_KEY, "");
        integer i;
        llSetObjectName("reset");
        for ( i = 0; i < 5; ++i )
            llRegionSay( SLAVE_CHANNEL+i, "reset" );
        llSetTimerEvent(PING_CHECK);
    }

    timer() {
        integer i = MAX_SLAVES;
        integer timeout = llGetUnixTime() - PING_TIMEOUT;
        while ( i-- ) {
            if ( llList2Integer(pings, i) < timeout ) {
                llSetObjectName("reset");
                llRegionSay( SLAVE_CHANNEL + i, "reset" );
                pings = llListReplaceList( pings, [-1], i, i );
            }
        }
    }

    listen(integer channel, string name, key id, string msg) {
        if ( name == "ping" ) {
            integer idx = (integer)msg - SLAVE_CHANNEL;
            pings = llListReplaceList( pings, [llGetUnixTime()], idx, idx );
            return;
        }
        if ( name == "register" ) {
            integer idx = llListFindList( pings, [-1] );
            if ( idx == -1 ) {
                llRegionSay((integer)msg, "full");
                return;
            }
            llRegionSay( (integer)msg,
                         (string)(SLAVE_CHANNEL + idx) +
                         "|" +
                         (string)(FIRST_POS + (OFFSET * idx)) );
            pings = llListReplaceList( pings, [llGetUnixTime()], idx, idx );
            return;
        }

        if ( (key)name ) {

            // no slaves, can't do anything
            if ( llListFindList( pings, [-1,-1,-1,-1,-1] ) == 0 )
                return;

            do {
                if ( ++current_slave >= MAX_SLAVES )
                    current_slave = 0;
            } while ( llList2Integer( pings, current_slave ) == -1 );
            llSetObjectName(name);
            llRegionSay( SLAVE_CHANNEL + current_slave, msg );

        }
    }
}
