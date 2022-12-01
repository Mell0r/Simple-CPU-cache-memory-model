`include "constants.sv"

module cpu #(parameter M = 64, parameter N = 60, parameter K = 32) (
  input int log_stream,
  input int mem_stream,
  input int cache_stream,
  input wire clk, 
  output wire[`ADDR1_BUS_SIZE - 1 : 0] a1_bus, 
  inout wire[`DATA1_BUS_SIZE - 1 : 0] d1_in, 
  inout wire[`CTR1_BUS_SIZE - 1 : 0] c1_in
);
  reg[`ADDR1_BUS_SIZE -1 : 0] a1_reg = 'z;
  reg[`DATA1_BUS_SIZE - 1 : 0] d1_reg = 'z;
  reg[`CTR1_BUS_SIZE - 1 : 0] c1_reg = 'z;
  assign a1_bus = a1_reg;
  assign d1_in = d1_reg;
  assign c1_in = c1_reg;
  
  int cache_hits;
  int cache_misses;

  task read8(
    input [`TAG_SIZE - 1 : 0] tag, 
    input [`SET_SIZE - 1 : 0] set, 
    input [`OFFSET_SIZE - 1: 0] offset,
    output reg[7 : 0] res
  );
    wait(clk == 0);
    //clock = 0

    c1_reg = READ8;
    a1_reg[`SET_SIZE +: `TAG_SIZE] = tag;
    a1_reg[0 +: `SET_SIZE] = set;

    `delay(`CLOCK_DELAY, 0)

    a1_reg = offset;  

    `delay(`CLOCK_DELAY, 0)

    c1_reg = 'z;
    d1_reg = 'z;
    a1_reg = 'z;
    $fdisplay(log_stream, "Time: %0t, cpu has given c1: %b", $time, c1_in);

    wait(c1_in == WRITE32_OR_RESPONSE && clk == 1);
    //Clock = 1
    res = d1_in;

    $fdisplay(log_stream, "Time: %0t, cpu listening d1: %b, c1: %b", $time, d1_in, c1_in);
    $fdisplay(log_stream, "Time: %0t, cash answer on read c1: %b, res: %0d", $time, c1_in, res);

    wait(clk == 0);

    c1_reg = NONE_C1;
  endtask

  task read16(
    input [`TAG_SIZE - 1 : 0] tag,
    input [`SET_SIZE - 1 : 0] set, 
    input [`OFFSET_SIZE - 1: 0] offset,
    output reg[15 : 0] res
  );
    wait(clk == 0);
    //clock = 0

    c1_reg = READ16;
    a1_reg[`SET_SIZE +: `TAG_SIZE] = tag;
    a1_reg[0 +: `SET_SIZE] = set;

    `delay(`CLOCK_DELAY, 0)

    a1_reg = offset;

    `delay(`CLOCK_DELAY, 0)

    c1_reg = 'z;
    d1_reg = 'z;
    a1_reg = 'z;
    $fdisplay(log_stream, "Time: %0t, cpu has given c1: %b", $time, c1_in);

    wait(c1_in == WRITE32_OR_RESPONSE && clk == 1);
    //Clock = 1
    res = d1_in;

    $fdisplay(log_stream, "Time: %0t, cpu listening d1: %b, c1: %b", $time, d1_in, c1_in);
    $fdisplay(log_stream, "Time: %0t, cash answer on read c1: %b, res: %0d", $time, c1_in, res);

    wait(clk == 0);

    c1_reg = NONE_C1;
  endtask

  task read32(
    input [`TAG_SIZE - 1 : 0] tag,
    input [`SET_SIZE - 1 : 0] set, 
    input [`OFFSET_SIZE - 1: 0] offset,
    output reg[31 : 0] res
  );
    wait(clk == 0);
    //clock = 0

    c1_reg = READ32;
    a1_reg[`SET_SIZE +: `TAG_SIZE] = tag;
    a1_reg[0 +: `SET_SIZE] = set;

    `delay(`CLOCK_DELAY, 0)

    a1_reg = offset;

    `delay(`CLOCK_DELAY, 0)

    c1_reg = 'z;
    d1_reg = 'z;
    a1_reg = 'z;
    $fdisplay(log_stream, "Time: %0t, cpu has given c1: %b", $time, c1_in);

    wait(c1_in == WRITE32_OR_RESPONSE && clk == 1);
    //Clock = 1
    res[15 : 0] = d1_in;
    $fdisplay(log_stream, "Time: %0t, cpu listening d1: %b, c1: %b", $time, d1_in, c1_in);

    `delay(`CLOCK_DELAY, 1)

    res[31 : 16] = d1_in;

    $fdisplay(log_stream, "Time: %0t, cpu listening d1: %b, c1: %b", $time, d1_in, c1_in);
    $fdisplay(log_stream, "Time: %0t, cash answer on read c1: %b, res: %0d", $time, c1_in, res);

    wait(clk == 0);

    c1_reg = NONE_C1;
  endtask

  task write32(
    input [`TAG_SIZE - 1 : 0] tag, 
    input [`SET_SIZE - 1 : 0] set, 
    input [`OFFSET_SIZE - 1: 0] offset,
    input reg[31 : 0] info
  );
    wait(clk == 0);
    //Clock = 0
    c1_reg = WRITE32_OR_RESPONSE;
    a1_reg[`SET_SIZE +: `TAG_SIZE] = tag;
    a1_reg[0 +: `SET_SIZE] = set;
    d1_reg = info & ((1 << `DATA1_BUS_SIZE) - 1);

    `delay(`CLOCK_DELAY, 0)
    a1_reg = offset;
    d1_reg = (info >> `DATA1_BUS_SIZE) & ((1 << `DATA1_BUS_SIZE) - 1);

    `delay(`CLOCK_DELAY, 0)
    
    //Clock = 0
    c1_reg = 'z;
    d1_reg = 'z;

    wait(c1_in == WRITE32_OR_RESPONSE && clk == 1);
    //Clock = 1
    $fdisplay(log_stream, "Time: %0t, cash answer on write c1:%b", $time, c1_in);

    wait(clk == 0);
    //Clock = 0
    c1_reg = NONE_C1;
  endtask

  int j;
  
  reg[7 : 0] a; 
  task readA(input int row, input int col);
    j = row * K + col;
    read8(j / ((1 << `OFFSET_SIZE) * (1 << `SET_SIZE)), (j / (1 << `OFFSET_SIZE)) % (1 << `SET_SIZE), j % (1 << `OFFSET_SIZE), a);
  endtask

  reg[15 : 0] b; 
  task readB(input int row, input int col);
    j = M * K + (row * N + col) * 2;
    read16(j / ((1 << `OFFSET_SIZE) * (1 << `SET_SIZE)), (j / (1 << `OFFSET_SIZE)) % (1 << `SET_SIZE), j % (1 << `OFFSET_SIZE), b);
  endtask

  reg[31 : 0] c; 
  task writeC(input int row, input int col);
    j = M * K + K * N * 2 + (row * N + col) * 4;
    write32(j / ((1 << `OFFSET_SIZE) * (1 << `SET_SIZE)), (j / (1 << `OFFSET_SIZE)) % (1 << `SET_SIZE), j % (1 << `OFFSET_SIZE), c);
  endtask

  task readC(input int row, input int col);
    j = M * K + K * N * 2 + (row * N + col) * 4;
    read32(j / ((1 << `OFFSET_SIZE) * (1 << `SET_SIZE)), (j / (1 << `OFFSET_SIZE)) % (1 << `SET_SIZE), j % (1 << `OFFSET_SIZE), c);
  endtask

  int s;
  int result_stream;
  initial begin
    `delay(`CLOCK_DELAY, 0) //pa init
    `delay(`CLOCK_DELAY, 0) //pc init
    for (int y = 0; y < M; y++) begin
      `delay(`CLOCK_DELAY, 0) //y init and ++ later

      for (int x = 0; x < N; x++) begin
        `delay(`CLOCK_DELAY, 0) //x init and ++ later

        `delay(`CLOCK_DELAY, 0) //pb init
        c = 0;
        `delay(`CLOCK_DELAY, 0) //s init
        for (int k = 0; k < K; k++) begin
          `delay(`CLOCK_DELAY, 0) //k init and ++ later

          readA(y, k);
          readB(k, x);
          c += a * b;
          `delay(`CLOCK_DELAY * (5 + 1), 0) // += and *
          `delay(`CLOCK_DELAY, 0) //pb +=
          
          `delay(`CLOCK_DELAY, 0) //k new iter
        end
        writeC(y, x);
        
        `delay(`CLOCK_DELAY, 0) //x new iter
      end
      `delay(`CLOCK_DELAY, 0) //pa +=
      `delay(`CLOCK_DELAY, 0) //pc += 
      `delay(`CLOCK_DELAY, 0) //y new iter
    end
    `delay(`CLOCK_DELAY, 0) //fun exit

    $display("Cache requests: %0d", cache_misses + cache_hits);
    $display("Cache hits: %0d", cache_hits);
    $display("Total ticks: %0t", $time / `CLOCK_DELAY);
    
    result_stream = $fopen("output_files/result.txt", "w");

    for (int y = 0; y < M; y++) begin
      for (int x = 0; x < N; x++) begin
        readC(y, x);
        $fdisplay(result_stream, "%0d", c);
      end
    end

    `delay(`CLOCK_DELAY, 0)

    $fclose(result_stream);
    $fclose(log_stream);
    $fclose(mem_stream);
    $fclose(cache_stream);

    $finish;
  end
endmodule;