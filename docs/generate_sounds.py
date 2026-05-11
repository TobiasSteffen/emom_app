#!/usr/bin/env python3
"""
Generiert die Alarm-Sounds für die EMOM App.
Ausgabe: assets/sounds/alarm_low.wav  (tieffrequente Variante, 440 Hz)

Das Original alarm.wav (880 Hz) wird NICHT überschrieben — es dient als Referenz
und wurde nach dem gleichen Schema generiert (Aufruf: make_alarm(880, ...)).

Ausführen aus dem Projektroot:
    python docs/generate_sounds.py

Abhängigkeiten: nur Python-Stdlib (struct, math, os) – keine externen Pakete nötig.

---

Klangdesign – Alarm-Beep-Muster:
  3 Gruppen à 2 Beeps, jeweils mit kurzem Intra-Gruppen-Abstand.
  Am Ende ~500 ms Stille, damit die Schleife (onPlayerComplete) nicht abbricht.

  Zeitstruktur (Beispiel für alarm.wav / 880 Hz):
    [Beep ~180 ms] [40 ms Stille] [Beep ~180 ms]  →  Gruppe 1
    [400 ms Stille]
    [Beep ~180 ms] [40 ms Stille] [Beep ~180 ms]  →  Gruppe 2
    [400 ms Stille]
    [Beep ~180 ms] [40 ms Stille] [Beep ~180 ms]  →  Gruppe 3
    [~500 ms Stille]  (Loop-Puffer – im Code zusätzlich 800 ms Pause via Future.delayed)

  Jeder Beep:
    - Sinuswelle mit der angegebenen Grundfrequenz
    - Zusätzlich 2. Oberton (halbe Amplitude) für wärmeren Klang
    - Hüllkurve: 10 ms Attack, 50 ms Decay am Ende des Beeps
    - Amplitudenramp: Lautstärke steigt innerhalb der Gruppe leicht an

Frequenzparameter:
  alarm.wav     : 880 Hz  (A5 – scharf, durchdringend)
  alarm_low.wav : 440 Hz  (A4 – eine Oktave tiefer, angenehmer)
"""

import struct, math, os

SAMPLE_RATE = 44100
MAX_AMP = 26000  # knapp unter 32767 (16-bit PCM max), um Clipping zu vermeiden


def make_wav_bytes(samples: list[int]) -> bytes:
    """Packt Samples (Liste von int16) in einen vollständigen WAV-Bytestring."""
    n = len(samples)
    data = struct.pack(f'<{n}h', *samples)
    header = struct.pack(
        '<4sI4s4sIHHIIHH4sI',
        b'RIFF', 36 + len(data),
        b'WAVE',
        b'fmt ', 16,
        1,           # PCM
        1,           # Mono
        SAMPLE_RATE,
        SAMPLE_RATE * 2,   # ByteRate = SampleRate × BlockAlign
        2,           # BlockAlign = Channels × BitsPerSample/8
        16,          # BitsPerSample
        b'data', len(data),
    )
    return header + data


def sine_beep(freq: float, duration_s: float, amp: float) -> list[int]:
    """
    Erzeugt einen einzelnen Beep als Sinuswelle.
    Grundton (freq) + 1. Oberton (0.5 × freq × 2) für Charakter.
    Hüllkurve: 10 ms Attack, 50 ms Decay.
    """
    n = int(duration_s * SAMPLE_RATE)
    attack = int(0.010 * SAMPLE_RATE)   # 10 ms
    decay  = int(0.050 * SAMPLE_RATE)   # 50 ms

    result = []
    for i in range(n):
        t = i / SAMPLE_RATE
        wave = 0.75 * math.sin(2 * math.pi * freq * t)
        wave += 0.25 * math.sin(2 * math.pi * freq * 2 * t)   # 1. Oberton

        # Hüllkurve
        if i < attack:
            env = i / attack
        elif i > n - decay:
            env = (n - i) / decay
        else:
            env = 1.0

        result.append(int(wave * env * amp))
    return result


def silence(duration_s: float) -> list[int]:
    return [0] * int(duration_s * SAMPLE_RATE)


def make_alarm(
    freq: float,
    beep_dur: float = 0.180,
    beep_gap: float = 0.040,
    group_gap: float = 0.400,
    groups: int = 3,
    end_silence: float = 0.500,
) -> list[int]:
    """
    Baut das vollständige Alarm-Muster aus Beep-Gruppen zusammen.

    Standardwerte reproduzieren das Muster von alarm.wav (880 Hz).
    alarm_low.wav nutzt 440 Hz, alle anderen Parameter identisch.
    """
    samples: list[int] = []
    for g in range(groups):
        # Amplitude steigt innerhalb der Gruppe leicht an (1. Beep etwas leiser)
        for b in range(2):
            amp = MAX_AMP * (0.85 + 0.15 * b)
            samples += sine_beep(freq, beep_dur, amp)
            if b == 0:
                samples += silence(beep_gap)
        if g < groups - 1:
            samples += silence(group_gap)
    samples += silence(end_silence)
    return samples


BASE = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
os.makedirs(BASE, exist_ok=True)

# alarm_low.wav – tieffrequente Variante (440 Hz, A4)
samples_low = make_alarm(freq=440)
path_low = os.path.join(BASE, 'alarm_low.wav')
with open(path_low, 'wb') as f:
    f.write(make_wav_bytes(samples_low))
print(f'Erstellt: {path_low}  ({len(samples_low)/SAMPLE_RATE:.2f} s, 440 Hz)')

# Hinweis: alarm.wav (880 Hz) kann mit dem folgenden Aufruf neu generiert werden:
#   samples_high = make_alarm(freq=880)
#   with open(os.path.join(BASE, 'alarm.wav'), 'wb') as f:
#       f.write(make_wav_bytes(samples_high))
print('Fertig. alarm.wav (880 Hz) wurde NICHT überschrieben.')
