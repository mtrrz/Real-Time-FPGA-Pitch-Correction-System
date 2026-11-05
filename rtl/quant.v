// Quantizer, bit-exact with model/quant_fixed.py. Tables come from model/quant_fixed.py (rtl/bq.hex, rr.hex).
// Refine the period, snap to a semitone, ratio = P * (1/T) with a serial multiplier (no divider, no DSP).
module quant (
  input  wire               clk_i,
  input  wire               start_i,
  input  wire [8:0]         lag_i,                 // 0 = unvoiced
  input  wire [19:0]        dm_i, d0_i, dp_i,
  output reg                done_o,                // 1-clk pulse
  output reg                voiced_o,
  output reg  [5:0]         sel_o,                 // semitone index, MIDI = 36 + sel
  output reg  signed [15:0] step_o                 // (1 - ratio) in Q.10
);
  localparam NN = 49;
  localparam IDLE = 0, DIV = 1, PQ = 2, S0 = 3, S1 = 4, MR0 = 5, MR1 = 6, MUL = 7, FIN = 8;

  reg [12:0] bq [0:NN-1];
  reg [16:0] rr [0:NN-1];
  initial begin $readmemh("rtl/bq.hex", bq); $readmemh("rtl/rr.hex", rr); end

  reg [3:0]  st = IDLE;
  reg [8:0]  lag = 0;
  reg [23:0] num = 0;
  reg [21:0] den = 0;
  reg [3:0]  q = 0;
  reg        neg = 0;
  reg [12:0] P = 0, bqr = 0;
  reg [16:0] rrr = 0, b_s = 0;
  reg [5:0]  n = 0;
  reg [4:0]  cnt = 0;
  reg [31:0] a_s = 0, prod = 0;

  wire [20:0] amc = {1'b0, dm_i} - {1'b0, dp_i};
  wire signed [17:0] rq = prod[31:14];

  always @(posedge clk_i) begin
    bqr <= bq[n];
    rrr <= rr[sel_o];
    done_o <= 1'b0;
    case (st)
      IDLE: if (start_i) begin
        lag <= lag_i;
        if (lag_i == 0) begin voiced_o <= 0; sel_o <= 0; step_o <= 0; done_o <= 1'b1; end
        else begin
          neg <= amc[20];
          num <= (amc[20] ? -amc : amc) << 3;
          den <= dm_i + dp_i - {d0_i, 1'b0};
          q <= 0; st <= DIV;
        end
      end
      DIV: if (den != 0 && num >= den && q < 8) begin num <= num - den; q <= q + 1'b1; end
           else st <= PQ;
      PQ: begin
        P <= neg ? {lag, 4'b0} - q : {lag, 4'b0} + q;
        n <= 0; sel_o <= 0; st <= S0;
      end
      S0: st <= S1;                                // wait for bq[n]
      S1: begin
        if (P <= bqr) sel_o <= n;
        if (n == NN - 1) st <= MR0; else begin n <= n + 1'b1; st <= S0; end
      end
      MR0: st <= MR1;                              // wait for rr[sel]
      MR1: begin a_s <= P; b_s <= rrr; prod <= 0; cnt <= 0; st <= MUL; end
      MUL: begin
        if (b_s[0]) prod <= prod + a_s;
        a_s <= a_s << 1; b_s <= b_s >> 1; cnt <= cnt + 1'b1;
        if (cnt == 16) st <= FIN;
      end
      FIN: begin
        step_o <= 18'sd1024 - rq;
        voiced_o <= 1'b1; done_o <= 1'b1; st <= IDLE;
      end
      default: st <= IDLE;
    endcase
  end
endmodule
