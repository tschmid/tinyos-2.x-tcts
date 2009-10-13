import sys
import os
import time
import struct

#tos stuff
import TestTctsMsg
from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial

ROOTID = 1
TEMPBINS = 0xFFFF/16384

class TctsDataLogger:
    def __init__(self, motestring):
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(self, TestTctsMsg.TestTctsMsg)

        if len(sys.argv) == 3:
            self.filteraddr = int(sys.argv[2])
        else:
            self.filteraddr = -1
        self.lastseq = -1
        self.seq = -1
        self.d = {}
        self.heardNodes = []
        self.entryStrLength = 0

        print "\n#time src_addr state seq temp syncerr | src_addr state seq temp syncerr | ... | line valid"

    def receive(self, src, msg):
        if msg.get_amType() == TestTctsMsg.AM_TYPE:
            m = TestTctsMsg.TestTctsMsg(msg.dataGet()) # not sure why this
            addr = m.get_src_addr()
            if m.get_counter() == self.lastseq:
                # store the data
                self.d[addr] = m
                if addr not in self.heardNodes:
                    self.heardNodes.append(addr)
                    self.heardNodes.sort()
            else:
                # print the data and reset
                if len(self.d.keys()) > 0:
                    ks = self.d.keys()
                    ks.sort()
                    sys.stdout.write("%.2f\t"%(time.time()))
                    bad = False
                    for k in self.heardNodes:
                        if self.filteraddr != -1:
                            if k != self.filteraddr:
                                continue
                        if k not in self.d.keys():
                            ps = "%3d             %10s"%(k, "N/A")
                            bad = True
                        elif self.d[k].get_is_synced() == 1:
                            # node is not synced
                            ps = "%3d %1d %3d %5d %10s"%(k,
                                    self.d[k].get_tcts_state(),
                                    self.d[k].get_ftsp_seq(),
                                    self.d[k].get_tcts_temp()/TEMPBINS, "NoSync")
                            bad = True
                        else:
                            if (self.d[k].get_ftsp_root_addr() == ROOTID) and (ROOTID in self.d.keys()):
                                ps = "%3d %1d %3d %5d %10d"%(k,
                                        self.d[k].get_tcts_state(),
                                        self.d[k].get_ftsp_seq(),
                                        self.d[k].get_tcts_temp()/TEMPBINS,
                                        self.d[self.d[k].get_ftsp_root_addr()].get_global_rx_timestamp()
                                        - self.d[k].get_global_rx_timestamp(),)
                            else:
                                ps = "%3d   %3d       %10s"%(k, self.d[k].get_ftsp_seq(), "NoRoot",)
                                bad = True

                        self.entryStrLength = max(len(ps), self.entryStrLength)
                        leftOver = " "*(self.entryStrLength - len(ps))
                        sys.stdout.write(ps + leftOver)
                        sys.stdout.write(" | ")
                    sys.stdout.write("%d\n"%(bad,))
                    sys.stdout.flush()
                self.d = {}
                self.d[addr] = m
                self.lastseq = m.get_counter()

            #if filteraddr < 0 or s[0] == filteraddr:

            #   print "%d %d %d %d %d %e %d %d %d %d %d %d"%(s)
            #   sys.stdout.flush()

            #print "*"*100

    def main_loop(self):
        while 1:
            time.sleep(1)


def main():

    if '-h' in sys.argv:
        print "Usage:", sys.argv[0], "sf@localhost:9002"
        sys.exit()

    fdl = TctsDataLogger(sys.argv[1])
    fdl.main_loop()  # don't expect this to return...


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass

