#if you want to rebuild the TestTctsMsg.py, make sure to replace the get_skew function with the following prototype:
#    def get_skew(self):
#        return self.getFloatElement(self.offsetBits_skew(), 32, 0)


#BUILD_EXTRA_DEPS = TestTctsMsg.py

TestTctsMsg.py: TestTcts.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=TestTctsMsg TestTcts.h test_tdts_msg -o $@

COMPONENT=TestTctsAppC

PFLAGS += -DTIMESYNC_RATE=3
#PFLAGS += -DTIMESYNC_DEBUG

CFLAGS += -DTOSH_DATA_LENGTH=50

PFLAGS += -I$(TOSDIR)/lib/ftsp -I$(TOSDIR)/lib/tcts -I$(TOSDIR)/../apps/RadioCountToLeds

include $(MAKERULES)
