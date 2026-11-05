`timescale 1ns/1ps
// Streams build/vec_in.hex into the detector at a realistic rate and checks every hop result
// (lag, d[lag-1], d[lag], d[lag+1]) against build/vec_exp.hex from model/amdf_fixed.py.
module tb_amdf;
  localparam NS = 5120, NH = 16, SP = 1000;   // keep NS in sync with gen_vectors.py
  reg clk = 0;
  always #5 clk = ~clk;
  reg valid = 0;
  reg signed [11:0] x = 0;
  wire done;
  wire [8:0] lag;
  wire [19:0] dm, d0, dp;
  amdf dut (.clk_i(clk), .valid_i(valid), .x_i(x), .done_o(done), .lag_o(lag),
            .dm_o(dm), .d0_o(d0), .dp_o(dp));

  reg [11:0] vin  [0:NS-1];
  reg [19:0] vexp [0:4*NH-1];
  integer n, h = 0, errs = 0;

  always @(posedge clk) if (done) begin
    if (h < NH && {lag, dm, d0, dp} !== {vexp[4*h][8:0], vexp[4*h+1], vexp[4*h+2], vexp[4*h+3]}) begin
      errs = errs + 1;
      $display("MISMATCH hop %0d: got %0d %0d %0d %0d exp %0d %0d %0d %0d", h, lag, dm, d0, dp,
               vexp[4*h], vexp[4*h+1], vexp[4*h+2], vexp[4*h+3]);
    end
    h = h + 1;
  end

  initial begin
    $readmemh("build/vec_in.hex", vin);
    $readmemh("build/vec_exp.hex", vexp);
    for (n = 0; n < NS; n = n + 1) begin
      x <= vin[n]; valid <= 1; @(posedge clk); valid <= 0;
      repeat (SP - 1) @(posedge clk);
    end
    repeat (350000) @(posedge clk);             // last hop's compute
    if (errs == 0 && h == NH) $display("PASS (%0d hops)", h);
    else $display("FAIL errs=%0d hops=%0d/%0d", errs, h, NH);
    $finish;
  end
endmodule
