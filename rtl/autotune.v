// Autotune core: left sample in once per frame, corrected sample out ~35 clocks later.
// detector (decim3 -> amdf) -> quantizer -> step -> shifter. Chromatic scale only.
// shortcut: a new ratio takes effect instantly at each 20 ms detection (hard-snap "robotic" setting);
// add smoothing between step_r and the shifter for the natural-sounding setting.
module autotune (
  input  wire               clk_i,
  input  wire               valid_i,
  input  wire signed [15:0] x_i,
  output wire signed [15:0] y_o,
  output wire               voiced_o,
  output wire [5:0]         sel_o
);
  wire dv;
  wire signed [11:0] dx;
  decim3 dec (.clk_i(clk_i), .valid_i(valid_i), .x_i(x_i), .valid_o(dv), .y_o(dx));

  wire adone;
  wire [8:0] lag;
  wire [19:0] dm, d0, dp;
  amdf det (.clk_i(clk_i), .valid_i(dv), .x_i(dx), .done_o(adone), .lag_o(lag),
            .dm_o(dm), .d0_o(d0), .dp_o(dp));

  wire qdone;
  wire signed [15:0] qstep;
  quant q (.clk_i(clk_i), .start_i(adone), .lag_i(lag), .dm_i(dm), .d0_i(d0), .dp_i(dp),
           .done_o(qdone), .voiced_o(voiced_o), .sel_o(sel_o), .step_o(qstep));

  reg signed [15:0] step_r = 0;
  always @(posedge clk_i) if (qdone) step_r <= qstep;

  shifter sh (.clk_i(clk_i), .valid_i(valid_i), .x_i(x_i), .step_i(step_r), .y_o(y_o));
endmodule
