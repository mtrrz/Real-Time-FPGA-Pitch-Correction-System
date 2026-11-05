// Fixed +1 octave shifter: dual-head delay line, triangular crossfade.
// Each frame the read delay p shrinks by 1 sample while the write pointer grows by 1, so the heads
// read the history at 2x speed = ratio 2. Head 2 sits W/2 away; tri(p)+tri(p+W/2) = W/2 so the
// crossfade gain is constant. Latency = 1..W samples (avg W/2), ~10 ms at W=1024, 49.8 kHz.
// shortcut: integer-sample ratio 2 only; arbitrary ratios need a fractional p and interpolation.
module shifter #(parameter AW = 10) (
  input  wire               clk_i,
  input  wire               valid_i,   // one pulse per sample, at least 6 clks apart
  input  wire signed [15:0] x_i,
  output reg  signed [15:0] y_o
);
  localparam W = 1 << AW;

  reg signed [15:0] mem [0:W-1];
  reg [AW-1:0] wr = 0, p = 0, ra = 0, r1 = 0;   // r1 = wr - p, kept as a register (timing)
  reg signed [15:0] rd = 0, s1 = 0, s2 = 0;
  reg [2:0] st = 0;                      // 0 = idle

  wire [AW-1:0] r2 = {~r1[AW-1], r1[AW-2:0]};   // + W/2
  wire [AW-1:0] p2 = {~p[AW-1],  p[AW-2:0]};
  wire [AW-1:0] w1 = p[AW-1]  ? -p  : p;   // tri(p), 0..W/2
  wire [AW-1:0] w2 = p2[AW-1] ? -p2 : p2;
  reg  signed [AW:0] g1 = 0, g2 = 0;
  reg signed [AW+16:0] m1 = 0, m2 = 0;   // registered products, keeps the multiplier under the 25.5 MHz clock

  always @(posedge clk_i) begin
    rd <= mem[ra];
    if (valid_i) mem[wr] <= x_i;
    case (st)
      0: if (valid_i) begin ra <= r1;      st <= 1; end
      1: begin             ra <= r2;      st <= 2; end
      2: begin s1 <= rd; g1 <= {1'b0, w1}; g2 <= {1'b0, w2}; st <= 3; end
      3: begin             s2 <= rd;      st <= 4; end
      4: begin m1 <= s1 * g1; m2 <= s2 * g2; st <= 5; end
      5: begin
        y_o <= (m1 + m2) >>> (AW - 1);
        wr  <= wr + 1'b1;
        p   <= p - 1'b1;
        r1  <= r1 + 2'd2;
        st  <= 0;
      end
      default: st <= 0;
    endcase
  end
endmodule
