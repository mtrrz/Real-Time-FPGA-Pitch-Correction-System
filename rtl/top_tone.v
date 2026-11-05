// Debug: ignore the input, play a ~440 Hz sawtooth on the Pmod line-out. Isolates clocks/pins/DAC.
// Green LED = input signal present (same as top.v), so one build also tests the input path.
module top_tone (
  input  wire clk,
  output wire da_mclk, da_lrck, da_sclk, da_sdin,
  output wire ad_mclk, ad_lrck, ad_sclk,
  input  wire ad_sdout,
  output wire led_r, led_g
);
  wire clk_o, mclk, sclk, lrck, valid;
  wire [15:0] l;
  reg  [15:0] phase = 0;
  always @(posedge clk_o) if (valid) phase <= phase + 16'd579;  // 440 Hz at 49.8 kHz
  wire [15:0] tone = $signed(phase) >>> 2;                      // quarter scale, don't blast the speakers

  SB_PLL40_PAD #(.FEEDBACK_PATH("SIMPLE"), .PLLOUT_SELECT("GENCLK"),
                 .DIVR(4'b0000), .DIVF(7'b1000011), .DIVQ(3'b101), .FILTER_RANGE(3'b001))
  pll (.PACKAGEPIN(clk), .PLLOUTCORE(clk_o), .RESETB(1'b1), .BYPASS(1'b0));

  i2s_core i2s (
    .clk_i(clk_o), .tx_l_i(tone), .tx_r_i(tone), .sdout_i(ad_sdout),
    .mclk_o(mclk), .sclk_o(sclk), .lrck_o(lrck), .sdin_o(da_sdin),
    .rx_l_o(l), .rx_r_o(), .rx_valid_o(valid)
  );

  assign {da_mclk, ad_mclk} = {2{mclk}};
  assign {da_sclk, ad_sclk} = {2{sclk}};
  assign {da_lrck, ad_lrck} = {2{lrck}};
  assign led_g = ~(l[15:8] != 8'h00 && l[15:8] != 8'hff);
  assign led_r = 1'b1;
endmodule
