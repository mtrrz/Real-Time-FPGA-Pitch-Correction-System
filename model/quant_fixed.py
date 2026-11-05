"""Integer quantizer: the exact spec rtl/quant.v must match.
Input: AMDF lag and the AMDF values at lag-1, lag, lag+1 (from amdf_fixed).
1. parabolic refinement of the period to 1/16 sample (division by <=8 repeated subtractions)
2. snap to the nearest semitone by comparing against a table of period boundaries (no logs)
3. ratio = P / T_target as a multiply by a reciprocal table (no divider)
Output: (voiced, semitone index n = MIDI-36, step) where step = (1 - ratio) in Q.10 for the shifter."""
import os

FS_D = 25.5e6 / 512 / 3            # detector sample rate: PLL clock / LRCK divider / decimation
M0, NN = 36, 49                    # MIDI 36 (65 Hz) .. 84 (1047 Hz)


def tables():
    bq, rr = [], []
    for m in range(M0, M0 + NN):
        T = FS_D / (440 * 2 ** ((m - 69) / 12))        # target period in samples
        bq.append(round(16 * T * 2 ** (1 / 24)))       # longest period (Q.4) that still maps to this semitone
        rr.append(round(2 ** 20 / T))                  # 1/T in Q.20
    return bq, rr


BQ, RR = tables()
assert all(a > b for a, b in zip(BQ, BQ[1:])) and max(BQ) < 8192 and max(RR) < 1 << 17


def quant_fixed(lag, a, b, c):
    if lag == 0:
        return 0, 0, 0
    den, num, q = a + c - 2 * b, abs(a - c) * 8, 0     # |a-c| <= den, so q <= 8
    while den and num >= den and q < 8:
        num -= den
        q += 1
    P = lag * 16 + (-q if a < c else q)                # period, Q.4
    sel = 0
    for n in range(NN):
        if P <= BQ[n]:
            sel = n                                    # last (shortest-period) semitone not above P
    return 1, sel, 1024 - ((P * RR[sel]) >> 14)


if __name__ == "__main__":
    rtl = os.path.join(os.path.dirname(__file__), "..", "rtl")
    open(os.path.join(rtl, "bq.hex"), "w").write("".join(f"{v:04x}\n" for v in BQ))
    open(os.path.join(rtl, "rr.hex"), "w").write("".join(f"{v:05x}\n" for v in RR))
