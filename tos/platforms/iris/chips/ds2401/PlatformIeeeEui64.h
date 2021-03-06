// $Id: PlatformIeeeEui64.h,v 1.1 2008/10/31 17:05:09 sallai Exp $
/*
 * Copyright (c) 2007, Vanderbilt University
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 *
 * IN NO EVENT SHALL THE VANDERBILT UNIVERSITY BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE VANDERBILT
 * UNIVERSITY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * THE VANDERBILT UNIVERSITY SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE VANDERBILT UNIVERSITY HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 * Author: Janos Sallai
 */

#ifndef PLATFORMIEEEEUI64_H
#define PLATFORMIEEEEUI64_H

/* For now, let us set the company ID to 'X' 'B' 'W', and the first two bytes
 * of the serial ID to 'I' 'R'. The last three bytes of the serial ID are read
 * from the DS2401 chip.
 */
 
enum {
  IEEE_EUI64_COMPANY_ID_0 = 'X',
  IEEE_EUI64_COMPANY_ID_1 = 'B',
  IEEE_EUI64_COMPANY_ID_2 = 'W',
  IEEE_EUI64_SERIAL_ID_0 = 'I',
  IEEE_EUI64_SERIAL_ID_1 = 'R',
};

#endif // PLATFORMIEEEEUI64_H
