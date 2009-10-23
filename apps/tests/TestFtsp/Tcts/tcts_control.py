#!/usr/bin/env "python -W ignore::DeprecationWarning"

"""
parameters:
    - the first parameter to this application is a MOTECOM string.
"""

import sys
import time
import curses
import signal

#tos stuff
import TctsCmdMsg
import TctsMsg
from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial

INVALID_TEMP = 3.141
NUM_TEMP = 2048

# hub commands
GET_SKEWS        = 0x01
WRITE_CONFIG     = 0x02
SET_SKEWS        = 0x03

# cmd responses
SKEW_RSP         = 0x81
WRITE_RSP        = 0x82
WRITE_FAILED_RSP = 0x83

c1 = 2.41134e-09
c2 = -4.61874e-06
c3 = 0.0021887

b1 = 2.48805e-09
b2 = -4.89248e-06
b3 = 0.00237733

a1 = 2.49163e-09
a2 = -4.7777e-06
a3 = 0.00225503

class Tcts:

    SENSOR_SCREEN_OFFSET_Y = 5
    CURRENT_TIME_OFFSET_Y = 1
    STATUS_SCREEN_OFFSET_Y = 32
    LEGEND_SCREEN_OFFSET_Y = 34

    def __init__(self, motestring, repeat = True, debug=True, screen=None):
        self.repeat = repeat
        self.binding = False
        self.DEBUG = debug
        self.nodes = {}

        self.state = GET_SKEWS

        self.history = []
        self.maxSizeHistory = 50

        ### start tos mote interface
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(self, TctsCmdMsg.TctsCmdMsg)
        self.mif.addListener(self, TctsMsg.TctsMsg)

        if(screen):
            # we are using curses
            self.scr = screen
            curses.curs_set(0) #disable showing the curser
            curses.start_color()
            curses.init_pair(1, curses.COLOR_RED, curses.COLOR_BLACK)
        else:
            self.scr = None


    def receive(self, src, msg):
        """ This is the registered listener function for TinyOS messages.
        """
        if msg.get_amType() == TctsMsg.AM_TYPE:
            if msg.get_cmd() == SKEW_RSP:
                self.scr.addstr(10, 0, "Received Skews from %d on %s"%(msg.get_src(), time.ctime()))
                for i in range(0,10):
                    self.scr.addstr(11+i, 0, 50*" ")
                i = 0
                for s in msg.get_skews():
                    if abs(s - INVALID_TEMP) > 1e-6:
                        self.scr.addstr(11+i, 0, "Index %d skew %e"%((msg.get_startIndex() + i)%NUM_TEMP, s))
                    i += 1
            elif msg.get_cmd() == WRITE_RSP:
                self.scr.addstr(10, 0, "Write Done on %d at %s"%(msg.get_src(), time.ctime()))
                # write done
                pass
            elif msg.get_cmd() == WRITE_FAILED_RSP:
                self.scr.addstr(10, 0, "Write FAILED on %d"%(msg.get_src()))
        else:
            print "Unknown message type:", msg.get_amType(), msg

    def refreshScreen(self,):
        self.scr.addstr(self.CURRENT_TIME_OFFSET_Y, 0,
                5*" " + "Current Time: %s"%(time.ctime()))
        self.scr.refresh()


    def process_input(self, c):
        if c == -1:
            # nothing here
            return
        if c == ord('q'):
            # quit application
            self.close()
            self.repeat=False
            return
        if c == ord('w'):
            # send write message
            self.state=WRITE_CONFIG
            self.scr.addstr(8, 0, "Write Mode")

        if c == ord('g'):
            # send write message
            self.state=GET_SKEWS
            self.scr.addstr(8, 0, "Get Mode")

        if c == ord('s'):
            # send a skew table to a node
            self.state=SET_SKEWS
            self.T = int(sys.argv[2])
            self.scr.addstr(8, 0, "Set Skews start at index=%d"%(self.T))

        if c - ord('0') in range(1, 10):
            if self.state == SET_SKEWS:
                self.scr.addstr(9, 0, "BUSY")

                i = 0
                smsg = TctsMsg.TctsMsg()
                smsg.set_cmd(self.state)
                smsg.set_src(c-ord('0'))
                smsg.set_startIndex(self.T)
                sk = []
                for T in range(self.T, self.T+10):
                    Tf = float(T)
                    if c-ord('0') == 6:
                        sk.append(a1*Tf*Tf+a2*Tf+a3)
                    elif c-ord('0') == 7:
                        sk.append(b1*Tf*Tf+b2*Tf+b3)
                    elif c-ord('0') == 8:
                        sk.append(c1*Tf*Tf+c2*Tf+c3)
                    else:
                        sk.append(INVALID_TEMP)

                smsg.set_skews(sk)
                self.mif.sendMsg(self.tos_source, c-ord('0'),
                        smsg.get_amType(), 0, smsg)
                self.scr.addstr(9, 0, "sent index=%d"%(self.T,))
                f = file('msg.log', 'a+')
                f.write(str(smsg) + "\n")
                f.close()
                self.T += 10
                if self.T > 2000:
                    self.T = 200
            else:
                cmsg = TctsCmdMsg.TctsCmdMsg()
                cmsg.set_cmd(self.state)
                self.mif.sendMsg(self.tos_source, c-ord('0'), cmsg.get_amType(), 0,
                        cmsg)

    def close(self):
        # close up everything
        pass

    def main_loop(self):
        counter = 0
        # wait for everything to start up
        time.sleep(1)
        # set a timeout for the character input (in 1/10s, max 255)
        curses.halfdelay(10)
        while self.repeat:
            ## Do input processing
            c = self.scr.getch()

            self.process_input(c)

            self.refreshScreen()

def main(scr):

    if '-h' in sys.argv:
        print "Usage:", sys.argv[0], "serial@/dev/ttyUSB0:telosb"
        sys.exit()

    cf = Tcts(sys.argv[1], screen=scr)
    cf.main_loop()  # don't expect this to return...


if __name__ == "__main__":
    try:
        import curses.wrapper
        curses.wrapper(main)
    except KeyboardInterrupt:
        pass
