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
    }

    uses
    {
        interface Boot;
        interface GlobalTime<T32khz> as TSGlobalTime;
        interface TimeSyncInfo;
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
    GlobalTime     = TctsP;
    TimeSyncInfo   = TctsP;
    TimeSyncMode   = TctsP;
    TimeSyncNotify = TctsP;

    components new Msp430InternalTemperatureC() as T;

    TctsP.Temperature -> T;

    components LedsC;

    TctsP.Leds -> LedsC;

    components new TimerMilliC() as TimerC;
    TctsP.BeaconTimer -> TimerC;

    components new ConfigStorageC(VOLUME_CONFIGTEST);
    TctsP.Config -> ConfigStorageC.ConfigStorage;
    TctsP.Mount  -> ConfigStorageC.Mount;

    components ActiveMessageC;
    TctsP.RadioControl -> ActiveMessageC;
    TctsP.Receive -> ActiveMessageC.Receive[AM_TCTS_CMD_MSG];
    TctsP.AMSend -> ActiveMessageC.AMSend[AM_TCTS_MSG];
    TctsP.Packet -> ActiveMessageC;
}

    
