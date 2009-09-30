/**
 * @author Thomas Schmid
 */

/**
 *
 */

#include "TimeSyncMsg.h"
#include "StorageVolumes.h"
#include "TctsMsg.h"
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

        interface ConfigStorage as Config;
        interface Mount;

        interface SplitControl as RadioControl;
        interface Receive;
        interface AMSend;
        interface Packet;
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
        CONFIG_ADDR = 0,
        CONFIG_VERSION = 1,

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

    typedef struct config_t {
        uint16_t version;
        float calTable[NUM_TEMP];
    } config_t;

    config_t conf;

    command error_t Init.init()
    {
        currentPeriod = DEFAULT_PERIOD;
        state = CALIBRATION;
        calibCounter = 0;
        conf.version = 0;
        return SUCCESS;
    }

    event void Boot.booted()
    {
        if (call Mount.mount() != SUCCESS) {
            // Handle failure
        }

    }

    event void Mount.mountDone(error_t error) {
        if (error == SUCCESS) {
            if(call Config.valid() == TRUE) {
                if (call Config.read(CONFIG_ADDR, &conf, sizeof(conf)) != SUCCESS) {
                    // Handle failure
                }
            }
            else {
                // Invalid volume. Commit to make valid
                //call Leds.led1On();
                if (call Config.commit() == SUCCESS) {
                    call Leds.led0On();
                }
                else {
                    // Handle failure
                }
            }
        } else {
            // Handle failure
        }

    }

    event void Config.readDone(storage_addr_t addr, void* buf, storage_len_t len, error_t err) __attribute__((noinline)) {
        if (err == SUCCESS) {
            memcpy(&conf, buf, len);
            if (conf.version == CONFIG_VERSION) {
                // everything is ok!
            }
            else {
                // version mismatch. Restore default.
                uint16_t i;
                conf.version = CONFIG_VERSION;

                for(i=0; i<NUM_TEMP; i++)
                    conf.calTable[i] = INVALID_TEMP; 
            }
            call Config.write(CONFIG_ADDR, &conf, sizeof(conf));
        }
        else {
            // Handle failure
        }

    }

    event void Config.writeDone(storage_addr_t addr, void*buf, storage_len_t len, error_t err) {
        // Verify addr and len

        if ( err == SUCCESS ) {
            if (call Config.commit() != SUCCESS) {
                // Handle failure
            }
        }
        else {
            // Handle failure
        }
    }

    event void Config.commitDone(error_t err) {
        if(conf.version == 0) {
            // we didn't read a configuration!
            // try to read it again
            if(call Config.valid() == TRUE) {
                if (call Config.read(CONFIG_ADDR, &conf, sizeof(conf)) != SUCCESS) {
                    // Handle failure
                }
            }
        } 
        else {
            call Leds.led0On();
            call Leds.led1On();
            call Leds.led2On();
            call RadioControl.start();
        }
    }
    event void RadioControl.startDone(error_t err) {
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
                    conf.calTable[i] = skew;

                    printf("CALIB ct: %u %ld\n", i, (int32_t)(skew*100000000));
                }
                printfflush();
                break;
            case COMPENSATION:
                printf("COMP temp: %u %u %ld\n", val, val/TEMP_BINS, (int32_t)((call TimeSyncInfo.getSkew())*100000000));
                if(conf.calTable[val/TEMP_BINS] == INVALID_TEMP)
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

    event message_t* Receive.receive(message_t* msgPtr, void* payload, uint8_t len)
    {
        tcts_cmd_msg_t* m = (tcts_cmd_msg_t*)call Packet.getPayload(msgPtr, sizeof(tcts_cmd_msg_t));

        switch(m->cmd)
        {
            default:
                call Leds.led0Toggle();
        }
        return msgPtr;
    }

    event void AMSend.sendDone(message_t* ptr, error_t success) {

    }

    event void RadioControl.stopDone(error_t err) {}
}
