#
# This class is automatically generated by mig. DO NOT EDIT THIS FILE.
# This class implements a Python interface to the 'TctsCmdMsg'
# message type.
#

import tinyos.message.Message

# The default size of this message type in bytes.
DEFAULT_MESSAGE_SIZE = 1

# The Active Message type associated with this message.
AM_TYPE = 150

class TctsCmdMsg(tinyos.message.Message.Message):
    # Create a new TctsCmdMsg of size 1.
    def __init__(self, data="", addr=None, gid=None, base_offset=0, data_length=1):
        tinyos.message.Message.Message.__init__(self, data, addr, gid, base_offset, data_length)
        self.amTypeSet(AM_TYPE)
    
    # Get AM_TYPE
    def get_amType(cls):
        return AM_TYPE
    
    get_amType = classmethod(get_amType)
    
    #
    # Return a String representation of this message. Includes the
    # message type name and the non-indexed field values.
    #
    def __str__(self):
        s = "Message <TctsCmdMsg> \n"
        try:
            s += "  [cmd=0x%x]\n" % (self.get_cmd())
        except:
            pass
        return s

    # Message-type-specific access methods appear below.

    #
    # Accessor methods for field: cmd
    #   Field type: short
    #   Offset (bits): 0
    #   Size (bits): 8
    #

    #
    # Return whether the field 'cmd' is signed (False).
    #
    def isSigned_cmd(self):
        return False
    
    #
    # Return whether the field 'cmd' is an array (False).
    #
    def isArray_cmd(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'cmd'
    #
    def offset_cmd(self):
        return (0 / 8)
    
    #
    # Return the offset (in bits) of the field 'cmd'
    #
    def offsetBits_cmd(self):
        return 0
    
    #
    # Return the value (as a short) of the field 'cmd'
    #
    def get_cmd(self):
        return self.getUIntElement(self.offsetBits_cmd(), 8, 1)
    
    #
    # Set the value of the field 'cmd'
    #
    def set_cmd(self, value):
        self.setUIntElement(self.offsetBits_cmd(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'cmd'
    #
    def size_cmd(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'cmd'
    #
    def sizeBits_cmd(self):
        return 8
    
