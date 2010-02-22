import os,sys
import time

time.sleep(1)

for i in range(0,25000):
    sys.stdout.flush()
    os.system("gotemp>/dev/null")
    os.system("gotemp")
    sys.stdout.write("\t%d %s: \t"%(time.time(), time.ctime()))
    sys.stdout.write("\tVOLT %.1f\n"%(i/10.0))
    sys.stdout.flush()
    time.sleep(2)
