README for TestIndirect
Author/Contact: tinyos-help@millennium.berkeley.edu

Description:

In this application one node takes the role of a PAN coordinator in a
beacon-enabled 802.15.4 PAN; it transmits periodic beacons and additionally in
every beacon interval it tries to transmit one DATA frame to a device using
indirect tranmission. A second node that takes the role of a device first scans
the pre-defined channel for beacons from the coordinator and once it finds a
beacon it tries to synchronize to and track all future beacons. Whenever the
coordinator has data to send (indicated in the beacon), the device extracts the
DATA frame from the coordinator.

The third LED (Telos: blue) is toggled whenever the coordinator has transmitted
a beacon, it is not used on the device. On the coordinator the second LED
(Telos: green) is toggled for every transmitted DATA frames. On a device the
second LED is toggled for every received DATA frame. The first LED (Telos: red)
is used for debugging, it denotes an error in the protocol stack and should
never be on.

Tools: NONE

Usage: 

1. Install the coordinator:

    $ cd coordinator; make <platform> install

2. Install one device

    $ cd device; make <platform> install

You can change some of the configuration parameters in app_profile.h

Known bugs/limitations:

- Many TinyOS 2 platforms do not have a clock that satisfies the
  precision/accuracy requirements of the IEEE 802.15.4 standard (e.g. 
  62.500 Hz, +-40 ppm in the 2.4 GHz band); in this case the MAC timing 
  is not standard compliant

$Id: README.txt,v 1.1 2009/05/18 16:21:55 janhauer Exp $

