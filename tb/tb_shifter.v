`timescale 1ns/1ps
// Feed a 100-sample-period sine for several ratios; the output must have ratio x the positive zero crossings.
module tb_shifter;
  reg clk = 0;
  always #5 clk = ~clk;
  reg valid = 0;
  reg signed [15:0] x = 0;
  reg signed [15:0] step = 0;
  wire signed [15:0] y;
  shifter dut (.clk_i(clk), .valid_i(valid), .x_i(x), .step_i(step), .y_o(y));

  integer i, cin, cout, pin, pout, errs = 0;
  // run(step, lo, hi): 3000 samples settle, then 30 input periods counted; out crossings must be in [lo,hi]
  task run(input integer s, input integer lo, input integer hi);
    begin
      step <= s; cin = 0; cout = 0; pin = 0; pout = 0;
      for (i = 0; i < 6000; i = i + 1) begin
        x <= $rtoi(8000.0 * $sin(6.283185307 * i / 100.0));
        valid <= 1; @(posedge clk); valid <= 0;
        repeat (39) @(posedge clk);
        if (i >= 3000) begin
          if (pin < 0 && x >= 0) cin = cin + 1;
          if (pout < 0 && y >= 0) cout = cout + 1;
          pin = x; pout = y;
        end
      end
      if (cin < 29 || cin > 31 || cout < lo || cout > hi) begin
        errs = errs + 1; $display("FAIL step=%0d in=%0d out=%0d (want %0d..%0d)", s, cin, cout, lo, hi);
      end else $display("ok   step=%0d in=%0d out=%0d", s, cin, cout);
    end
  endtask

  initial begin
    run(-1024, 57, 63);   // x2.0   -> 60
    run(-512,  43, 47);   // x1.5   -> 45
    run(-256,  36, 39);   // x1.25  -> 37.5
    run(0,     29, 31);   // x1.0   -> 30
    run(256,   21, 24);   // x0.75  -> 22.5
    if (errs == 0) $display("PASS"); else $display("FAIL errs=%0d", errs);
    $finish;
  end
endmodule
