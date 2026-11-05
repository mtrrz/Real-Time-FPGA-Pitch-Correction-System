"""Integer AMDF detector: the exact spec rtl/amdf.v must match (12-bit signed samples).
Window N=512 decimated samples (~16.6 kHz), lags LMIN..LMIN+255, M=237 terms per lag.
Returns (lag, d[lag-1], d[lag], d[lag+1]); lag 0 = unvoiced. The neighbours feed parabolic
refinement in the quantizer, so the detector itself stays integer-lag."""
import numpy as np

N, HOP, LMIN, LAGS, M = 512, 320, 20, 256, 237


def amdf_fixed(x):
    x = np.asarray(x, dtype=np.int64)
    assert len(x) == N
    d = np.array([np.abs(x[:M] - x[l:l + M]).sum() for l in range(LMIN, LMIN + LAGS)])
    dsum, dmin = int(d.sum()), int(d.min())
    dmean = dsum >> 8                                   # exactly 256 lags, so a shift is the mean
    if dsum < (1 << 19) or 2 * dmin > dmean:            # silence, or no clear minimum
        return 0, 0, 0, 0
    thr = dmin + ((dmean - dmin) >> 3)
    i = int(np.argmax(d <= thr))                        # first lag under threshold (avoids octave-down errors)
    while i + 1 < LAGS and d[i + 1] < d[i]:             # walk down to the local minimum
        i += 1
    return (LMIN + i, int(d[i - 1]) if i else int(d[i]), int(d[i]),
            int(d[i + 1]) if i + 1 < LAGS else int(d[i]))
