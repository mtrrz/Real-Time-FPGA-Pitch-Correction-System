"""Offline autotune reference model: AMDF detect -> snap to semitone -> dual-head delay-line shift.
Becomes the golden model for the RTL (swap float for fixed point once the algorithm is settled)."""
import numpy as np

FS = 16000
N = 512                 # analysis frame
LMIN, LMAX = 32, 256    # 500 Hz .. 62.5 Hz
W = 320                 # shifter delay span (20 ms)
HOP = 320               # re-detect every 20 ms


def amdf_pitch(x, fs=FS):
    """Return f0 in Hz, or None if unvoiced. x: at least N samples."""
    x = np.asarray(x[-N:], dtype=float)
    m = N - LMAX        # fixed term count so every lag is compared fairly
    d = np.array([np.mean(np.abs(x[:m] - x[l:l + m])) for l in range(LMIN, LMAX + 1)])
    if np.sqrt(np.mean(x ** 2)) < 0.01 or d.min() > 0.5 * d.mean():
        return None
    thr = d.min() + 0.1 * (d.mean() - d.min())
    i = int(np.argmax(d <= thr))                 # first lag under threshold (avoids octave-down errors)
    while i + 1 < len(d) and d[i + 1] < d[i]:    # walk to the local minimum
        i += 1
    if 0 < i < len(d) - 1:                       # parabolic refinement
        a, b, c = d[i - 1], d[i], d[i + 1]
        den = a - 2 * b + c
        if den != 0:
            lag = LMIN + i + 0.5 * (a - c) / den
            return fs / lag
    return fs / (LMIN + i)


def snap_ratio(f0):
    """Correction ratio to the nearest chromatic semitone (RTL will use a period LUT, no logs)."""
    if f0 is None:
        return 1.0
    midi = 69 + 12 * np.log2(f0 / 440.0)
    return 440.0 * 2 ** ((round(midi) - 69) / 12) / f0


def shift(x, ratios):
    """Dual-read-head delay line with triangular crossfade. ratios: per-sample array."""
    y = np.zeros(len(x))
    p = 0.0
    for n in range(len(x)):
        out = 0.0
        for off in (0.0, 0.5):
            q = (p + off) % 1.0
            pos = n - W * q
            if pos >= 0:
                i = int(pos)
                f = pos - i
                s = x[i] * (1 - f) + (x[i + 1] * f if i + 1 < len(x) else 0.0)
                out += (1 - abs(2 * q - 1)) * s
        y[n] = out
        p = (p + (1 - ratios[n]) / W) % 1.0
    return y


def autotune(x, strength=1.0):
    """strength 1 = instant snap (robotic), lower = slower glide toward the target."""
    ratios = np.ones(len(x))
    r = 1.0
    for s in range(0, len(x), HOP):
        seg = x[max(0, s + HOP - N):s + HOP]
        if len(seg) == N:
            r += strength * (snap_ratio(amdf_pitch(seg)) - r)
        ratios[s:s + HOP] = r
    return shift(np.asarray(x, dtype=float), ratios)
