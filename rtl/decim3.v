// Decimate by 3 for the detector: sum of 3 samples (a crude low-pass), x4 gain, saturate to 12 bits.
// The x4 gain (>>>4 instead of >>>6) keeps quiet line-level audio above the detector's silence threshold.
module decim3 (
  input  wire               clk_i,
  input  wire               valid_i,
  input  wire signed [15:0] x_i,
  output reg                valid_o,
  output reg  signed [11:0] y_o
);
  reg [1:0] c = 0;
  reg signed [17:0] s = 0;
  wire signed [17:0] t  = s + x_i;
  wire signed [17:0] sh = t >>> 4;
  always @(posedge clk_i) begin
    valid_o <= 1'b0;
    if (valid_i) begin
      if (c == 2) begin
        y_o <= (sh > 18'sd2047) ? 12'sd2047 : (sh < -18'sd2048) ? -12'sd2048 : sh[11:0];
        valid_o <= 1'b1; c <= 0; s <= 0;
      end else begin c <= c + 1'b1; s <= t; end
    end
  end
endmodule
