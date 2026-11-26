# Credits

The voice changer core has no external dependency: everything it needs is in this folder as our own source.

| Our file | Derived from | Version | License |
| --- | --- | --- | --- |
| `Sources/NovagramVoiceDSP/NovagramPitchShift.c`, `NovagramPitchShift.h` | Sonic library by Bill Cox, https://github.com/waywardgeek/sonic | commit `b93885dcb70aae50c6f76b0fe4e0868f029a077e` | Apache License 2.0 (`LICENSE-Sonic-Apache-2.0.txt`) |
| `Sources/NovagramVoiceDSP/NovagramVoiceDSP.c` (Freeverb part) | Freeverb by Jezar at Dreampoint | original tunings | Public domain |

Changes to Sonic: trimmed to 16-bit sample streams (no float or unsigned char I/O, spectrogram, static-memory mode,
user data or getters) and the public names renamed to `nv_sonic_*`; the algorithm is unchanged. The original
copyright and license notice is kept at the top of both files.

The presets and the rest of `NovagramVoiceDSP.c` are a port of the Novagram Android app's voice changer
(`org/fenixuz/voice/VoiceEffect.kt`, `CallVoiceChanger.kt`).
