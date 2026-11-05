// I2S master for the Digilent Pmod I2S2 (CS5343 ADC + CS4344 DAC), 16-bit samples in 24-bit slots.
// clk_i = 12 MHz. MCLK = clk (256*fs), SCLK = clk/4 (64*fs), LRCK = clk/256 -> fs = 46.875 kHz.
// All timing is derived from one counter, so everything stays in one clock domain (no CDC).
// Frame layout: cnt[7:2] = SCLK cycle b (0..63), cnt[7] = LRCK (0 = left). I2S data is delayed
// one SCLK after the LRCK edge, so bit k (k=1..16) of a slot is MSB-first at cycle k.
module i2s_core (
  input  wire        clk_i,
  input  wire [15:0] tx_l_i, tx_r_i,   // latched once per frame
  input  wire        sdout_i,          // from ADC
  output wire        mclk_o, sclk_o, lrck_o,
  output wire        sdin_o,           // to DAC
  output reg  [15:0] rx_l_o, rx_r_o,
  output reg         rx_valid_o        // 1 clk pulse once per frame, after the right sample
);
  reg [7:0] cnt = 0;
  always @(posedge clk_i) cnt <= cnt + 1'b1;

  assign mclk_o = clk_i;
  assign sclk_o = cnt[1];
  assign lrck_o = cnt[7];

  wire [5:0] b  = cnt[7:2];
  wire [5:0] nb = b + 1'b1;            // the SCLK cycle about to start
  wire [4:0] k  = nb[4:0];

  // TX: update on the SCLK falling edge (cnt[1:0]==3 -> next clk is cnt[1:0]==0)
  reg [15:0] l_r = 0, r_r = 0;
  reg        sdin_r = 0;
  wire [15:0] cur = nb[5] ? r_r : l_r;
  always @(posedge clk_i) if (cnt[1:0] == 2'b11) begin
    if (nb == 6'd0) begin l_r <= tx_l_i; r_r <= tx_r_i; end
    sdin_r <= (k >= 5'd1 && k <= 5'd16) ? cur[5'd16 - k] : 1'b0;
  end
  assign sdin_o = sdin_r;

  // RX: sample on the SCLK rising edge (cnt[1:0]==1 -> next clk is cnt[1:0]==2)
  // shortcut: sdout_i is sampled unsynchronised; it is launched by SCLK's falling edge so it is
  // stable by now, add a 2-flop synchroniser if the pin ever shows glitches.
  reg [15:0] sr = 0;
  wire [15:0] sr_next = {sr[14:0], sdout_i};
  always @(posedge clk_i) begin
    rx_valid_o <= 1'b0;
    if (cnt[1:0] == 2'b01 && b[4:0] >= 5'd1 && b[4:0] <= 5'd16) begin
      sr <= sr_next;
      if (b[4:0] == 5'd16) begin
        if (b[5]) begin rx_r_o <= sr_next; rx_valid_o <= 1'b1; end
        else            rx_l_o <= sr_next;
      end
    end
  end
endmodule
