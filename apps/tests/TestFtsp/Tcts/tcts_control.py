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

# hub commands
GET_SKEWS        = 0x01
WRITE_CONFIG     = 0x02

# cmd responses
SKEW_RSP         = 0x81
WRITE_RSP        = 0x82
WRITE_FAILED_RSP = 0x83


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
                pass
            elif msg.get_cmd() == WRITE_RSP:
                self.scr.addstr(10, 0, "Write Done on %s"%(src))
                # write done
                pass
            elif msg.get_cmd() == WRITE_FAILED:
                self.scr.addstr(10, 0, "Write FAILED on %s"%(src))
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
            cmsg = TctsCmdMsg.TctsCmdMsg()
            cmsg.set_cmd(WRITE_CONFIG)
            self.mif.sendMsg(self.tos_source, 0x3, cmsg.get_amType(), 0,
                    cmsg)

        if c == ord('g'):
            # send write message
            cmsg = TctsCmdMsg.TctsCmdMsg()
            cmsg.set_cmd(GET_SKEWS)
            self.mif.sendMsg(self.tos_source, 0x3, cmsg.get_amType(), 0,
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
