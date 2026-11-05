`timescale 1ns/1ps
// Closed loop at real timing: 512 clocks per frame. A sine at +freq Hz goes through the whole autotune core;
// the output frequency (from zero-crossing times) must land on +target Hz within 1%.
module tb_loop;
  localparam NFR = 20000, MEAS = 12000;
  real FS = 25.5e6 / 512;
  integer freq = 225;
  real target = 220.0;
  reg clk = 0;
  always #5 clk = ~clk;
  reg valid = 0;
  reg signed [15:0] x = 0;
  wire signed [15:0] y;
  wire voiced;
  wire [5:0] sel;
  autotune dut (.clk_i(clk), .valid_i(valid), .x_i(x), .y_o(y), .voiced_o(voiced), .sel_o(sel));

  integer n, nc = 0;
  real yp = 0, t, t0 = 0, t1 = 0, fout, err;
  initial begin
    if (!$value$plusargs("freq=%d", freq)) freq = 225;
    if (!$value$plusargs("target=%f", target)) target = 220.0;
    for (n = 0; n < NFR; n = n + 1) begin
      x <= $rtoi(8000.0 * $sin(6.283185307 * freq * n / FS));
      valid <= 1; @(posedge clk); valid <= 0;
      repeat (511) @(posedge clk);
      if (n >= MEAS) begin
        if (yp < 0 && y >= 0) begin
          t = n - 1 + (-yp) / (y - yp);               // interpolated crossing time, in frames
          if (nc == 0) t0 = t;
          t1 = t; nc = nc + 1;
        end
        yp = y;
      end
    end
    fout = (nc - 1) * FS / (t1 - t0);
    err = 100.0 * (fout / target - 1.0);
    $display("in %0d Hz -> out %.2f Hz (target %.2f, err %.2f%%, sel=%0d voiced=%b, %0d crossings)", freq, fout, target, err, sel, voiced, nc);
    if (nc > 20 && err > -1.0 && err < 1.0) $display("PASS"); else $display("FAIL");
    $finish;
  end
endmodule
