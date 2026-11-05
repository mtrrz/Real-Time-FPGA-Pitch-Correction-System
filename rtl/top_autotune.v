// Phase 4: real-time autotune. Pmod I2S2 on PMOD1B, left input -> autotune -> both outputs.
// Green LED = a pitch is being detected (voiced). Same PLL as top.v (25.5 MHz).
module top_autotune (
  input  wire clk,
  output wire da_mclk, da_lrck, da_sclk, da_sdin,
  output wire ad_mclk, ad_lrck, ad_sclk,
  input  wire ad_sdout,
  output wire led_r, led_g
);
  wire clk_o, mclk, sclk, lrck, valid, voiced;
  wire [15:0] l;
  wire [15:0] y;
  wire [5:0] sel;

  SB_PLL40_PAD #(.FEEDBACK_PATH("SIMPLE"), .PLLOUT_SELECT("GENCLK"),
                 .DIVR(4'b0000), .DIVF(7'b1000011), .DIVQ(3'b101), .FILTER_RANGE(3'b001))
  pll (.PACKAGEPIN(clk), .PLLOUTCORE(clk_o), .RESETB(1'b1), .BYPASS(1'b0));

  i2s_core i2s (
    .clk_i(clk_o), .tx_l_i(y), .tx_r_i(y), .sdout_i(ad_sdout),
    .mclk_o(mclk), .sclk_o(sclk), .lrck_o(lrck), .sdin_o(da_sdin),
    .rx_l_o(l), .rx_r_o(), .rx_valid_o(valid)
  );

  autotune at (.clk_i(clk_o), .valid_i(valid), .x_i(l), .y_o(y), .voiced_o(voiced), .sel_o(sel));

  assign {da_mclk, ad_mclk} = {2{mclk}};
  assign {da_sclk, ad_sclk} = {2{sclk}};
  assign {da_lrck, ad_lrck} = {2{lrck}};
  assign led_g = ~voiced;
  assign led_r = 1'b1;
endmodule
