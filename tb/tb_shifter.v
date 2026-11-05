`timescale 1ns/1ps
// Feed a 100-sample-period sine; the output must have ~2x the positive zero crossings (octave up).
module tb_shifter;
  reg clk = 0;
  always #5 clk = ~clk;
  reg valid = 0;
  reg signed [15:0] x = 0;
  wire signed [15:0] y;
  shifter dut (.clk_i(clk), .valid_i(valid), .x_i(x), .y_o(y));

  integer i, cin = 0, cout = 0, pin = 0, pout = 0;
  initial begin
    for (i = 0; i < 6000; i = i + 1) begin
      x = $rtoi(8000.0 * $sin(6.283185307 * i / 100.0));
      valid = 1; @(posedge clk); valid = 0;
      repeat (8) @(posedge clk);
      if (i >= 3000) begin
        if (pin < 0 && x >= 0) cin = cin + 1;
        if (pout < 0 && y >= 0) cout = cout + 1;
        pin = x; pout = y;
      end
    end
    // 3000 samples = 30 input periods -> expect 30 in, ~60 out
    if (cin >= 29 && cin <= 31 && cout >= 57 && cout <= 63) $display("PASS in=%0d out=%0d", cin, cout);
    else $display("FAIL in=%0d out=%0d", cin, cout);
    $finish;
  end
endmodule
