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

        interface BlockRead;
        interface BlockWrite;

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
        BLOCK_ADDR = 0,
        CONFIG_VERSION = 5,

        CALIBRATION = 1,
        COMPENSATION = 2,
        DEFAULT_PERIOD = 10,
        NUM_CALIB    = 3,              // how many calibration messages are needed?
        NUM_TEMP     = 512,
        TEMP_BINS    = 0xFFFF/512,
        INVALID_TEMP = 0xFFFF,
    };


    enum {
        STATE_INIT,
        STATE_READ,
    };

    uint8_t state;
    uint8_t storageState;
    uint8_t calibCounter; // counts how many calibration messages we received
    uint16_t currentPeriod; // the current beacon interval in seconds
    bool locked;
    message_t msg;

    typedef struct config_t {
        uint16_t version;
        float calTable[NUM_TEMP];
    } config_t;

    config_t conf;

    command error_t Init.init()
    {
        currentPeriod = DEFAULT_PERIOD;
        state = CALIBRATION;
        storageState = STATE_INIT;
        calibCounter = 0;
        conf.version = 0;
        locked = FALSE;
        return SUCCESS;
    }

    event void Boot.booted()
    {
        if (call BlockRead.read(BLOCK_ADDR, &conf, sizeof(conf)) != SUCCESS) {
            // Handle failure
            call Leds.led2On();
        }
        call RadioControl.start();
    }

    event void BlockRead.readDone(storage_addr_t addr, void* buf, storage_len_t len, error_t err) {
        if (err == SUCCESS) {
            call Leds.led0On();
            memcpy(&conf, buf, len);
            if (conf.version == CONFIG_VERSION) {
                // everything is ok!
                if(storageState == STATE_INIT){
                    storageState = STATE_READ;
                    call Leds.led0On();
                    call Leds.led1On();
                    call Leds.led2On();
                    call StdControl.start();
                    return;
                }
            }
            else {
                // version mismatch. Restore default.
                uint16_t i;
                conf.version = CONFIG_VERSION;

                for(i=0; i<NUM_TEMP; i++)
                    conf.calTable[i] = INVALID_TEMP; 
                
                if(call BlockWrite.erase() != SUCCESS)
                {
                    // handle failure
                    call Leds.led2On();
                }
            }
        }
        else {
            // Handle failure
            call Leds.led2On();
        }

    }

    event void BlockWrite.eraseDone(error_t result)
    {
        if(result == SUCCESS)
        {
            if(call BlockWrite.write(BLOCK_ADDR, &conf, sizeof(conf)) != SUCCESS)
            {
                call Leds.led2On();
            }
        }
        else {
            call Leds.led2On();
        }
    }

    event void BlockWrite.writeDone(storage_addr_t addr, void* buf, storage_len_t len, error_t err) {
        tcts_msg_t* tm = (tcts_msg_t*)call Packet.getPayload(&msg, sizeof(tcts_msg_t));


        call Leds.led1On();

        if ( err == SUCCESS ) {
            call BlockWrite.sync();
            if(storageState == STATE_INIT){
                storageState = STATE_READ;
                call Leds.led0On();
                call Leds.led1On();
                call Leds.led2On();
                call StdControl.start();
            }
            tm->cmd = WRITE_RSP;
        }
        else {
            // Handle failure
            call Leds.led2On();
            tm->cmd = WRITE_FAILED_RSP;
        }
        // send the write done message
        if (!locked) {
            tm->cmd = WRITE_RSP;

            locked = TRUE;
            call Leds.led0Toggle();
            if(call AMSend.send(4000, &msg, sizeof(tcts_msg_t)) != SUCCESS)
            {
                locked = FALSE;
            }
        }
        else {
            call Leds.led2Toggle();
        }
    }

    event void RadioControl.startDone(error_t err) {
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

        call Leds.led0Off();
        call Leds.led1Off();
        call Leds.led2Off();
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
        call Leds.led0Toggle();

        switch(m->cmd)
        {
            case GET_SKEWS:
                break;
            case WRITE_CONFIG:
                call BlockWrite.erase();
                break;
            default:
                call Leds.led0Toggle();
        }
        return msgPtr;
    }

    event void AMSend.sendDone(message_t* ptr, error_t success) {
        if(success == SUCCESS)
        {
            call Leds.led0Off();
            call Leds.led1Off();
            call Leds.led2Off();
        }

        locked = FALSE;
    }

    event void RadioControl.stopDone(error_t err) {}
    event void BlockWrite.syncDone(error_t result) {
    }
    event void BlockRead.computeCrcDone(storage_addr_t addr, storage_len_t len, uint16_t crc, error_t result) {}
}
