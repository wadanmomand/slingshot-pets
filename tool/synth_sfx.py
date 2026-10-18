#!/usr/bin/env python3
"""Synthesize SFX WAVs for Pawzzle Smash (44.1kHz mono 16-bit). No licensing issues."""
import numpy as np
import os

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')
os.makedirs(OUT, exist_ok=True)

def write(name, data):
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype(np.int16)
    import wave
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print('wrote', name, f'{len(data)/SR:.2f}s')

def env(n, attack=0.005, decay=None):
    t = np.arange(n) / SR
    a = np.minimum(1, t / attack)
    d = np.exp(-t / (decay or (n / SR / 3)))
    return a * d

def whoosh(dur=0.35):
    n = int(SR * dur)
    noise = np.random.randn(n)
    # rising band-passed sweep feel: amplitude swell + simple lowpass via cumsum smoothing
    k = np.ones(64) / 64
    smooth = np.convolve(noise, k, mode='same')
    swell = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return smooth * swell * 1.6

def crack(dur=0.18):
    n = int(SR * dur)
    noise = np.random.randn(n) * env(n, attack=0.002, decay=0.03)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * 120 * t) * np.exp(-t / 0.02) * 0.7
    return noise * 0.9 + thump

def shatter(dur=0.35):
    n = int(SR * dur)
    t = np.arange(n) / SR
    noise = np.random.randn(n)
    # crude highpass: subtract smoothed version
    k = np.ones(24) / 24
    hp = noise - np.convolve(noise, k, mode='same')
    out = hp * env(n, attack=0.002, decay=0.06) * 0.8
    for f in (2600, 3400, 4100, 5200):
        out += np.sin(2 * np.pi * f * t + np.random.rand() * 6) * np.exp(-t / 0.05) * 0.18
    return out

def cage_burst(dur=0.4):
    n = int(SR * dur)
    t = np.arange(n) / SR
    noise = np.random.randn(n) * env(n, attack=0.002, decay=0.05) * 0.5
    metal = np.sin(2 * np.pi * 740 * t) * np.exp(-t / 0.09) * 0.5
    metal += np.sin(2 * np.pi * 1180 * t) * np.exp(-t / 0.07) * 0.3
    thump = np.sin(2 * np.pi * 95 * t) * np.exp(-t / 0.03) * 0.6
    return noise + metal + thump

def cheer(dur=0.55):
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    notes = [523.25, 659.25, 783.99, 1046.5]  # C5 E5 G5 C6
    for i, f in enumerate(notes):
        s = int(i * SR * 0.11)
        e = min(n, s + int(SR * 0.22))
        tt = np.arange(e - s) / SR
        out[s:e] += np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.09) * 0.5
    return out

write('launch.wav', whoosh())
write('crack.wav', crack())
write('shatter.wav', shatter())
write('cage.wav', cage_burst())
write('cheer.wav', cheer())
print('done ->', OUT)
