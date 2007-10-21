integer CHANNEL         = -12610672; // channel that scanners announce scanned agents on
integer CHAT_CHANNEL    = -12610671; // channel to send chat on
integer DRONE_CHANNEL   = -12610670; // channel to init drones on

string  CHAT_DRONE      = "chat drone"; // name of chat drones

float   PING_CHECK      = 30.0;
integer PING_TIMEOUT    = 60;

list    tracked_agents  = [];
list    pings           = [];

list    rez_queue       = [];
key     rez_waiting     = NULL_KEY;

integer
is_key(key in)
{
    if (in) return TRUE;
    return FALSE;
}

rez(key id)
{
    if ( id == NULL_KEY ) {
        rez_waiting = NULL_KEY;
        if ( rez_queue == [] ) {
            return;
        } else {
            id = llList2Key(rez_queue, 0);
            if ( rez_queue == [1] )
                rez_queue = [];
            else
                rez_queue = llList2List(rez_queue, 1, -1);
        }
    }

    if ( rez_waiting == NULL_KEY ) {
        rez_waiting = id;
        llOwnerSay("rez " + (string)id);
        llRezObject(CHAT_DRONE, llGetPos(), ZERO_VECTOR, ZERO_ROTATION, DRONE_CHANNEL);
        return;
    }
    rez_queue += id;
}

default {
    state_entry() {
        llOwnerSay("masterkey: " + (string)llGetKey() );
        llListen(CHANNEL, "", NULL_KEY, "");
        llSetTimerEvent(PING_CHECK);
        llRegionSay( CHAT_CHANNEL, "killall" );
    }

    timer() {
        integer len     = llGetListLength(pings);
        integer i       = 0;
        integer timeout = llGetUnixTime() - PING_TIMEOUT;
        for ( i = 0; i < len; ++i ) {
            if ( llList2Integer(pings, i) < timeout ) {
                llOwnerSay( llList2String(tracked_agents,i) + " timed out" );
                llRegionSay( CHAT_CHANNEL, "kill" + llList2String(tracked_agents,i) );
                tracked_agents  = llDeleteSubList( tracked_agents, i, i );
                pings           = llDeleteSubList( pings, i, i );
                --i;
                --len;
            }
        }
    }

    listen(integer channel, string name, key id, string msg) {
        if ( llGetOwnerKey(id) != llGetOwner() )
            return;

        if ( name == "PING" ) {
            integer i = llListFindList( tracked_agents, [(key)msg] );
            if ( i == -1 )
                return;
            pings = llListReplaceList( pings, [llGetUnixTime()], i, i );
            return;
        }

        if ( name == "GET" ) {
            llSay(DRONE_CHANNEL, (string)rez_waiting);
            rez(NULL_KEY);
            return;
        }

        if ( name == "REMOVE" ) {
            integer i = llListFindList( tracked_agents, [(key)msg] );
            if ( i == -1 )
                return;
            tracked_agents  = llDeleteSubList( tracked_agents, i, i );
            pings           = llDeleteSubList( pings, i, i );
            return;
        }

        list keys = llCSV2List(msg);
        integer i = llGetListLength(keys);
        while ( i-- ) {
            key k = llList2Key(keys, i);
            if ( is_key(k) ) {
                if ( llListFindList(tracked_agents, [k]) == -1 ) {
                    tracked_agents += k;
                    pings += [llGetUnixTime()];
                    rez(k);
                }
            }
        }
    }
}
