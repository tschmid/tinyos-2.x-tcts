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

        print "\n#time src_addr ftsp_seq local_rx_timestamp global_rx_timestamp \
skew table_entries rootid"

    def receive(self, src, msg):
        if msg.get_amType() == TestTctsMsg.AM_TYPE:
            m = TestTctsMsg.TestTctsMsg(msg.dataGet())
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
                            ps = "%3d %3d %10d %10d %e %1d %3d %10s"%(k, 0, 0,
                                    0, 0, 0, 0, "None")
                            bad = True
                        elif self.d[k].get_is_synced() == 1:
                            # node is not synced
                            ps = "%3d %3d %10d %10d %e %1d %3d %10s"%(k,
                                    self.d[k].get_ftsp_seq(),
                                    -1,
                                    -1,
                                    self.d[k].get_skew(),
                                    self.d[k].get_ftsp_table_entries(),
                                    self.d[k].get_ftsp_root_addr(),
                                    "None")
                            bad = True
                        else:
                            ps = "%3d %3d %10d %10d %e %1d %3d "%(k,
                                    self.d[k].get_ftsp_seq(),
                                    self.d[k].get_local_rx_timestamp(),
                                    self.d[k].get_global_rx_timestamp(),
                                    self.d[k].get_skew(),
                                    self.d[k].get_ftsp_table_entries(),
                                    self.d[k].get_ftsp_root_addr(),
                                    )
                            if (self.d[k].get_ftsp_root_addr() == ROOTID) and (ROOTID in self.d.keys()):
                                ps += " %10d"%(self.d[self.d[k].get_ftsp_root_addr()].get_global_rx_timestamp()
                                        - self.d[k].get_global_rx_timestamp(),)
                            else:
                                ps += " %10s"%("None",)
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

