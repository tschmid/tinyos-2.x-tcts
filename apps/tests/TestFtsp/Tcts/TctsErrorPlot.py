import sys
import os
import time
import struct

import wx
import wx.lib.plot as plot
from threading import Lock, Thread

#tos stuff
import TestTctsMsg
from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial

ROOTID = 1
TEMPBINS = 0xFFFF/16384

EVT_RESULT_ID = wx.NewEventType()
ERRORPLOT = 1
TEMPPLOT = 2
SKEWPLOT = 3

COLORS = {
        1 : 'red',
        6 : 'blue',
        7 : 'green',
        8 : 'black',
        9 : 'orange'
        }

YMARGIN = {
        ERRORPLOT: 1/32.768,
        TEMPPLOT : 1,
        SKEWPLOT : 1,
        }

class ResultEvent(wx.PyEvent):
    """Simple event to carry arbitrary result data."""
    def __init__(self, data):
        """Init Result Event."""
        wx.PyEvent.__init__(self)
        self.SetEventType(EVT_RESULT_ID)
        self.data = data


class TctsDataLogger(wx.Frame):
    def __init__(self, parent, id, title, motestring):

        wx.Frame.__init__(self, parent, id, title, size=(510, 340))
        self.panel = wx.Panel(self)
        self.Center()
        # Initialize a Box to hold all the graph plots
        self.box = wx.BoxSizer(wx.VERTICAL)
        # Initialize dictionary of graph plots along with corresponding sensor id
        # {sensor id 0 : plot 0, ...}
        self.plotter = {}
        # Initialize dictionary of data along with corresponding sensor id
        # {sensor id 0 : [(x1,y1), (x2,y2), ...], ...}
        self.data = {}
        self.odata = {}
        # Initialize dictionary of timestamps of first data buffer
        # for each sensor
        # {sensor id 0: timestamp, ...}
        self.init_timestamp = {}
        # Configuration variables
        # Header size of sensor data structure in new API
        self.SENSOR_DATA_HDR_SIZE = 8
        # Window size for displaying current data
        self.WINDOW_SIZE = 1024
        # Sample rate in Hz
        self.SAMPLE_RATE = 250
        # Clock frequency of clock utlized for timestamps
        self.TIME_CLOCK_SOURCE = 32768
        # Set the range for y-axis as (lower bound, upper bound)
        self.Y_AXIS_RANGE = (0, 2**32)
        # Internal variables
        self._x_lower = 0
        self._x_upper = 15
        self._rcvLock = Lock()
        # Set event handler for posting data
        self.Connect(-1, -1, EVT_RESULT_ID, self._PlotGraph)


        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(self, TestTctsMsg.TestTctsMsg)

        self.starttime = time.time()

        if len(sys.argv) == 3:
            self.filteraddr = int(sys.argv[2])
        else:
            self.filteraddr = -1
        self.lastseq = -1
        self.seq = -1
        self.d = {}
        self.plot = {}
        self.heardNodes = []
        self.entryStrLength = 0
        self._y_lower = {}
        self._y_upper = {}

        ## mild difference between wxPython26 and wxPython28
        #if wx.VERSION[1] < 7:
        #    self.plotter = plot.PlotCanvas(self.panel1, size=(1000, 750))
        #else:
        #    self.plotter = plot.PlotCanvas(self.panel1)
        #    self.plotter.SetInitialSize(size=(1000, 750))

    def CreateGraphs(self, sensorid):
        """Add all graphs for displaying sensor data.
        sensorid: list of sensor id's corresponding to each plot"""
        for i in range(len(sensorid)):
            # Add a graph plot to list
            self.plotter[sensorid[i]] = plot.PlotCanvas(self.panel)
            self.plotter[sensorid[i]].SetEnableLegend(True)
            #self.plotter[sensorid[i]].SetEnableGrid(True)
            #self.plotter.append((sensorid[i], plot.PlotCanvas(self.panel)))
            # Add the above graph plot to the Box
            self.box.Add(self.plotter[sensorid[i]], 1, wx.EXPAND)
        # Add the Box to the panel
        self.panel.SetSizer(self.box)

    def SetWindowSize(self, size):
        """Set window size of current display"""
        self.WINDOW_SIZE = size

    def SetSampleRate(self, rate):
        """Set sample rate of sensor data"""
        self.SAMPLE_RATE = rate

    def SetTimeClockSource(self, source):
        """Set the frequency of clock used for timestamps"""
        self.TIME_CLOCK_SOURCE = source

    def SetYAxisRange(self, lower, upper):
        """Set the range of Y-axis for display"""
        self.Y_AXIS_RANGE = (lower, upper)

    def my_min(self, x,y):
        if x[1] <= y[1]:
            return x
        else:
            return y

    def my_max(self, x,y):
        if x[1] >= y[1]:
            return x
        else:
            return y



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
                    self._rcvLock.acquire()
                    plots = {ERRORPLOT: {}, TEMPPLOT: {}, SKEWPLOT: {}}
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
                                error = self.d[self.d[k].get_ftsp_root_addr()].get_global_rx_timestamp() - self.d[k].get_global_rx_timestamp()
                                if k not in self.plot.keys():
                                    self.plot[k] = {ERRORPLOT : [], TEMPPLOT :
                                            [], SKEWPLOT : []}
                                self.plot[k][ERRORPLOT].append((time.time()-self.starttime,
                                    error/32768.0*1000))
                                self.plot[k][TEMPPLOT].append((time.time()-self.starttime,
                                    self.d[k].get_tcts_temp()))
                                self.plot[k][SKEWPLOT].append((time.time()-self.starttime,
                                    self.d[k].get_skew()*1e6))

                                for j in (ERRORPLOT, TEMPPLOT, SKEWPLOT):
                                        # clip data to adjust to the window size
                                        self.plot[k][j][0:max(-self.WINDOW_SIZE,
                                            -len(self.plot[k][j]))] = []

                                        # calculate new min max
                                        ymax = reduce(self.my_max, self.plot[k][j])
                                        ymin = reduce(self.my_min, self.plot[k][j])
                                        if j not in self._y_lower.keys():
                                            self._y_lower[j] = ymin[1]-YMARGIN[j]
                                            self._y_upper[j] = ymax[1]+YMARGIN[j]
                                        else:
                                            self._y_lower[j] = min(self._y_lower[j],
                                                ymin[1]-YMARGIN[j])
                                            self._y_upper[j] = max(self._y_upper[j],
                                                ymax[1]+YMARGIN[j])
                                        #plots[j][k] = self.plot[k][j]

                                # Update the lower and upper bounds for x-axis
                                self._x_lower = self.plot[k][ERRORPLOT][0][0]
                                self._x_upper = self.plot[k][ERRORPLOT][-1][0]
                                # post data to the plotting function


                                ps = "%3d %1d %3d %5d %10d"%(k,
                                        self.d[k].get_tcts_state(),
                                        self.d[k].get_ftsp_seq(),
                                        self.d[k].get_tcts_temp()/TEMPBINS,
                                        error,)
                            else:
                                ps = "%3d   %3d       %10s"%(k, self.d[k].get_ftsp_seq(), "NoRoot",)
                                bad = True
                        # add all the data to the graphs
                        if k != ROOTID:
                            for j in (ERRORPLOT, TEMPPLOT, SKEWPLOT):
                                if k in self.plot.keys():
                                    plots[j][k] = self.plot[k][j]

                    event = ResultEvent([plots,])
                    wx.PostEvent(self, event)
                    self._rcvLock.release()

                    #print self.plot.keys()

                self.d = {}
                self.d[addr] = m
                self.lastseq = m.get_counter()

            #if filteraddr < 0 or s[0] == filteraddr:

            #   print "%d %d %d %d %d %e %d %d %d %d %d %d"%(s)
            #   sys.stdout.flush()

            #print "*"*100

    def _PlotGraph(self, event):
        """Plot the graph for corresponding sensor data"""
        self._rcvLock.acquire()
        for j in event.data[0].keys():
            data = event.data[0][j]
            #print data
            line = []
            for k in data.keys():
                if k in COLORS.keys():
                    c = COLORS[k]
                else:
                    c = 'black'
                line.append(plot.PolyLine(data[k], colour=c, width=1,
                    legend="Node %d"%(k,)))
                # To draw markers: default colour = black, size = 2
                # shapes = 'circle', 'cross', 'square', 'dot', 'plus'
                #marker = plot.PolyMarker(event.data[1], marker='triangle')

            # set up text, axis and draw
            if j == ERRORPLOT:
                t = "Synchronization Error"
                xa = "Time [s]"
                ya = "Error [ms]"
            elif j == TEMPPLOT:
                t = "Temperature Index"
                xa = "Time [s]"
                ya = "Index"
            elif j == SKEWPLOT:
                t = "Frequency Error"
                xa = "Time [s]"
                ya = "Frequency Error [ppm]"
            gc = plot.PlotGraphics(line, t, xa, ya)
            # Draw graphs for each plot
            self.plotter[j].Draw(gc, xAxis=(self._x_lower,
                self._x_upper), yAxis=(float(self._y_lower[j]),
                    float(self._y_upper[j])))
        self._rcvLock.release()

    def __del__(self):
        self._Close()

    def _Close(self):
        """Cleanup before exit."""
        pass


def main():

    if '-h' in sys.argv:
        print "Usage:", sys.argv[0], "sf@localhost:9002"
        sys.exit()

    app = wx.App()
    f = TctsDataLogger(None, -1, "Data", sys.argv[1])
    sensorids = [ERRORPLOT, TEMPPLOT, SKEWPLOT]
    f.CreateGraphs(sensorids)
    f.SetWindowSize(256)
    f.SetSampleRate(1)
    f.SetYAxisRange(-20, 20)
    f.Show(True)
    app.MainLoop()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass

