integer IM_CHANNEL      = -12610699; // channel to request IMs on
integer NUM_SLAVES      = 10;
integer PING            = 10;
integer cur_slave       = 0;
integer our_channel     = 0;
key     master_id       = NULL_KEY;

default {
    state_entry() {
        if ( llGetAttached() != 0 ) {
            llOwnerSay("durr durr");
            state tard;
        }
        integer channel = 0 - (integer)llFrand(1<<31);
        llListen( channel, "", NULL_KEY, "" );
        llSetObjectName("register");
        llRegionSay( IM_CHANNEL, (string)channel );
    }

    attach(key id) {
        if ( id != NULL_KEY ) {
            llOwnerSay("durr durr");
            state tard;
        }
    }

    on_rez(integer param) {
        llResetScript();
    }

    listen(integer channel, string name, key id, string msg) {
        if ( msg == "full" ) {
            llOwnerSay("no more IM slaves needed");
            while (1) llDie();
        }
        master_id   = id;

        list d = llParseString2List( msg, ["|"], [] );
        our_channel = (integer)llList2String(d,0);
        vector pos = (vector) llList2String(d, 1);
        while (llVecDist(llGetPos(), pos) > 0.01)
            llSetPos(pos);
        state active;
    }
}

state tard {
    on_rez(integer param) {
        llResetScript();
    }
}

state active {
    state_entry() {
        llListen(our_channel, "", master_id, "" );
        llSetTimerEvent(PING);
        llOwnerSay("active");
    }

    on_rez(integer param) {
        llResetScript();
    }

    timer() {
        llSetObjectName("ping");
        llRegionSay(IM_CHANNEL, (string)our_channel);
    }

    listen(integer channel, string name, key id, string msg) {
        if ( name == "reset" && msg == "reset" ) llResetScript();
        if ( ++cur_slave >= NUM_SLAVES ) cur_slave = 0;
        integer i = llSubStringIndex(msg, ":");
        string fname = llDeleteSubString(msg, i, -1 );
        msg  = llDeleteSubString(msg, 0, i+1 );
        llSetObjectName(fname);
        llMessageLinked( LINK_SET, cur_slave, msg, (key)name );
    }

}
