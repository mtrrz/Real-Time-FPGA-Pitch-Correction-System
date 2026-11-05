// AMDF pitch detector, bit-exact with model/amdf_fixed.py. No multipliers.
// Samples arrive one per valid_i (12-bit, decimated ~16.6 kHz). Every HOP samples it scans all 256
// lags over the last 512 samples, then finds the first lag under a threshold and walks to its local minimum.
// Cost: 256 lags * 237 terms * 5 clks = ~303k clks per hop, hop = 320 samples = ~491k clks at 25.5 MHz.
// shortcut: a hop trigger while still busy is ignored (spacing between valid_i must keep HOP*spacing > 303k clks).
module amdf #(parameter HOP = 320, LMIN = 20, M = 237) (
  input  wire               clk_i,
  input  wire               valid_i,
  input  wire signed [11:0] x_i,
  output reg                done_o,                  // 1-clk pulse when the result below is valid
  output reg  [8:0]         lag_o,                   // 0 = unvoiced
  output reg  [19:0]        dm_o, d0_o, dp_o         // AMDF at lag-1, lag, lag+1
);
  reg [11:0] xmem [0:1023];                          // 1024 deep: the 512-sample window survives ~512 new samples
  reg [19:0] dmem [0:255];
  integer j;
  initial for (j = 0; j < 1024; j = j + 1) xmem[j] = 0;

  localparam IDLE = 0, SA = 1, SB = 2, LA = 3, AB = 4, AC = 5, EL = 6,
             TH1 = 7, TH2 = 8, W0 = 9, SC = 10, WT = 11, FIN = 12;

  reg [9:0]  wp = 0, base = 0, ra = 0;
  reg [7:0]  dra = 0, lg = 0, i = 0, k = 0, lagi = 0;
  reg [8:0]  hopc = 0;
  reg [11:0] rd = 0, a = 0, ad = 0;
  reg [19:0] dr = 0, acc = 0, dmin = 0, dmean = 0, thr = 0, prevd = 0;
  reg [27:0] dsum = 0;
  reg [3:0]  st = IDLE;
  reg        go = 0, unv = 0, found = 0, hit = 0;

  wire signed [12:0] diff = $signed(a) - $signed(rd);
  wire [11:0] adw = diff[12] ? -diff[11:0] : diff[11:0];

  always @(posedge clk_i) begin
    rd <= xmem[ra];
    dr <= dmem[dra];
    done_o <= 1'b0;

    if (valid_i) begin
      xmem[wp] <= x_i;
      wp <= wp + 1'b1;
      if (hopc == HOP - 1) begin hopc <= 0; base <= wp + 10'd513; go <= 1'b1; end   // base = wp+1-512
      else hopc <= hopc + 1'b1;
    end

    case (st)
      IDLE: if (go) begin
        go <= 1'b0; st <= SA; lg <= 0; i <= 0; acc <= 0; dmin <= 20'hFFFFF; dsum <= 0;
      end
      // pass 1: d[lg] = sum_i |x[i] - x[i+lag]|
      SA: begin ra <= base + i;                   st <= SB; end
      SB: begin ra <= base + i + LMIN + lg;       st <= LA; end
      LA: begin a <= rd;                          st <= AB; end
      AB: begin ad <= adw;                        st <= AC; end
      AC: begin
        acc <= acc + ad;
        if (i == M - 1) st <= EL; else begin i <= i + 1'b1; st <= SA; end
      end
      EL: begin
        dmem[lg] <= acc;
        if (acc < dmin) dmin <= acc;
        dsum <= dsum + acc;
        if (lg == 255) st <= TH1;
        else begin lg <= lg + 1'b1; i <= 0; acc <= 0; st <= SA; end
      end
      // threshold and voicing decision
      TH1: begin dmean <= dsum[27:8]; st <= TH2; end
      TH2: begin
        thr <= dmin + ((dmean - dmin) >> 3);
        unv <= (dsum < 28'd524288) || ({dmin, 1'b0} > dmean);
        dra <= 0; k <= 0; found <= 0; hit <= 0; st <= W0;
      end
      W0: if (unv) begin
        lag_o <= 0; dm_o <= 0; d0_o <= 0; dp_o <= 0; done_o <= 1'b1; st <= IDLE;
      end else st <= SC;
      // pass 2: scan d[] for the first value <= thr, then walk down to the local minimum
      SC: begin
        prevd <= dr;
        if (!found) begin
          if (dr <= thr) begin found <= 1'b1; lagi <= k; d0_o <= dr; dm_o <= (k == 0) ? dr : prevd; end
        end else if (dr < d0_o) begin dm_o <= d0_o; d0_o <= dr; lagi <= k; end
        else begin dp_o <= dr; hit <= 1'b1; end
        if ((found && !(dr < d0_o)) || k == 255) st <= FIN;
        else begin k <= k + 1'b1; dra <= k + 1'b1; st <= WT; end
      end
      WT: st <= SC;
      FIN: begin
        lag_o <= LMIN + lagi;
        if (!hit) dp_o <= d0_o;
        done_o <= 1'b1; st <= IDLE;
      end
      default: st <= IDLE;
    endcase
  end
endmodule
