"""Write build/vec_in.hex (samples) and build/vec_exp.hex (lag,dm,d0,dp per hop) for tb/tb_amdf.v.
Also asserts the integer model finds the right pitch on each segment."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from amdf_fixed import amdf_fixed, N, HOP

NS = 5120                                  # keep in sync with tb_amdf.v
t = np.arange(NS)
rng = np.random.default_rng(1)
x = np.zeros(NS)
x[640:1920] = 1000 * np.sin(2 * np.pi * t[640:1920] / 73.8)
x[1920:3200] = 600 * np.sin(2 * np.pi * t[1920:3200] / 150)
v = sum(a * np.sin(2 * np.pi * h * t[3200:4480] / 55.3) for h, a in ((1, 700), (2, 420), (3, 280)))
x[3200:4480] = v + rng.normal(0, 20, 1280)
x[4480:] = rng.normal(0, 300, NS - 4480)
x = np.clip(np.round(x), -2048, 2047).astype(int)

pad = np.concatenate([np.zeros(N, int), x])
exp = [amdf_fixed(pad[(h + 1) * HOP:(h + 1) * HOP + N]) for h in range(NS // HOP)]

# (hop end index, expected period or None for unvoiced)
for end, per in ((640, None), (1280, 73.8), (1920, 73.8), (2560, 150), (3200, 150),
                 (3840, 55.3), (4480, 55.3), (5120, None)):
    lag = exp[end // HOP - 1][0]
    assert (lag == 0) if per is None else abs(lag - per) <= 1.5, (end, lag, per)

os.makedirs("build", exist_ok=True)
open("build/vec_in.hex", "w").write("".join(f"{s & 0xFFF:03x}\n" for s in x))
open("build/vec_exp.hex", "w").write("".join(f"{w:05x}\n" for e in exp for w in e))
print("lags per hop:", [e[0] for e in exp])
