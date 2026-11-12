// Novagram voice changer DSP: the same presets as the Android app (org.fenixuz.voice.VoiceEffect), in plain C with no
// platform dependencies, so the recorder (Swift), the call audio (C++) and tests share one implementation.
// 16-bit mono PCM only.
#ifndef NOVAGRAM_VOICE_DSP_H
#define NOVAGRAM_VOICE_DSP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Preset ids. They are stored in the settings, so never renumber them (same numbers as on Android).
#define NV_PRESET_OFF 0
#define NV_PRESET_CHILD 1
#define NV_PRESET_WOMAN 2
#define NV_PRESET_MAN 3
#define NV_PRESET_HELIUM 4
#define NV_PRESET_HEXAFLUORIDE 5
#define NV_PRESET_MONSTER 6
#define NV_PRESET_MOUSE 7
#define NV_PRESET_ROBOT 8
#define NV_PRESET_ALIEN 9
#define NV_PRESET_ECHO 10
#define NV_PRESET_CAVE 12
#define NV_PRESET_HOARSENESS 13
#define NV_PRESET_MODULATION 14
#define NV_PRESET_NOISE 15
// The four tape speeds, thickest first.
#define NV_PRESET_SPEED_VERY_THICK 16
#define NV_PRESET_SPEED_THICK 17
#define NV_PRESET_SPEED_THIN 18
#define NV_PRESET_SPEED_VERY_THIN 19

#define NV_TONE_MIN (-12)
#define NV_TONE_MAX 12
#define NV_STEP_MIN 1
#define NV_STEP_MAX 10

// What the user sets for Modulation (tone, semitones), Echo (delay in tenths of a second, volume in tenths) and Noise
// (volume in tenths).
typedef struct {
    int32_t tone;
    int32_t echoDelay;
    int32_t echoVolume;
    int32_t noiseVolume;
} NVParams;

// +5 semitones; an echo at 70% after 0.5 s; noise at 70%.
NVParams nv_params_default(void);

// Values clamped to their ranges.
NVParams nv_params_clamped(NVParams params);

// 1 for a known preset id (OFF included), else 0.
int nv_preset_is_known(int32_t presetId);
int nv_preset_is_speed(int32_t presetId);
int nv_preset_has_settings(int32_t presetId);

// The tape speed: above 1 the message gets shorter. 1 for every non-speed preset.
float nv_preset_rate(int32_t presetId);

typedef struct NVEffect NVEffect;

// A new effect, or NULL for OFF or an unknown id. One per recording, used from one thread.
NVEffect *nv_effect_create(int32_t presetId, NVParams params, int32_t sampleRate);
void nv_effect_destroy(NVEffect *effect);

// Runs `count` samples through the effect. The result may be longer or shorter than the input (the pitch shifter
// holds some samples back); `*output` points into the effect's own buffer, valid until the next call.
int32_t nv_effect_process(NVEffect *effect, const int16_t *input, int32_t count, const int16_t **output);

// What the effect still holds once the recording stops, with an echo or reverb fading out.
int32_t nv_effect_drain(NVEffect *effect, const int16_t **output);

// Calls. The choice is one atomic value: any thread may set it, the audio thread reads it every buffer, so a change
// during a call applies at once. presetId OFF (or a speed, which a live voice can't have) turns it off.
void nv_call_set_choice(int32_t presetId, NVParams params);

// Changes one microphone buffer in place (16-bit mono), on the call's recording thread. A small queue keeps every
// buffer at its own size. The state is global: there is one microphone, and only one recording thread uses it.
void nv_call_process_in_place(int16_t *samples, int32_t count, int32_t sampleRate);

// For the call path's per-buffer cost: 1 when a call effect is chosen.
int nv_call_is_on(void);

// The call hook in one line: returns `samples` itself when no effect is on or the format isn't 16-bit mono, else a
// changed copy (a buffer of the voice changer's, valid until the next call on the same thread).
const void *nv_call_process(const void *samples, size_t count, size_t bytesPerSample, size_t channels, uint32_t sampleRate);

#ifdef __cplusplus
}
#endif

#endif
