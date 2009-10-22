export TOSROOT=`pwd`
export TOSDIR="$TOSROOT/tos"
export CLASSPATH=$TOSROOT/support/sdk/java:$TOSROOT/support/sdk/java/tinyos.jar:$CLASSPATH
export MAKERULES="$TOSROOT/support/make/Makerules"

export CC2420_CHANNEL=19
export DEFAULT_LOCAL_GROUP=0x24

cd ../tinyos-2.x-quanto
. quanto_setup.sh
cd -
