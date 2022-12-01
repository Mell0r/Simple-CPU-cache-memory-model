`include "constants.sv"

module cache(
  input int log_stream,
  input int cache_stream,
  input wire clk, reset, c_dump,
  input wire[`ADDR1_BUS_SIZE - 1 : 0] a1_in,
  inout wire[`DATA1_BUS_SIZE - 1 : 0] d1_in,
  inout wire[`CTR1_BUS_SIZE - 1 : 0] c1_in,
  output wire[`ADDR2_BUS_SIZE - 1 : 0] a2_out,
  inout wire[`DATA2_BUS_BIT_SIZE - 1 : 0] d2_in,
  inout wire[`CTR2_BUS_SIZE - 1 : 0] c2_in
);
  reg[`DATA1_BUS_SIZE - 1 : 0] d1_reg = 'z;
  reg[`CTR1_BUS_SIZE - 1 : 0] c1_reg = 'z;
  reg[`ADDR2_BUS_SIZE - 1 : 0] a2_reg = 'z;
  reg[`DATA2_BUS_BIT_SIZE - 1 : 0] d2_reg = 'z;
  reg[`CTR2_BUS_SIZE - 1 : 0] c2_reg = NONE;
  assign d1_in = d1_reg;
  assign c1_in = c1_reg;
  assign d2_in = d2_reg;
  assign a2_out = a2_reg;
  assign c2_in = c2_reg;

  reg[`LINE_BIT_SIZE - 1 : 0] cache_memory[`CACHE_WAY_BLOCKS_NUMBER - 1 : 0][`CACHE_WAY - 1 : 0];
  reg[`TAG_SIZE - 1 : 0] line_tag[`CACHE_WAY_BLOCKS_NUMBER - 1 : 0][`CACHE_WAY - 1 : 0];
  reg modified[`CACHE_WAY_BLOCKS_NUMBER - 1 : 0][`CACHE_WAY - 1 : 0];
  reg invalid[`CACHE_WAY_BLOCKS_NUMBER - 1 : 0][`CACHE_WAY - 1 : 0];
  reg last_used[`CACHE_WAY_BLOCKS_NUMBER - 1 : 0];
  reg[`TAG_SIZE - 1 : 0] requested_tag;
  reg[`SET_SIZE - 1 : 0] requested_set;
  reg[`OFFSET_SIZE - 1 : 0] requested_offset;
  reg[`CTR1_BUS_SIZE - 1 : 0] requested_operation = NONE;
  reg[`MAX_WRITE_REQUEST_SIZE - 1 : 0] data_to_write;

  task write_to_memory(
    input reg[`SET_SIZE - 1 : 0] set, 
    input int ind_in_way_block
  );
    c2_reg = WRITE;
    a2_reg[`SET_SIZE +: `TAG_SIZE] = line_tag[set][ind_in_way_block];
    a2_reg[0 +: `SET_SIZE] = set;

    $fdisplay(log_stream, "Time: %0t, cache send write request to memory on a2: %b", $time, a2_out);

    for (int i = 0; i < `MEMORY_INTERACTION_TICK_NUMBER; i++) begin
      d2_reg = (cache_memory[set][ind_in_way_block] >> i * `DATA2_BUS_BIT_SIZE) & ((1 << `DATA2_BUS_BIT_SIZE) - 1);
      `delay(`CLOCK_DELAY, 0)
    end

    modified[set][ind_in_way_block] = 0;
    c2_reg = 'z;

    wait(clk == 1 && c2_in == RESPONSE);
    //Clock = 1

    $fdisplay(log_stream, "Time: %0t, memory answered to cache on write c2: %b", $time, c2_in);
    wait(clk == 0);
    //Clock = 0
    
    c2_reg = NONE;
    $fdisplay(log_stream, "Time: %0t, cache has taken the c2: %b", $time, c2_in);
  endtask;

  task read_from_memory(
    input reg[`TAG_SIZE - 1 : 0] tag, 
    input reg[`SET_SIZE - 1 : 0] set, 
    input int ind_in_way_block
  );
    c2_reg = READ;
    a2_reg[`SET_SIZE +: `TAG_SIZE] = tag;
    a2_reg[0 +: `SET_SIZE] = set;

    $fdisplay(log_stream, "Time: %0t, cache send read request to memory, a2: %b", $time, a2_out);

    `delay(`CLOCK_DELAY, 0)
    c2_reg = 'z;
    d2_reg = 'z;

    wait(clk == 1 && c2_in == RESPONSE);
    //Clock = 1

    cache_memory[set][ind_in_way_block] = 0;
    for (int i = 0; i < `MEMORY_INTERACTION_TICK_NUMBER; i++) begin
      cache_memory[set][ind_in_way_block][i * `DATA2_BUS_BIT_SIZE +: `DATA2_BUS_BIT_SIZE] = d2_in;
      `delay(`CLOCK_DELAY, 1)
    end;

    invalid[set][ind_in_way_block] = 0;
    modified[set][ind_in_way_block] = 0;
    line_tag[set][ind_in_way_block] = tag;
    $fdisplay(log_stream, "Time: %0t, memory answered to cache on read with data: %b", $time, cache_memory[set][ind_in_way_block]);

    wait(clk == 0);
    //Clock = 0
    
    c2_reg = NONE;
    $fdisplay(log_stream, "Time: %0t, cache has taken the c2: %b", $time, c2_in);
  endtask;

  task reset_cache;
    $fdisplay(log_stream, "Cache reset");
    for (int i = 0; i < `CACHE_WAY_BLOCKS_NUMBER; i++) begin
      for (int j = 0; j < `CACHE_WAY; j++) begin
        cache_memory[i][j] = 0;
        invalid[i][j] = 1;
        modified[i][j] = 0;
      end;
      last_used[i] = 0;
    end
  endtask

  task dump_cache;
    for (int i = 0; i < `CACHE_WAY_BLOCKS_NUMBER; i++) begin
      for (int j = 0; j < `CACHE_WAY; j++) begin
        $fdisplay(cache_stream, "tag: %b, set: %b, ind_in_way_block: %b, cache_line: %b", line_tag[i][j], i, j, cache_memory[i][j]);
      end
    end
  endtask

  initial reset_cache();

  int ind_in_way_block = -1;
  int requested_bit_offset;

  always @(posedge reset) 
    reset_cache();

  always @(posedge c_dump)
    dump_cache();

  always @(clk) begin

    if (clk == 1 && c1_in != NONE_C1) begin
      requested_operation = c1_in;
      requested_set = a1_in & ((1 << `SET_SIZE) - 1);
      requested_tag = (a1_in >> `SET_SIZE);
      if (c1_in == WRITE8)
        data_to_write = d1_in & ((1 << 8) - 1);
      else if (c1_in == WRITE16 || c1_in == WRITE32_OR_RESPONSE)
        data_to_write = d1_in;

      if (c1_in != INVALIDATE) begin
        `delay(`CLOCK_DELAY, 1)

        requested_offset = a1_in & ((1 << `OFFSET_SIZE) - 1);
        if (c1_in == WRITE32_OR_RESPONSE)
          data_to_write[`DATA1_BUS_SIZE +: `DATA1_BUS_SIZE] = d1_in;
      end
      
      $fdisplay(log_stream, "Time: %0t, cache got the request: %0d, tag: %b, set: %b, offset: %b", $time, requested_operation, requested_tag, requested_set, requested_offset);
      if (c1_in == WRITE8 || c1_in == WRITE16 || c1_in == WRITE32_OR_RESPONSE)
        $fdisplay(log_stream, "with data to write: %b", data_to_write);
    end
    
    if (clk == 0 && requested_operation != NONE) begin
      c1_reg = NONE_C1;
      $fdisplay(log_stream, "Time: %0t, cache has taken the c1 bus and started processing request", $time);

      if (requested_operation == INVALIDATE) begin
        for (int j = 0; j < `CACHE_WAY; j++) begin
          if (invalid[requested_set][j] == 0 && line_tag[requested_set][j] == requested_tag) begin
            last_used[requested_set] = !j;
            if (modified[requested_set][j])
              write_to_memory(requested_set, j);
            invalid[requested_set][j] = 1;
          end
        end
        c1_reg = WRITE32_OR_RESPONSE;
      end else begin
        ind_in_way_block = -1;
        for (int j = 0; j < `CACHE_WAY; j++)
          if (invalid[requested_set][j] == 0 && line_tag[requested_set][j] == requested_tag)
            ind_in_way_block = j;
        
        if (ind_in_way_block == -1) begin
          $fdisplay(log_stream, "Time: %0t, cache miss at set: %b at tag: %b", $time, requested_set, requested_tag);
          test_simulation.cpu_inst.cache_misses++;
          `delay(`CACHE_MISS_RESPONSE_TIME - `CACHE_INTERACTION_TICK_NUMBER * `CLOCK_DELAY, 0)

          ind_in_way_block = !last_used[requested_set];
          
          if (modified[requested_set][ind_in_way_block] == 1 && invalid[requested_set][ind_in_way_block] == 0)
            write_to_memory(requested_set, ind_in_way_block);

          read_from_memory(requested_tag, requested_set, ind_in_way_block);
        end else begin
          $fdisplay(log_stream, "Time: %0t, cache hit at set: %b at tag: %b", $time, requested_set, requested_tag);
          test_simulation.cpu_inst.cache_hits++;
          `delay(`CACHE_HIT_RESPONSE_TIME - `CACHE_INTERACTION_TICK_NUMBER * `CLOCK_DELAY, 0)
        end

        c1_reg = WRITE32_OR_RESPONSE;
        requested_bit_offset = requested_offset * 8; //bytes to bits
        
        case (requested_operation) 
          WRITE8: begin
            cache_memory[requested_set][ind_in_way_block][requested_bit_offset +: 8] = data_to_write;
            modified[requested_set][ind_in_way_block] = 1;
          end

          WRITE16: begin
            cache_memory[requested_set][ind_in_way_block][requested_bit_offset +: 16] = data_to_write;
            modified[requested_set][ind_in_way_block] = 1;
          end

          WRITE32_OR_RESPONSE: begin
            cache_memory[requested_set][ind_in_way_block][requested_bit_offset +: 32] = data_to_write;
            modified[requested_set][ind_in_way_block] = 1;
          end

          READ8: d1_reg = cache_memory[requested_set][ind_in_way_block][requested_bit_offset +: 8];

          READ16: d1_reg = cache_memory[requested_set][ind_in_way_block][requested_bit_offset +: 16];

          READ32: begin
            $fdisplay(log_stream, "Time: %0t, cache_memory: %b", $time, cache_memory[requested_set][ind_in_way_block][requested_bit_offset +: 16]);
            d1_reg = cache_memory[requested_set][ind_in_way_block][requested_bit_offset +: 16];
            `delay(`CLOCK_DELAY, 0);
            $fdisplay(log_stream, "Time: %0t, cache_memory: %b", $time, cache_memory[requested_set][ind_in_way_block][requested_bit_offset + 16 +: 16]);
            d1_reg = cache_memory[requested_set][ind_in_way_block][requested_bit_offset + 16 +: 16];
          end
        endcase

        last_used[requested_set] = ind_in_way_block;
      end

      `delay(`CLOCK_DELAY, 0)

      $fdisplay(log_stream, "Time: %0t, cache has given the c1 bus", $time);
      c1_reg = 'z;
      d1_reg = 'z;
      requested_operation = NONE;
    end
  end;
endmodule;