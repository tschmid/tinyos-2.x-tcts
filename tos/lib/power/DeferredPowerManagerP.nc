/*
 * "Copyright (c) 2005 Washington University in St. Louis.
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 *
 * IN NO EVENT SHALL WASHINGTON UNIVERSITY IN ST. LOUIS BE LIABLE TO ANY PARTY 
 * FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING 
 * OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF WASHINGTON 
 * UNIVERSITY IN ST. LOUIS HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * WASHINGTON UNIVERSITY IN ST. LOUIS SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND WASHINGTON UNIVERSITY IN ST. LOUIS HAS NO 
 * OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
 * MODIFICATIONS."
 *
 */
 
/*
 * - Revision -------------------------------------------------------------
 * $Revision: 1.6 $
 * $Date: 2009/03/02 21:05:10 $ 
 * ======================================================================== 
 */
 
/**
 * Please refer to TEP 115 for more information about this component and its
 * intended use.<br><br>
 *
 * This is the internal implementation of the deffered power management
 * policy for managing the power states of non-virtualized devices.
 * Non-virtualized devices are shared using a parameterized Resource
 * interface, and are powered down according to some policy whenever there
 * are no more pending requests to that Resource.  The policy implemented
 * by this component is to delay the power down of a device by some contant
 * factor.  Such a policy is useful whenever a device has a long wake-up
 * latency.  The cost of waiting for the device to power up can be
 * avoided if the device is requested again before some predetermined
 * amount of time.
 *
 * @param <b>delay</b> -- The amount of time the power manager should wait
 *                        before shutting down the device once it is free.
 * 
 * @author Kevin Klues (klueska@cs.wustl.edu)
 */
 
generic module DeferredPowerManagerP(uint32_t delay) {
  uses {
    interface StdControl;
    interface SplitControl;

    interface PowerDownCleanup;
    interface ResourceDefaultOwner;
    interface ArbiterInfo;
    interface Timer<TMilli> as TimerMilli;
  }
}
implementation {

  norace bool stopping = FALSE;
  norace bool requested  = FALSE;
  norace bool stopTimer = FALSE;

  task void startTask() {
    call TimerMilli.stop();
    stopTimer = FALSE;
    call StdControl.start();
    if (call SplitControl.start()==EALREADY)
      call ResourceDefaultOwner.release();
  }

  task void timerTask() { 
    call TimerMilli.startOneShot(delay); 
  }

  async event void ResourceDefaultOwner.requested() {
    if(stopping == FALSE) {
      stopTimer = TRUE;
      post startTask();
    }
    else requested = TRUE;
  }

  async event void ResourceDefaultOwner.immediateRequested() {
  }

  default command error_t StdControl.start() {
    return SUCCESS;
  }
  default command error_t SplitControl.start() {
    signal SplitControl.startDone(SUCCESS);
    return SUCCESS;
  }

  event void SplitControl.startDone(error_t error) {
    call ResourceDefaultOwner.release();
  }

  async event void ResourceDefaultOwner.granted() {
    post timerTask();
  }

  event void TimerMilli.fired() {
    atomic {
      if(stopTimer == FALSE) {
        stopping = TRUE;
        call PowerDownCleanup.cleanup();
        call StdControl.stop();
        if (call SplitControl.stop()==EALREADY)
          signal SplitControl.stopDone(SUCCESS);
      }
    }
  }

  event void SplitControl.stopDone(error_t error) {
    if(requested == TRUE) {
      call StdControl.start();
      call SplitControl.start();
    }
    atomic {
      requested = FALSE;
      stopping = FALSE;
    }
  }

  default command error_t StdControl.stop() {
    return SUCCESS;
  }
  default command error_t SplitControl.stop() {
    signal SplitControl.stopDone(SUCCESS);
    return SUCCESS;
  }

  default async command void PowerDownCleanup.cleanup() {
  }
}
