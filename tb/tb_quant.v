`timescale 1ns/1ps
// 260 (lag, d[lag-1], d[lag], d[lag+1]) cases from gen_vectors.py; RTL must match quant_fixed.py exactly.
module tb_quant;
  localparam NQ = 260;
  reg clk = 0;
  always #5 clk = ~clk;
  reg start = 0;
  reg [8:0] lag = 0;
  reg [19:0] dm = 0, d0 = 0, dp = 0;
  wire done, voiced;
  wire [5:0] sel;
  wire signed [15:0] step;
  quant dut (.clk_i(clk), .start_i(start), .lag_i(lag), .dm_i(dm), .d0_i(d0), .dp_i(dp),
             .done_o(done), .voiced_o(voiced), .sel_o(sel), .step_o(step));

  reg [19:0] qin  [0:4*NQ-1];
  reg [19:0] qexp [0:3*NQ-1];
  integer n, t, errs = 0;
  initial begin
    $readmemh("build/q_in.hex", qin);
    $readmemh("build/q_exp.hex", qexp);
    for (n = 0; n < NQ; n = n + 1) begin
      lag <= qin[4*n]; dm <= qin[4*n+1]; d0 <= qin[4*n+2]; dp <= qin[4*n+3];
      @(posedge clk); start <= 1; @(posedge clk); start <= 0;
      t = 0;
      @(posedge clk);
      while (!done && t < 1000) begin @(posedge clk); t = t + 1; end
      if (t >= 1000 || {voiced, sel, step} !== {qexp[3*n][0], qexp[3*n+1][5:0], qexp[3*n+2][15:0]}) begin
        errs = errs + 1;
        if (errs < 6) $display("MISMATCH case %0d lag=%0d: got %b %0d %0d exp %0d %0d %0d", n, qin[4*n],
                               voiced, sel, step, qexp[3*n], qexp[3*n+1], $signed(qexp[3*n+2][15:0]));
      end
    end
    if (errs == 0) $display("PASS (%0d cases)", NQ); else $display("FAIL errs=%0d", errs);
    $finish;
  end
endmodule
