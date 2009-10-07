import os,sys
sys.path.append("/home/thomas/projects/agilentlib/trunk")
import E3631A
import time

device = sys.argv[1]

ea = E3631A.E3631A(device)

ea.setVoltageP25(0.0)
time.sleep(1)
ea.setVoltageN25(0.0)
time.sleep(1)

ea.outputOn()
time.sleep(1)

for i in range(0,250):
    sys.stdout.flush()
    os.system("gotemp>/dev/null")
    os.system("gotemp")
    sys.stdout.write("\t%d %s: \t"%(time.time(), time.ctime()))
    sys.stdout.write("\tVOLT %.1f\n"%(i/10.0))
    sys.stdout.flush()
    ea.setVoltageP25(i/10.0)
    time.sleep(5*60)

#for i in range(1,250):
#    sys.stdout.flush()
#    os.system("gotemp")
#    sys.stdout.flush()
#    sys.stdout.write("\t%d %s: \t"%(time.time(), time.ctime()))
#    sys.stdout.write("\tVOLT %.1f\n"%(25+i/10.0))
#    sys.stdout.flush()
#    ea.setVoltageN25(i/10.0)
#    time.sleep(5*60)


#print ea.ser.readline()
