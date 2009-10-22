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
        interface TimeSyncInfo as TSTimeSyncInfo;
        interface TimeSyncMode;
        interface TimeSyncNotify;
        interface Leds;

        interface Boot;
        interface Timer<TMilli> as BeaconTimer;

        interface Init as CompensationAlarmInit;
        interface Alarm<T32khz,uint32_t> as CompensationAlarm;

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
        interface TimeSyncInfo;
        interface TctsInfo;
    }
}

implementation
{

#define COMPINTERVAL 163840L        // update every 5 seconds

    enum {
        BLOCK_ADDR = 0,
        CONFIG_VERSION = 7,

        CALIBRATION = 1,
        COMPENSATION = 2,
        DEFAULT_PERIOD = 30,
        NUM_CALIB    = 3,              // how many calibration messages are needed?
        NUM_TEMP     = 2048,
        TEMP_BINS    = 0xFFFF/16384, 
    };

#define INVALID_TEMP 3.141


    enum {
        STATE_INIT,
        STATE_READ,
    };

    uint8_t state;
    uint8_t storageState;
    uint8_t calibCounter; // counts how many calibration messages we received
    uint16_t currentPeriod; // the current beacon interval in seconds
    bool locked;            // protects the msg buffer
    message_t msg;
    uint32_t lastAlarm;

    uint16_t tempIndex; // current position in reading the temperature
    norace uint16_t currentTemp;

    typedef struct config_t {
        uint16_t version;
        float calTable[NUM_TEMP];
    } config_t;

    config_t conf;

    // time sync globals
    float skew;
    uint32_t localAverage;
    int32_t offsetAverage;
    float offsetAverageF;

    command error_t Init.init()
    {
        currentPeriod = DEFAULT_PERIOD;
        state = CALIBRATION;
        storageState = STATE_INIT;
        calibCounter = 0;
        conf.version = 0;
        tempIndex = 0;
        locked = FALSE;
        skew = 0.0;
        localAverage = 0;
        offsetAverage = 0;
        return call CompensationAlarmInit.init();
    }

    event void Boot.booted()
    {
        if (call BlockRead.read(BLOCK_ADDR, &conf, sizeof(conf)) != SUCCESS) {
            // Handle failure
            call Leds.led2On();
        }
        atomic {
            lastAlarm = call CompensationAlarm.getNow();
            call CompensationAlarm.startAt(lastAlarm, COMPINTERVAL);
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
        tm->src = TOS_NODE_ID;

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
        atomic {
            localAverage = call TSTimeSyncInfo.getSyncPoint();
            offsetAverage = call TSTimeSyncInfo.getOffset();
            offsetAverageF = offsetAverage;
        }

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
        currentTemp = val;
        switch(state)
        {
            case CALIBRATION:
                if(calibCounter == NUM_CALIB)
                {
                    // we collected enough data points. Skew is now valid!
                    uint16_t i = val/TEMP_BINS;
                    atomic {
                        skew = call TSTimeSyncInfo.getSkew();
#ifndef NOCOMP
                        state = COMPENSATION;
#endif
                        conf.calTable[i] = skew;
                    }
                }
                break;
            case COMPENSATION:
                if(conf.calTable[val/TEMP_BINS] == INVALID_TEMP)
                {
                    // we don't know the current skew, go back to calibration!

                    atomic {
#ifdef DOCALIB
                            state = CALIBRATION;
#endif
                    }
                    calibCounter = 0;
                } 
                else {
                    // first, update our estimate of global time using old
                    // skew
                    atomic {
                        offsetAverageF = offsetAverageF + (skew + conf.calTable[val/TEMP_BINS]) / 2.0 * COMPINTERVAL;
                        offsetAverage = (int32_t)offsetAverageF;

                        localAverage += COMPINTERVAL;

                        // now, update the skew
                        skew = conf.calTable[val/TEMP_BINS];
                    }


                break;
                }
        }
    }

    task void getTemperature()
    {
        call Temperature.read();
    }

    async event void CompensationAlarm.fired()
    {
        // fires every time we have to do compensation
        //
        // setup the next trigger
        lastAlarm = call CompensationAlarm.getAlarm();
        call CompensationAlarm.startAt(lastAlarm, COMPINTERVAL);

        switch(state)
        {
            case CALIBRATION:
                // do nothing
                post getTemperature(); // do it for demo...
                break;
            case COMPENSATION:
                // get a temperature sample
                post getTemperature();
                break;
        }
    }

    async command uint32_t GlobalTime.getLocalTime()
    {
        return call TSGlobalTime.getLocalTime();

    }

    async command error_t GlobalTime.getGlobalTime(uint32_t *time)
    {
        switch(state)
        {
            case CALIBRATION:
                return call TSGlobalTime.getGlobalTime(time);
            case COMPENSATION:
                *time = call GlobalTime.getLocalTime();
                return call GlobalTime.local2Global(time);
        }
    }

    async command error_t GlobalTime.local2Global(uint32_t *time)
    {
        switch(state)
        {
            case CALIBRATION:
                return call TSGlobalTime.local2Global(time);
            case COMPENSATION:
                *time += offsetAverage + (int32_t)(skew * (int32_t)(*time - localAverage));
                return SUCCESS;
        }
    }

    async command error_t GlobalTime.global2Local(uint32_t *time)
    {
        switch(state)
        {
            case CALIBRATION:
                return call TSGlobalTime.global2Local(time);
            case COMPENSATION:
                {
                    uint32_t approxLocalTime = *time - offsetAverage;
                    *time = approxLocalTime - (int32_t)(skew * (int32_t)(approxLocalTime - localAverage));
                    return SUCCESS;
                }
        }
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
                {
                    uint16_t i;
                    uint8_t j;
                    tcts_msg_t* tm = (tcts_msg_t*)call Packet.getPayload(&msg, sizeof(tcts_msg_t));
                    tm->src = TOS_NODE_ID;

                    call Leds.led1On();

                    tm->cmd = SKEW_RSP;
                    // send the message
                    if (!locked) {
                        locked = TRUE;

                        // first, go to the first valid entry
                        for (i=tempIndex; i<tempIndex+NUM_TEMP; i++) {
                            if (conf.calTable[i%NUM_TEMP] != INVALID_TEMP) {
                                break;
                            }
                        }
                        for (j=0; j < 10; j++) {
                            tm->skews[j] = conf.calTable[(i+j)%NUM_TEMP];
                        }
                        tm->startIndex = i;
                        tempIndex = i+10;
                        tempIndex = tempIndex%NUM_TEMP;

                        call Leds.led0Toggle();
                        if(call AMSend.send(4000, &msg, sizeof(tcts_msg_t)) != SUCCESS)
                        {
                            locked = FALSE;
                        }
                    }
                    break;
                }
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

    async command float     TimeSyncInfo.getSkew() { return skew; }
    async command uint32_t  TimeSyncInfo.getOffset() { return offsetAverage; }
    async command uint32_t  TimeSyncInfo.getSyncPoint() { return localAverage; }
    async command uint16_t  TimeSyncInfo.getRootID() { return call TSTimeSyncInfo.getRootID(); }
    async command uint8_t   TimeSyncInfo.getSeqNum() { return call TSTimeSyncInfo.getSeqNum(); }
    async command uint8_t   TimeSyncInfo.getNumEntries() { return call TSTimeSyncInfo.getNumEntries(); }
    async command uint8_t   TimeSyncInfo.getHeartBeats() { return call TSTimeSyncInfo.getHeartBeats(); }

    async command uint16_t TctsInfo.getTemp() { return currentTemp; }
    async command uint8_t TctsInfo.getState() { return state; }

}
