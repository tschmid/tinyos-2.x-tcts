/**
 * @author Thomas Schmid
 */

/**
 *
 */

#include "TimeSyncMsg.h"
#include "printf.h"

generic module TctsP(typedef precision_tag)
{
    uses
    {
        interface GlobalTime<precision_tag> as TSGlobalTime;
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

        interface GlobalTime<precision_tag>;
    }
}

implementation
{

    enum {
        CALIBRATION = 1,
        COMPENSATION = 2,
        DEFAULT_PERIOD = 10,
        NUM_CALIB    = 3,              // how many calibration messages are needed?
        NUM_TEMP     = 2048,
        TEMP_BINS    = 0xFFFF/2048,
        INVALID_TEMP = 0xFFFF,
    };

    uint8_t state;
    uint8_t calibCounter; // counts how many calibration messages we received
    uint16_t currentPeriod; // the current beacon interval in seconds

    float calTable[NUM_TEMP];

    command error_t Init.init()
    {
        uint16_t i;

        for(i=0; i<NUM_TEMP; i++)
            calTable[i] = INVALID_TEMP;

        currentPeriod = DEFAULT_PERIOD;
        state = CALIBRATION;
        calibCounter = 0;
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
                calibCounter += 1;
                call Leds.led1Toggle();
                call Temperature.read();
                break;

            case COMPENSATION:
                call Leds.led2Toggle();
                call Temperature.read();
                break;
        }
    }

    event void Temperature.readDone(error_t result, uint16_t val)
    {
        switch(state)
        {
            case CALIBRATION:
                printf("CALIB temp: %u %u\n", val, val/TEMP_BINS);
                if(calibCounter == NUM_CALIB)
                {
                    // we collected enough data points. Skew is now valid!
                    uint16_t i = val/TEMP_BINS;
                    float skew = call TimeSyncInfo.getSkew();

                    state = COMPENSATION;
                    calTable[i] = skew;

                    printf("CALIB ct: %u %ld\n", i, (int32_t)(skew*100000000));
                }
                printfflush();
                break;
            case COMPENSATION:
                printf("COMP temp: %u %u %ld\n", val, val/TEMP_BINS, (int32_t)((call TimeSyncInfo.getSkew())*100000000));
                if(calTable[val/TEMP_BINS] == INVALID_TEMP)
                {
                    // we don't know the current skew, go back to calibration!
                    state = CALIBRATION;
                    calibCounter = 0;
                }
                printfflush();
                break;
        }
    }

    async command uint32_t GlobalTime.getLocalTime()
    {
        return call TSGlobalTime.getLocalTime();
    }

    async command error_t GlobalTime.getGlobalTime(uint32_t *time)
    {
        return call TSGlobalTime.getGlobalTime(time);
    }

    async command error_t GlobalTime.local2Global(uint32_t *time)
    {
        return call TSGlobalTime.local2Global(time);
    }

    async command error_t GlobalTime.global2Local(uint32_t *time)
    {
        return call TSGlobalTime.global2Local(time);
    }

    event void TimeSyncNotify.msg_sent()
    {
        call Leds.led0Toggle();
    }
}
