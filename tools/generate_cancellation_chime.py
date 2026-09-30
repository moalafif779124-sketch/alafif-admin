#!/usr/bin/env python3
"""Generate the ALAFIF staff cancellation chime (assets/sounds/cancellation_alert.wav).

The chime must be *instantly* recognisable and different from a normal
notification: a descending two-tone "uh-oh" figure played twice, with a soft
attack/decay envelope so it never clicks. Run from the repo root:

    python3 tools/generate_cancellation_chime.py

Output: mono, 44.1 kHz, 16-bit PCM (≈1.2 s).
"""

import math
import struct
import wave
from pathlib import Path

RATE = 44_100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds" / "cancellation_alert.wav"


def tone(freq: float, ms: int, amp: float = 0.55) -> list[float]:
    """One enveloped note: short attack, exponential decay, 2nd harmonic."""
    n = int(RATE * ms / 1000)
    attack = max(1, int(RATE * 0.006))
    samples = []
    for i in range(n):
        t = i / RATE
        env = (i / attack) if i < attack else math.exp(-3.2 * (i - attack) / n)
        wave_ = math.sin(2 * math.pi * freq * t)
        wave_ += 0.28 * math.sin(2 * math.pi * freq * 2 * t)
        samples.append(amp * env * wave_)
    return samples


def silence(ms: int) -> list[float]:
    return [0.0] * int(RATE * ms / 1000)


def main() -> None:
    # Descending minor third = "something went wrong", played twice for urgency.
    body = (
        tone(988.0, 160)      # B5
        + tone(659.0, 260)    # E5
        + silence(90)
        + tone(988.0, 160)
        + tone(659.0, 320)
    )

    peak = max(abs(s) for s in body) or 1.0
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s / peak * 0.92)) * 32767))
        for s in body
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)

    print(f"✓ {OUT} — {len(frames)} bytes, {len(body) / RATE:.2f}s @ {RATE} Hz mono 16-bit")


if __name__ == "__main__":
    main()
