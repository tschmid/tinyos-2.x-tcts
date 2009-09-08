#if you want to rebuild the TestTdtsMsg.py, make sure to replace the get_skew function with the following prototype:
#    def get_skew(self):
#        return self.getFloatElement(self.offsetBits_skew(), 32, 0)


#BUILD_EXTRA_DEPS = TestTdtsMsg.py

TestTdtsMsg.py: TestTdts.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=TestTdtsMsg TestTdts.h test_tdts_msg -o $@

COMPONENT=TestTdtsAppC

PFLAGS += -DTIMESYNC_RATE=3
#PFLAGS += -DTIMESYNC_DEBUG

CFLAGS += -DTOSH_DATA_LENGTH=50

PFLAGS += -I$(TOSDIR)/lib/ftsp -I$(TOSDIR)/../apps/RadioCountToLeds

include $(MAKERULES)
