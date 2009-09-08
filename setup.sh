export TOSROOT=`pwd`
export TOSDIR="$TOSROOT/tos"
export CLASSPATH=$TOSROOT/support/sdk/java:$TOSROOT/support/sdk/java/tinyos.jar:$CLASSPATH
export MAKERULES="$TOSROOT/support/make/Makerules"

cd ../tinyos-2.x-quanto
. quanto_setup.sh
cd -
