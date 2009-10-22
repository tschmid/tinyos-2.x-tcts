#if you want to rebuild the TestTctsMsg.py, make sure to replace the get_skew function with the following prototype:
#    def get_skew(self):
#        return self.getFloatElement(self.offsetBits_skew(), 32, 0)


#BUILD_EXTRA_DEPS = TestTctsMsg.py
#BUILD_EXTRA_DEPS = TctsMsg.py
#BUILD_EXTRA_DEPS = TctsCmdMsg.py

TestTctsMsg.py: TestTcts.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=TestTctsMsg TestTcts.h test_tcts_msg -o $@

TctsMsg.py: $(TOSDIR)/lib/tcts/TctsMsg.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=TctsMsg $(TOSDIR)/lib/tcts/TctsMsg.h tcts_msg -o $@
TctsCmdMsg.py: $(TOSDIR)/lib/tcts/TctsMsg.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=TctsCmdMsg $(TOSDIR)/lib/tcts/TctsMsg.h tcts_cmd_msg -o $@

COMPONENT=TestTctsAppC

PFLAGS += -DTIMESYNC_RATE=100
#PFLAGS += -DTIMESYNC_DEBUG

CFLAGS += -DTOSH_DATA_LENGTH=90

PFLAGS += -I$(TOSDIR)/lib/ftsp -I$(TOSDIR)/lib/tcts -I$(TOSDIR)/../apps/RadioCountToLeds
PFLAGS += -I$(TOSDIR)/lib/printf

CFLAGS += -DDOCALIB  # uncomment to enable automatic calibration
#CFLAGS += -DNOCOMP   # uncomment to disable automatic compensation
#CFLAGS += -DNOREAD   # uncomment to disable the reading of the conf table from flash
CFLAGS += -DCONFIG_VERSION=8

include $(MAKERULES)
