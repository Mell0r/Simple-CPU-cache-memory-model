`ifndef GUARD
`define GUARD

`define delay(TIME, CLOCK) \
        for (int i = 0; i < TIME; i++) begin \
            wait(clk == (i + !CLOCK) % 2); \
        end

`define BYTE 8
`define LINE_BYTE_SIZE 16
`define LINE_BIT_SIZE 16 * `BYTE

`define MEM_BYTE_SIZE (1 << 19)

`define CACHE_LINE_NUMBER 64
`define CACHE_WAY 2
`define CACHE_WAY_BLOCKS_NUMBER (`CACHE_LINE_NUMBER / `CACHE_WAY)

`define CTR1_BUS_SIZE 3
`define CTR2_BUS_SIZE 2

typedef enum int { NONE_C1 = 0, READ8 = 1, READ16 = 2, READ32 = 3, INVALIDATE = 4, WRITE8 = 5, WRITE16 = 6, WRITE32_OR_RESPONSE = 7 } C1_state;
typedef enum int { NONE = 0, RESPONSE = 1, READ = 2, WRITE = 3 } C2_state;

`define DATA1_BUS_SIZE 16
`define DATA2_BUS_BIT_SIZE 16
`define DATA2_BUS_BYTE_SIZE (`DATA2_BUS_BIT_SIZE / `BYTE)

`define ADDR1_BUS_SIZE 15
`define ADDR2_BUS_SIZE 15

`define TAG_SIZE 10
`define SET_SIZE 5
`define OFFSET_SIZE 4
`define MAX_WRITE_REQUEST_SIZE 32

`define CLOCK_DELAY 2
`define MEMORY_RESPONSE_TIME (`CLOCK_DELAY * 100)
`define CACHE_HIT_RESPONSE_TIME (`CLOCK_DELAY * 6)
`define CACHE_MISS_RESPONSE_TIME (`CLOCK_DELAY * 4)

`define MEMORY_INTERACTION_TICK_NUMBER (`LINE_BYTE_SIZE / `DATA2_BUS_BYTE_SIZE)
`define CACHE_INTERACTION_TICK_NUMBER 2

`endif //GUARD