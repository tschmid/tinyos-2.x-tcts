/**
 * @author Thomas Schmid
 */

/**
 *
 */

#include "TimeSyncMsg.h"

generic module TctsP(typedef precision_tag)
{
    uses
    {
        interface GlobalTime<precision_tag>;
        interface TimeSyncInfo;
        interface TimeSyncMode;
        interface TimeSyncNotify;
        interface Leds;

        interface Boot;
        interface Timer<TMilli> as BeaconTimer;

        interface Read<uint16_t> as Temperature;
    }
    provides
    {
        interface Init;
        interface StdControl;
    }
}

implementation
{

    enum {
        CALIBRATION = 1,
        COMPENSATION = 2,
        DEFAULT_PERIOD = 10,
        NUM_TEMP     = 512,
        INVALID_TEMP = 0xFFFF,
    };

    uint8_t state;
    uint16_t currentPeriod; // the current beacon interval in seconds

    float calTable[NUM_TEMP];

    command error_t Init.init()
    {
        uint16_t i;

        for(i=0; i<NUM_TEMP; i++)
            calTable[i] = INVALID_TEMP;

        currentPeriod = DEFAULT_PERIOD;
        state = CALIBRATION;
        return SUCCESS;
    }

    event void Boot.booted()
    {
        call StdControl.start();
    }

    command error_t StdControl.start()
    {
        // take over controle of the resynchronization messages
        call TimeSyncMode.setMode(TS_USER_MODE);
        if(TOS_NODE_ID == 1)
        {
            // for now, only the root node sends out beacons!
            call BeaconTimer.startPeriodic(currentPeriod*1024);
        }

        return SUCCESS;
    }

    command error_t StdControl.stop()
    {
        return SUCCESS;
    }

    event void BeaconTimer.fired()
    {
        call TimeSyncMode.send();
    }

    event void TimeSyncNotify.msg_received()
    {
        switch(state)
        {
            case CALIBRATION:
                call Leds.led1Toggle();
                call Temperature.read();
                break;

            case COMPENSATION:
                call Leds.led2Toggle();
                break;
        }
    }

    event void Temperature.readDone(error_t result, uint16_t val)
    {
        switch(state)
        {
            case CALIBRATION:
                if(call TimeSyncInfo.getNumEntries() == 3)
                {
                    // we collected enough data points. Skew is now valid!
                    state = COMPENSATION;
                    calTable[val/NUM_TEMP] = call TimeSyncInfo.getSkew();
                }
                break;
            case COMPENSATION:
                if(calTable[val/NUM_TEMP] == INVALID_TEMP)
                {
                    // we don't know the current skew, go back to calibration!
                    state = CALIBRATION;
                }
                break;
        }
    }

    event void TimeSyncNotify.msg_sent()
    {
        call Leds.led0Toggle();
    }
}
