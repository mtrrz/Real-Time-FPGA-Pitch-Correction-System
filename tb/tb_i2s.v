`timescale 1ns/1ps
// Self-checking loopback: behavioural ADC feeds i2s_core, core passes left to both DAC slots,
// behavioural DAC capture must see a recently sent sample on both channels.
module tb;
  reg clk = 0;
  always #42 clk = ~clk;

  wire mclk, sclk, lrck, sdin;
  reg  sdout = 0;
  wire [15:0] rl, rr;
  i2s_core dut (.clk_i(clk), .tx_l_i(rl), .tx_r_i(rl), .sdout_i(sdout),
                .mclk_o(mclk), .sclk_o(sclk), .lrck_o(lrck), .sdin_o(sdin),
                .rx_l_o(rl), .rx_r_o(rr), .rx_valid_o());

  // ---- ADC model ----
  reg        lrck_a = 0;
  reg [23:0] word = 0;
  integer    bitc = 23, n = 0;
  reg [15:0] cur_l = 0;
  reg [15:0] sent [0:255];
  always @(posedge sclk) begin
    if (lrck !== lrck_a) begin
      if (lrck == 0) begin n = n + 1; cur_l = 16'h1000 + n * 37; sent[n] = cur_l; word = {cur_l, 8'h00}; end
      else word = {~cur_l, 8'h00};
      bitc = 0;
    end
    lrck_a = lrck;
  end
  always @(negedge sclk) begin
    sdout <= word[23 - bitc];
    if (bitc < 23) bitc = bitc + 1;
  end

  // ---- DAC capture ----
  reg        lrck_d = 0;
  integer    c = 0, errs = 0, frames = 0, j;
  reg [15:0] sr = 0, cap_l = 0, cap_r = 0;
  reg        found;
  always @(posedge sclk) begin
    if (lrck !== lrck_d) c = 0; else c = c + 1;
    lrck_d = lrck;
    if (c >= 1 && c <= 16) sr = {sr[14:0], sdin};
    if (c == 16) begin
      if (!lrck) cap_l = sr;
      else begin
        cap_r = sr;
        frames = frames + 1;
        if (frames > 6) begin
          found = 0;
          for (j = n - 4; j <= n; j = j + 1) if (sent[j] == cap_l) found = 1;
          if (!found || cap_r !== cap_l) begin
            errs = errs + 1;
            $display("MISMATCH frame %0d: l=%h r=%h latest_sent=%h", frames, cap_l, cap_r, sent[n]);
          end
        end
      end
    end
  end

  initial begin
    #(84 * 512 * 30);
    if (errs == 0 && frames > 20) $display("PASS (%0d frames)", frames);
    else $display("FAIL errs=%0d frames=%0d", errs, frames);
    $finish;
  end
endmodule
