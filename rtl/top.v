// Phase 1: audio passthrough. Pmod I2S2 on PMOD1A (12-pin), left input -> both outputs.
module top (
  input  wire clk,
  output wire da_mclk, da_lrck, da_sclk, da_sdin,
  output wire ad_mclk, ad_lrck, ad_sclk,
  input  wire ad_sdout,
  output wire led_r, led_g   // active low on the iCEBreaker
);
  wire mclk, sclk, lrck;
  wire [15:0] l;

  i2s_core i2s (
    .clk_i(clk), .tx_l_i(l), .tx_r_i(l), .sdout_i(ad_sdout),
    .mclk_o(mclk), .sclk_o(sclk), .lrck_o(lrck), .sdin_o(da_sdin),
    .rx_l_o(l), .rx_r_o(), .rx_valid_o()
  );

  assign {da_mclk, ad_mclk} = {2{mclk}};
  assign {da_sclk, ad_sclk} = {2{sclk}};
  assign {da_lrck, ad_lrck} = {2{lrck}};

  // green LED = input signal present (top 8 bits not all-equal), red off
  assign led_g = ~(l[15:8] != 8'h00 && l[15:8] != 8'hff);
  assign led_r = 1'b1;
endmodule
