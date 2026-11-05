import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from autotune import FS, amdf_pitch, snap_ratio, autotune

t = np.arange(FS) / FS
sine = lambda f: 0.5 * np.sin(2 * np.pi * f * t)

# detector: within 1% on a few pitches
for f in (110, 225, 330, 440):
    got = amdf_pitch(sine(f)[:2048])
    assert got and abs(got / f - 1) < 0.01, (f, got)

# silence is unvoiced -> ratio 1
assert snap_ratio(amdf_pitch(np.zeros(2048))) == 1.0

# 225 Hz is ~39 cents sharp of A3 (220): output must land on 220 Hz
out = autotune(sine(225))
got = amdf_pitch(out[8000:8000 + 2048])
assert got and abs(got / 220 - 1) < 0.015, got

print("PASS: detector, silence, autotune 225 Hz ->", round(got, 1), "Hz")
