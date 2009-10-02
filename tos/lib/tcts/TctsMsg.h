#ifndef TCTS_MSG_H
#define TCTS_MSG_H

typedef nx_struct tcts_msg
{
    nx_uint8_t cmd;
    nx_uint16_t startIndex;
    nx_float skews[10];
} tcts_msg_t;

typedef nx_struct tcts_cmd_msg
{
    nx_uint8_t cmd;
} tcts_cmd_msg_t;

enum
{
    AM_TCTS_MSG = 138,
    AM_TCTS_CMD_MSG = 150
};

enum
{
    GET_SKEWS = 1,
    WRITE_CONFIG = 2,

    SKEW_RSP = 0x81,
    WRITE_RSP = 0x82,
    WRITE_FAILED_RSP = 0x83,
};

#endif //TCTS_MSG_H
