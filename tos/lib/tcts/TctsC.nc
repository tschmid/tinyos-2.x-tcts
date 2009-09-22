/**
 * @author Thomas Schmid
 */

configuration TctsC
{
    provides
    {
        interface Init;
        interface StdControl;
    }

    uses
    {
        interface Boot;
        interface GlobalTime<T32khz>;
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
}

    
