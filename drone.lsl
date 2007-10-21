integer MASTER_CHANNEL = -12610672; // channel to communicate with master on
integer CHAT_CHANNEL   = -12610671; // channel to listen for chat on
integer IM_CHANNEL     = -12610699; // channel to request IMs on

string  BEACON_NAME         = "/chat/beacon";
integer BEACON_DISTANCE     = 32;
integer BEACON_INTERVAL     = 5;
string  MYSTERY_LOCATION    = "???";
float   TIMEOUT             = 30.0;
integer PING_TIME           = 30;

integer ping                = 0;

key     target              = NULL_KEY;

list    recent_msgs         = [1, 2, 3, 4, 5]; // length will be kept constant

string  location            = "???";
integer target_present      = FALSE;

key     master_key          = NULL_KEY;


chat(string name, string msg) {
    llSetObjectName(location + "," + name);
    llRegionSay(CHAT_CHANNEL, msg);
}

send_target(string msg) {
    llSetObjectName(target);
    llRegionSay(IM_CHANNEL, msg);
}

default {
    state_entry() {
        llSetStatus(STATUS_PHYSICS|STATUS_ROTATE_X|STATUS_ROTATE_Y|STATUS_ROTATE_Z, FALSE);
        llSetObjectName("chat drone");
    }

    on_rez(integer id) {
        llListen( id, "", NULL_KEY, "" );
        llOwnerSay("init: " + (string)id);
        llSetObjectName("GET");
        llSay( MASTER_CHANNEL, "GET");
    }

    listen(integer channel, string name, key id, string msg) {
        if ( llGetOwnerKey(id) != llGetOwner() )
            return;

        master_key = id;
        target = msg;
        state active;
    }
}

state active {
    state_entry() {
        llOwnerSay("target: " + "<" + (string)target + ">");

        vector pos = llGetPos();
        llSetStatus(STATUS_PHYSICS | STATUS_PHANTOM, TRUE);
        llMoveToTarget(pos, 0.1);
        llSetTimerEvent(1.0);

        // Listen on 0 MUST come first.
        llListen( 0, "", NULL_KEY, "" );
        llListen( CHAT_CHANNEL, "", NULL_KEY, "" );

        llSensorRepeat( BEACON_NAME, NULL_KEY, PASSIVE, BEACON_DISTANCE, PI, BEACON_INTERVAL );
    }

    timer() {
        vector pos = ZERO_VECTOR;

        list d = llGetObjectDetails(target, [OBJECT_POS]);
        if ( d != [] ) {
            pos = llList2Vector(d,0);
            // sanity check
            if ( pos.x < 0 || pos.x > 256 || pos.y < 0 || pos.y > 256 )
                pos = ZERO_VECTOR;
        }

        if ( pos == ZERO_VECTOR ) {
            target_present = FALSE;
            if ( llGetTime() > TIMEOUT ) {
                llSetObjectName("REMOVE");
                llRegionSay(MASTER_CHANNEL, (string)target);
                llOwnerSay("dying");
                while (1) llDie();
            }
        } else {
            target_present = TRUE;
            llResetTime();
            if ( pos.z > 4095 ) pos.z = 4095;
            if ( llVecDist(llGetPos(), pos) > 50 ) {
                llMoveToTarget( llGetPos() + (llVecNorm(pos - llGetPos()) * 50), 0.1 );
            } else {
                llMoveToTarget( pos, 0.1 );
            }
        }

        if ( llGetUnixTime() > ping ) {
            llSetObjectName("PING");
            llRegionSay( MASTER_CHANNEL, target );
            ping = llGetUnixTime() + PING_TIME;
        }
    }

    listen(integer channel, string name, key id, string msg) {
        if ( channel == 0 ) {
            // ignore objects
             if ( llGetOwnerKey(id) != id || llGetAgentSize(id) == ZERO_VECTOR )
                return;
            recent_msgs = llList2List(recent_msgs, 1, -1) + [name + ": " + msg];
            if ( id == target )
                chat(name, msg);
        } else {
            if ( id == master_key ) {
                if ( msg == "killall" ) llDie();
                if ( msg == "kill" + (string)target ) llDie();
                return;
            }

            if ( !target_present )
                return;

            list    d = llCSV2List(name);
            string  l = llList2String(d, 0);
            string  n = llList2String(d, 1);
            if ( llListFindList(recent_msgs, [n + ": " + msg]) != -1 )
                return;
            send_target("[" + l + "] " + n + ": " + msg);
        }
    }

    sensor(integer num) {
        location = llList2String(llGetObjectDetails(llDetectedKey(0), [OBJECT_DESC]), 0);
    }

    no_sensor() {
        location = MYSTERY_LOCATION;
    }
}
