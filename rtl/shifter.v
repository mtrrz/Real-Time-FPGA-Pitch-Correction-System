// Variable-ratio pitch shifter: dual-head delay line, linear interpolation, triangular crossfade.
// Each frame the delay p (Q.F samples) changes by step_i while the write pointer advances by 1,
// so the read heads move at ratio = 1 - step/2^F. Head 2 sits W/2 away (top bit of p flipped);
// tri(p)+tri(p+W/2) = W/2, so the crossfade gain is constant. Latency = p, 0..W samples (avg W/2).
// ~35 clocks per frame; valid_i must be at least that far apart.
// shortcut: crossfade weight uses the integer part of p only (gain steps 1/512 per sample), and
// ratios must stay below 2 (step > -2^F) or the head would run into unwritten history.
module shifter #(parameter AW = 10, F = 10) (
  input  wire               clk_i,
  input  wire               valid_i,
  input  wire signed [15:0] x_i,
  input  wire signed [15:0] step_i,        // Q.F; -1024 = x2, 0 = x1, +256 = x0.75
  output reg  signed [15:0] y_o
);
  localparam W = 1 << AW, PW = AW + F;
  localparam IDLE = 0, P0 = 1, P1 = 2, P2 = 3, P3 = 4, P4 = 5, P5 = 6, P6 = 7,
             P7 = 8, P8 = 9, P9 = 10, P10 = 11, P11 = 12;

  reg signed [15:0] mem [0:W-1];
  integer j;
  initial for (j = 0; j < W; j = j + 1) mem[j] = 0;

  reg [AW-1:0] wr = 0, ra = 0, ta = 0, pi = 0, wt = 0;
  reg [F-1:0]  fr = 0;
  reg [PW-1:0] p = 0, pc = 0;
  reg signed [15:0] rd = 0, y1 = 0, y0 = 0, v1 = 0, v2 = 0;
  reg signed [16:0] dif = 0;
  reg signed [F+17:0] pm = 0;
  reg signed [AW:0] g1 = 0, g2 = 0;
  reg signed [AW+16:0] m1 = 0, m2 = 0;
  reg h = 0;
  reg [3:0] st = IDLE;

  wire [PW-1:0] p2 = {~p[PW-1], p[PW-2:0]};
  wire signed [F+17:0] pms = pm >>> F;

  always @(posedge clk_i) begin
    rd <= mem[ra];
    if (valid_i) mem[wr] <= x_i;
    case (st)
      IDLE: if (valid_i) begin h <= 0; st <= P0; end
      P0:  begin pc <= h ? p2 : p;                         st <= P1; end
      P1:  begin pi <= pc[PW-1:F]; fr <= pc[F-1:0];       st <= P2; end
      P2:  begin ta <= wr - pi; wt <= pi[AW-1] ? -pi : pi; st <= P3; end
      P3:  begin ra <= ta; ta <= ta - 1'b1;                st <= P4; end    // newer sample (y1)
      P4:  begin ra <= ta;                                 st <= P5; end    // older sample (y0)
      P5:  begin y1 <= rd;                                 st <= P6; end
      P6:  begin y0 <= rd;                                 st <= P7; end
      P7:  begin dif <= y1 - y0;                           st <= P8; end
      P8:  begin pm <= dif * $signed({1'b0, fr});          st <= P9; end
      P9:  begin
        if (h) begin v2 <= y1 - $signed(pms[16:0]); g2 <= {1'b0, wt}; st <= P10; end
        else   begin v1 <= y1 - $signed(pms[16:0]); g1 <= {1'b0, wt}; h <= 1; st <= P0; end
      end
      P10: begin m1 <= v1 * g1; m2 <= v2 * g2;             st <= P11; end
      P11: begin
        y_o <= (m1 + m2) >>> (AW - 1);
        wr  <= wr + 1'b1;
        p   <= p + {{(PW-16){step_i[15]}}, step_i};
        st  <= IDLE;
      end
      default: st <= IDLE;
    endcase
  end
endmodule
