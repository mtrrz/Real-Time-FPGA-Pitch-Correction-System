"""End to end on the integer models: sine -> amdf_fixed -> quant_fixed. Output pitch must land on the
nearest semitone."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from amdf_fixed import amdf_fixed, N
from quant_fixed import quant_fixed, FS_D, M0

worst = 0.0
for f in (90, 110, 130, 150, 170, 200, 225, 250, 275, 300, 330, 370, 410, 470, 520, 600, 700):
    x = np.round(1500 * np.sin(2 * np.pi * f * np.arange(N) / FS_D)).astype(int)
    voiced, sel, step = quant_fixed(*amdf_fixed(x))
    assert voiced, f
    midi = 69 + 12 * np.log2(f / 440)
    assert abs(M0 + sel - midi) < 0.6, (f, sel, midi)
    target = 440 * 2 ** ((M0 + sel - 69) / 12)
    cents = 1200 * np.log2(f * (1024 - step) / 1024 / target)
    worst = max(worst, abs(cents))
    assert abs(cents) < 12, (f, cents)

assert quant_fixed(*amdf_fixed(np.zeros(N, int)))[0] == 0
print(f"PASS: quantizer lands within {worst:.1f} cents of the target semitone")
