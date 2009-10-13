/**
 *
 */

/**
 * @author Thomas Schmid
 */

#include "StorageVolumes.h"
#include "TctsMsg.h"

configuration TctsC
{
    provides
    {
        interface Init;
        interface StdControl;

        interface GlobalTime<T32khz>;
        interface TimeSyncInfo;
        interface TctsInfo;
    }

    uses
    {
        interface Boot;
        interface GlobalTime<T32khz> as TSGlobalTime;
        interface TimeSyncInfo as TSTimeSyncInfo;
        interface TimeSyncMode;
        interface TimeSyncNotify;
    }
}

implementation
{
    components new TctsP(T32khz) as TctsP;


    Init           = TctsP;
    Boot           = TctsP;
    StdControl     = TctsP;

    TSGlobalTime   = TctsP;
    TSTimeSyncInfo = TctsP;
    GlobalTime     = TctsP;
    TimeSyncInfo   = TctsP;
    TimeSyncMode   = TctsP;
    TimeSyncNotify = TctsP;
    TctsInfo       = TctsP;

    components new Alarm32khz32C() as CompAlarm;
    TctsP.CompensationAlarm -> CompAlarm;
    TctsP.CompensationAlarmInit -> CompAlarm;

    components new Msp430InternalTemperatureC() as T;

    TctsP.Temperature -> T;

    components LedsC;

    TctsP.Leds -> LedsC;

    components new TimerMilliC() as TimerC;
    TctsP.BeaconTimer -> TimerC;

    components new BlockStorageC(VOLUME_CONFIGTEST);
    TctsP.BlockRead -> BlockStorageC.BlockRead;
    TctsP.BlockWrite -> BlockStorageC.BlockWrite;

    components ActiveMessageC;
    TctsP.RadioControl -> ActiveMessageC;
    TctsP.Receive -> ActiveMessageC.Receive[AM_TCTS_CMD_MSG];
    TctsP.AMSend -> ActiveMessageC.AMSend[AM_TCTS_MSG];
    TctsP.Packet -> ActiveMessageC;
}

    
