`include "constants.sv"
`include "memCTR.sv"
`include "cache.sv"
`include "cpu.sv"

module test_simulation(
  output wire clk, reset,
  output reg c_dump, m_dump, 
  output wire[`ADDR1_BUS_SIZE - 1 : 0] a1, 
  output wire[`DATA1_BUS_SIZE - 1 : 0] d1, 
  output wire[`CTR1_BUS_SIZE - 1 : 0] c1,
  output wire[`ADDR2_BUS_SIZE - 1 : 0] a2, 
  output wire[`DATA2_BUS_BIT_SIZE - 1 : 0] d2, 
  output wire[`CTR2_BUS_SIZE - 1 : 0] c2
);
  int log_stream = $fopen("output_files/log.txt", "w");
  int mem_stream = $fopen("output_files/memory_dump.txt", "w");
  int cache_stream = $fopen("output_files/cache_dump.txt", "w");

  clock c(clk);
  cpu cpu_inst(log_stream, mem_stream, cache_stream, clk, a1, d1, c1);
  cache cache_inst(log_stream, cache_stream, clk, reset, c_dump, a1, d1, c1, a2, d2, c2);
  memCTR mem_inst(log_stream, mem_stream, clk, reset, m_dump, a2, d2, c2);

endmodule;

module clock(output reg clk);

  always begin
    clk = 0;
    #1;
    clk = 1;
    #1;
  end
endmodule