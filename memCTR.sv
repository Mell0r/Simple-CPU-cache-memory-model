`include "constants.sv"

module memCTR #(parameter _SEED = 225526) (
  input int log_stream,
  input int mem_stream,
  input wire clk, reset, m_dump, 
  input wire[`ADDR2_BUS_SIZE - 1 : 0] a2_in, 
  inout wire[`DATA2_BUS_BIT_SIZE - 1 : 0] d2_in, 
  inout wire[`CTR2_BUS_SIZE - 1 : 0] c2_in
);
  integer SEED = _SEED;

  reg[`DATA2_BUS_BIT_SIZE - 1 : 0] d2_reg = 'z;
  reg[`CTR2_BUS_SIZE - 1 : 0] c2_reg = 'z;
  assign d2_in = d2_reg;
  assign c2_in = c2_reg;

  reg[`BYTE - 1 : 0] ram[`MEM_BYTE_SIZE - 1 : 0];

  task reset_ram;
    for (int i = 0; i < `MEM_BYTE_SIZE; i++)
      ram[i] = $random(SEED) >> 16;
    $fdisplay(log_stream, "Memory reset");
  endtask

  task dump_memory;
    $fdisplay(mem_stream,"Memory dump. t: %0t", $time);
    for (int i = 0; i < 50000; i++)
      $fdisplay(mem_stream, "[tag = %0d, set = %0d, offset = %0d] %0d", i / (16 * 32), (i / 16) % 32, i % 16, ram[i]);
    $fdisplay(mem_stream, "-------------------------------------------------------");
    // for (int i = 0; i < `MEM_BYTE_SIZE; i++)
    //   $fdisplay(mem_stream, "tag: %0d, set: %0d, offset: %0d, data: %0d", i / (16 * 32), (i / 16) % 32, i % 16, ram[i]);
  endtask

  reg[`CTR2_BUS_SIZE - 1 : 0] requested_operation = NONE;
  reg[`ADDR2_BUS_SIZE - 1 : 0] data_from = 0;

  initial begin
    reset_ram();
  end

  always @(posedge reset) 
    reset_ram();

  always @(posedge m_dump)
    $dumpvars(0, memCTR);

  always @(clk) begin
    if (m_dump)
      $dumpvars(0, memCTR);

    if (reset)
      reset_ram(); 

    if (clk == 1 && c2_in != NONE) begin
      requested_operation = c2_in;
      case (c2_in)
        READ: begin
          $fdisplay(log_stream, "Time: %0t, memory read at adress: %b", $time, a2_in);

          data_from = a2_in;
        end
        WRITE: begin
          $fdisplay(log_stream, "Time: %0t, memory write at adress: %b", $time, a2_in);

          for (int i = 0; i < `MEMORY_INTERACTION_TICK_NUMBER; i++) begin
            if (i > 0)
              `delay(`CLOCK_DELAY, 1)
            for (int j = 0; j < `DATA2_BUS_BYTE_SIZE; j++)
              ram[a2_in * `LINE_BYTE_SIZE + i * `DATA2_BUS_BYTE_SIZE + j] = (d2_in >> (j * `BYTE)) & ((1 << `BYTE) - 1);
          end
        end
      endcase
    end
    
    if (clk == 0 && requested_operation != NONE) begin
      c2_reg = NONE;
      $fdisplay(log_stream, "Time: %0t, memory has taken the bus and started processing request", $time);

      if (requested_operation == READ)
        `delay(`MEMORY_RESPONSE_TIME - `CLOCK_DELAY, 0)
      else
        `delay(`MEMORY_RESPONSE_TIME - `MEMORY_INTERACTION_TICK_NUMBER * `CLOCK_DELAY, 0)

      c2_reg = RESPONSE;
      $fdisplay(log_stream, "Time: %0t, memory start answering", $time);
      if (requested_operation == READ) begin
        for (int i = 0; i < `MEMORY_INTERACTION_TICK_NUMBER; i++) begin
          if (i > 0)
            `delay(`CLOCK_DELAY, 0)
          d2_reg = 0;
          for (int j = 0; j < `DATA2_BUS_BYTE_SIZE; j++)
            d2_reg[j * `BYTE +: `BYTE] = ram[data_from * `LINE_BYTE_SIZE + i * `DATA2_BUS_BYTE_SIZE + j];
        end
      end

      `delay(`CLOCK_DELAY, 0)

      c2_reg = 'z;
      d2_reg = 'z;

      $fdisplay(log_stream, "Time: %0t, memory has given the bus", $time);
      requested_operation = NONE;
    end
  end
endmodule