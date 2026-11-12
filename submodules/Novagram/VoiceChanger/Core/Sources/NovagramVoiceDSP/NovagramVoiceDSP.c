// Novagram voice changer DSP, ported from the Android app's VoiceEffect.kt / CallVoiceChanger.kt so both platforms
// sound the same. The pitch shift and tape speed are NovagramPitchShift.c, derived from Sonic (Apache 2.0, CREDITS.md).
#include "NovagramVoiceDSP/NovagramVoiceDSP.h"

#include <math.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

#include "NovagramPitchShift.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// MARK: - Presets

typedef struct {
    int32_t id;
    float semitones;
    // Where the formants end up, in semitones; hasFormant 0 leaves them moving with the pitch (the cartoon voice).
    int hasFormant;
    float formant;
    float rate;
    float robotHz;
    float ringHz;
    float ringMix;
    float echoMs;
    float echoFeedback;
    float echoMix;
    float reverbMix;
    float reverbRoom;
    float reverbDamp;
    float reverbPreDelayMs;
    float drive;
    float whisper;
    float roughness;
    float noise;
    float gain;
} NVPreset;

static NVPreset nv_preset_base(int32_t id) {
    NVPreset p;
    memset(&p, 0, sizeof(p));
    p.id = id;
    p.rate = 1.0f;
    p.reverbRoom = 0.5f;
    p.reverbDamp = 0.5f;
    p.gain = 1.0f;
    return p;
}

NVParams nv_params_default(void) {
    NVParams params = { 5, 5, 7, 7 };
    return params;
}

static int32_t nv_clamp_int(int32_t value, int32_t low, int32_t high) {
    return value < low ? low : (value > high ? high : value);
}

NVParams nv_params_clamped(NVParams params) {
    params.tone = nv_clamp_int(params.tone, NV_TONE_MIN, NV_TONE_MAX);
    params.echoDelay = nv_clamp_int(params.echoDelay, NV_STEP_MIN, NV_STEP_MAX);
    params.echoVolume = nv_clamp_int(params.echoVolume, NV_STEP_MIN, NV_STEP_MAX);
    params.noiseVolume = nv_clamp_int(params.noiseVolume, NV_STEP_MIN, NV_STEP_MAX);
    return params;
}

int nv_preset_is_speed(int32_t presetId) {
    return presetId >= NV_PRESET_SPEED_VERY_THICK && presetId <= NV_PRESET_SPEED_VERY_THIN;
}

int nv_preset_is_known(int32_t presetId) {
    return (presetId >= NV_PRESET_OFF && presetId <= NV_PRESET_SPEED_VERY_THIN && presetId != 11);
}

int nv_preset_has_settings(int32_t presetId) {
    return presetId == NV_PRESET_MODULATION || presetId == NV_PRESET_ECHO || presetId == NV_PRESET_NOISE;
}

float nv_preset_rate(int32_t presetId) {
    switch (presetId) {
        case NV_PRESET_SPEED_VERY_THICK: return 0.7f;
        case NV_PRESET_SPEED_THICK: return 0.85f;
        case NV_PRESET_SPEED_THIN: return 1.25f;
        case NV_PRESET_SPEED_VERY_THIN: return 1.5f;
        default: return 1.0f;
    }
}

// The preset with the user's settings applied (VoicePreset.ROWS + VoicePreset.with on Android).
static NVPreset nv_preset_resolve(int32_t id, NVParams params) {
    params = nv_params_clamped(params);
    NVPreset p = nv_preset_base(id);
    switch (id) {
        case NV_PRESET_ROBOT:
            p.robotHz = 120.0f; p.gain = 1.15f;
            break;
        case NV_PRESET_ALIEN:
            p.semitones = 4.0f; p.ringHz = 140.0f; p.ringMix = 0.6f; p.gain = 1.6f;
            break;
        case NV_PRESET_HOARSENESS:
            p.whisper = 0.5f; p.roughness = 0.15f; p.drive = 1.3f;
            break;
        case NV_PRESET_MODULATION:
            // The formants go half as far as the pitch; at 0 the voice passes as it is.
            if (params.tone != 0) {
                p.semitones = (float)params.tone;
                p.hasFormant = 1;
                p.formant = params.tone / 2.0f;
            }
            break;
        case NV_PRESET_CHILD:
            p.semitones = 12.0f; p.hasFormant = 1; p.formant = 5.5f; p.gain = 1.1f;
            break;
        case NV_PRESET_MOUSE:
            p.semitones = 14.0f;
            break;
        case NV_PRESET_MAN:
            p.semitones = -6.0f; p.hasFormant = 1; p.formant = -3.0f;
            break;
        case NV_PRESET_WOMAN:
            p.semitones = 9.0f; p.hasFormant = 1; p.formant = 3.5f; p.gain = 1.1f;
            break;
        case NV_PRESET_MONSTER:
            p.semitones = -8.0f; p.hasFormant = 1; p.formant = -5.0f; p.drive = 2.5f; p.ringHz = 30.0f; p.ringMix = 0.25f;
            p.gain = 0.54f;
            break;
        case NV_PRESET_ECHO: {
            float volume = params.echoVolume / 10.0f;
            float mix = volume * 0.8f;
            p.echoMs = params.echoDelay * 100.0f;
            p.echoMix = mix;
            p.echoFeedback = 0.25f + 0.3f * volume;
            p.gain = 1.0f / (1.0f + 0.35f * mix);
            break;
        }
        case NV_PRESET_NOISE:
            p.noise = 0.03f * params.noiseVolume / 10.0f;
            break;
        case NV_PRESET_HELIUM:
            // As in the real gas, mostly the formants go up, the pitch only a little.
            p.semitones = 3.0f; p.hasFormant = 1; p.formant = 9.0f; p.gain = 0.95f;
            break;
        case NV_PRESET_HEXAFLUORIDE:
            p.semitones = -3.0f; p.hasFormant = 1; p.formant = -7.0f; p.gain = 1.08f;
            break;
        case NV_PRESET_CAVE:
            p.reverbMix = 0.3f; p.reverbRoom = 0.7f; p.reverbDamp = 0.3f; p.reverbPreDelayMs = 35.0f;
            break;
        default:
            if (nv_preset_is_speed(id)) {
                p.rate = nv_preset_rate(id);
            }
            break;
    }
    return p;
}

// MARK: - Small helpers

// The next xorshift state; as a signed int over 2^31 it is white noise in -1..1.
static int32_t nv_xorshift(int32_t seed) {
    uint32_t s = (uint32_t)seed;
    s ^= s << 13;
    s ^= s >> 17;
    s ^= s << 5;
    return (int32_t)s;
}

static float *nv_hann(int size) {
    float *window = (float *)malloc(sizeof(float) * size);
    for (int i = 0; i < size; i++) {
        window[i] = (float)(0.5 - 0.5 * cos(2.0 * M_PI * i / size));
    }
    return window;
}

static int16_t nv_to_short(float value) {
    // Same as Kotlin's toInt().toShort() for values already in range.
    int v = (int)value;
    if (v > 32767) v = 32767;
    if (v < -32768) v = -32768;
    return (int16_t)v;
}

// MARK: - FFT (in place, radix 2, inverse scaled by 1/size)

typedef struct {
    int size;
    float *cosTable;
    float *sinTable;
    int *reversed;
} NVFft;

static void nv_fft_init(NVFft *fft, int size) {
    fft->size = size;
    fft->cosTable = (float *)malloc(sizeof(float) * (size / 2));
    fft->sinTable = (float *)malloc(sizeof(float) * (size / 2));
    for (int i = 0; i < size / 2; i++) {
        fft->cosTable[i] = (float)cos(2.0 * M_PI * i / size);
        fft->sinTable[i] = (float)sin(2.0 * M_PI * i / size);
    }
    fft->reversed = (int *)calloc(size, sizeof(int));
    int j = 0;
    for (int i = 1; i < size; i++) {
        int bit = size >> 1;
        while (j & bit) {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;
        fft->reversed[i] = j;
    }
}

static void nv_fft_free(NVFft *fft) {
    free(fft->cosTable);
    free(fft->sinTable);
    free(fft->reversed);
}

static void nv_fft_transform(const NVFft *fft, float *re, float *im, int inverse) {
    int size = fft->size;
    for (int i = 0; i < size; i++) {
        int j = fft->reversed[i];
        if (i < j) {
            float t = re[i]; re[i] = re[j]; re[j] = t;
            t = im[i]; im[i] = im[j]; im[j] = t;
        }
    }
    for (int length = 2; length <= size; length <<= 1) {
        int half = length / 2;
        int step = size / length;
        for (int start = 0; start < size; start += length) {
            for (int k = 0; k < half; k++) {
                float wr = fft->cosTable[k * step];
                float wi = inverse ? fft->sinTable[k * step] : -fft->sinTable[k * step];
                int a = start + k;
                int b = a + half;
                float tr = re[b] * wr - im[b] * wi;
                float ti = re[b] * wi + im[b] * wr;
                re[b] = re[a] - tr;
                im[b] = im[a] - ti;
                re[a] += tr;
                im[a] += ti;
            }
        }
    }
    if (inverse) {
        float s = 1.0f / size;
        for (int i = 0; i < size; i++) {
            re[i] *= s;
            im[i] *= s;
        }
    }
}

// MARK: - Formant warp

// Moves the formants by `factor` along the frequency axis and leaves the pitch where it is: the spectral envelope comes
// from the cepstrum (quefrencies under 1.5 ms), and each frame is filtered by the warped envelope over its own.
// 75% overlapping Hann windows; the output lags the input by `size` samples.
#define NV_LIFTER_SECONDS 0.0015f
#define NV_LIFTER_TAPER 16
#define NV_MAX_LOG_GAIN 2.0794415f

typedef struct {
    float factor;
    int size, hop, half, lifter;
    float *window, *input, *output, *re, *im, *cepRe, *cepIm, *envelope;
    NVFft fft;
    int pos, sinceFrame;
    float scale;
} NVFormantWarp;

static NVFormantWarp *nv_warp_create(float factor, int sampleRate) {
    NVFormantWarp *w = (NVFormantWarp *)calloc(1, sizeof(NVFormantWarp));
    w->factor = factor;
    w->size = sampleRate > 32000 ? 2048 : 1024;
    w->hop = w->size / 4;
    w->half = w->size / 2;
    int lifter = (int)lroundf(sampleRate * NV_LIFTER_SECONDS);
    w->lifter = lifter > 8 ? lifter : 8;
    w->window = nv_hann(w->size);
    w->input = (float *)calloc(w->size, sizeof(float));
    w->output = (float *)calloc(w->size, sizeof(float));
    w->re = (float *)calloc(w->size, sizeof(float));
    w->im = (float *)calloc(w->size, sizeof(float));
    w->cepRe = (float *)calloc(w->size, sizeof(float));
    w->cepIm = (float *)calloc(w->size, sizeof(float));
    w->envelope = (float *)calloc(w->half + 1, sizeof(float));
    nv_fft_init(&w->fft, w->size);
    w->scale = w->hop / (0.375f * w->size);
    return w;
}

static void nv_warp_destroy(NVFormantWarp *w) {
    if (!w) return;
    free(w->window); free(w->input); free(w->output); free(w->re); free(w->im);
    free(w->cepRe); free(w->cepIm); free(w->envelope);
    nv_fft_free(&w->fft);
    free(w);
}

static void nv_warp_frame(NVFormantWarp *w) {
    int size = w->size, half = w->half;
    float *re = w->re, *im = w->im, *cr = w->cepRe, *ci = w->cepIm;
    for (int i = 0; i < size; i++) {
        re[i] = w->input[(w->pos + i) % size] * w->window[i];
        im[i] = 0.0f;
    }
    nv_fft_transform(&w->fft, re, im, 0);
    // The log magnitude, an even real sequence, through the inverse transform: the cepstrum.
    for (int k = 0; k <= half; k++) {
        float level = logf(hypotf(re[k], im[k]) + 1e-9f);
        cr[k] = level;
        ci[k] = 0.0f;
        if (k >= 1 && k < half) {
            cr[size - k] = level;
            ci[size - k] = 0.0f;
        }
    }
    nv_fft_transform(&w->fft, cr, ci, 1);
    for (int n = 0; n < size; n++) {
        int quefrency = n <= half ? n : size - n;
        float lift;
        if (quefrency < w->lifter) {
            lift = 1.0f;
        } else if (quefrency < w->lifter + NV_LIFTER_TAPER) {
            lift = (float)(0.5 + 0.5 * cos(M_PI * (quefrency - w->lifter) / NV_LIFTER_TAPER));
        } else {
            lift = 0.0f;
        }
        cr[n] *= lift;
        ci[n] = 0.0f;
    }
    nv_fft_transform(&w->fft, cr, ci, 0);
    for (int k = 0; k <= half; k++) {
        w->envelope[k] = cr[k];
    }
    for (int k = 0; k <= half; k++) {
        // The envelope `factor` times lower down lands here: above 1 the formants go up.
        float from = k / w->factor;
        int below = (int)from;
        float target = below >= half
            ? w->envelope[half]
            : w->envelope[below] + (w->envelope[below + 1] - w->envelope[below]) * (from - below);
        // Limited, so that a quiet valley or the noise between words isn't blown up.
        float logGain = target - w->envelope[k];
        if (logGain < -NV_MAX_LOG_GAIN) logGain = -NV_MAX_LOG_GAIN;
        if (logGain > NV_MAX_LOG_GAIN) logGain = NV_MAX_LOG_GAIN;
        float gain = expf(logGain);
        re[k] *= gain;
        im[k] *= gain;
        if (k >= 1 && k < half) {
            re[size - k] = re[k];
            im[size - k] = -im[k];
        }
    }
    nv_fft_transform(&w->fft, re, im, 1);
    for (int i = 0; i < size; i++) {
        w->output[(w->pos + i) % size] += re[i] * w->window[i] * w->scale;
    }
}

static float nv_warp_process(NVFormantWarp *w, float x) {
    w->input[w->pos] = x;
    float y = w->output[w->pos];
    w->output[w->pos] = 0.0f;
    w->pos = (w->pos + 1) % w->size;
    if (++w->sinceFrame == w->hop) {
        w->sinceFrame = 0;
        nv_warp_frame(w);
    }
    return y;
}

// MARK: - Spectral (robot and whisper)

// A robot keeps each frame's spectrum but drops its phases (a monotone pulse at the frame rate); a whisper randomizes
// them (breath that keeps its vowels). Output lags the input by `size` samples; dryDelayed is the input with that lag.
typedef struct {
    int robot;
    int size, hop;
    float *window, *input, *output, *re, *im;
    NVFft fft;
    int pos, sinceFrame;
    int32_t seed;
    float scale;
    float dryDelayed;
} NVSpectral;

static NVSpectral *nv_spectral_create(int robot, int size, int hop) {
    NVSpectral *s = (NVSpectral *)calloc(1, sizeof(NVSpectral));
    s->robot = robot;
    s->size = size;
    s->hop = hop < 1 ? 1 : hop;
    s->window = nv_hann(size);
    s->input = (float *)calloc(size, sizeof(float));
    s->output = (float *)calloc(size, sizeof(float));
    s->re = (float *)calloc(size, sizeof(float));
    s->im = (float *)calloc(size, sizeof(float));
    nv_fft_init(&s->fft, size);
    s->seed = 0x6C8E9CF5;
    s->scale = robot ? s->hop / (0.375f * size) : sqrtf(s->hop / (0.140625f * size));
    return s;
}

static void nv_spectral_destroy(NVSpectral *s) {
    if (!s) return;
    free(s->window); free(s->input); free(s->output); free(s->re); free(s->im);
    nv_fft_free(&s->fft);
    free(s);
}

static void nv_spectral_frame(NVSpectral *s) {
    int size = s->size, half = size / 2;
    float *re = s->re, *im = s->im;
    for (int i = 0; i < size; i++) {
        re[i] = s->input[(s->pos + i) % size] * s->window[i];
        im[i] = 0.0f;
    }
    nv_fft_transform(&s->fft, re, im, 0);
    re[0] = 0.0f;
    im[0] = 0.0f;
    for (int k = 1; k <= half; k++) {
        float magnitude = hypotf(re[k], im[k]);
        if (s->robot) {
            // Zero phase, moved to the middle of the frame (the sign flip of odd bins) where the window is open.
            re[k] = (k % 2 == 0) ? magnitude : -magnitude;
            im[k] = 0.0f;
        } else {
            s->seed = nv_xorshift(s->seed);
            double angle = s->seed / 2147483648.0 * M_PI;
            re[k] = magnitude * (float)cos(angle);
            im[k] = (k == half) ? 0.0f : magnitude * (float)sin(angle);
        }
        if (k < half) {
            re[size - k] = re[k];
            im[size - k] = -im[k];
        }
    }
    nv_fft_transform(&s->fft, re, im, 1);
    for (int i = 0; i < size; i++) {
        s->output[(s->pos + i) % size] += re[i] * s->window[i] * s->scale;
    }
}

static float nv_spectral_process(NVSpectral *s, float x) {
    s->dryDelayed = s->input[s->pos];
    s->input[s->pos] = x;
    float y = s->output[s->pos];
    s->output[s->pos] = 0.0f;
    s->pos = (s->pos + 1) % s->size;
    if (++s->sinceFrame == s->hop) {
        s->sinceFrame = 0;
        nv_spectral_frame(s);
    }
    return y;
}

// MARK: - Freeverb (Jezar at Dreampoint, public domain)

#define NV_COMBS 8
#define NV_ALLPASSES 4

typedef struct {
    float *combs[NV_COMBS];
    int combSize[NV_COMBS];
    int combPos[NV_COMBS];
    float combStore[NV_COMBS];
    float *allpasses[NV_ALLPASSES];
    int allpassSize[NV_ALLPASSES];
    int allpassPos[NV_ALLPASSES];
    float feedback, damp;
    float *preDelay;
    int preDelaySize, preDelayPos;
    float highPassCoef, highPassOut, highPassIn;
} NVFreeverb;

static NVFreeverb *nv_reverb_create(int sampleRate, const NVPreset *preset) {
    static const int combTunings[NV_COMBS] = { 1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617 };
    static const int allpassTunings[NV_ALLPASSES] = { 556, 441, 341, 225 };
    NVFreeverb *r = (NVFreeverb *)calloc(1, sizeof(NVFreeverb));
    float scale = sampleRate / 44100.0f;
    for (int i = 0; i < NV_COMBS; i++) {
        int size = (int)(combTunings[i] * scale);
        r->combSize[i] = size < 1 ? 1 : size;
        r->combs[i] = (float *)calloc(r->combSize[i], sizeof(float));
    }
    for (int i = 0; i < NV_ALLPASSES; i++) {
        int size = (int)(allpassTunings[i] * scale);
        r->allpassSize[i] = size < 1 ? 1 : size;
        r->allpasses[i] = (float *)calloc(r->allpassSize[i], sizeof(float));
    }
    r->feedback = preset->reverbRoom * 0.28f + 0.7f;
    r->damp = preset->reverbDamp * 0.4f;
    if (preset->reverbPreDelayMs > 0.0f) {
        int size = (int)(sampleRate * preset->reverbPreDelayMs / 1000.0f);
        r->preDelaySize = size < 1 ? 1 : size;
        r->preDelay = (float *)calloc(r->preDelaySize, sizeof(float));
    }
    // A one-pole high-pass at 200 Hz on what goes into the reverb, so low notes don't pile up into a boom.
    r->highPassCoef = (float)exp(-2.0 * M_PI * 200.0 / sampleRate);
    return r;
}

static void nv_reverb_destroy(NVFreeverb *r) {
    if (!r) return;
    for (int i = 0; i < NV_COMBS; i++) free(r->combs[i]);
    for (int i = 0; i < NV_ALLPASSES; i++) free(r->allpasses[i]);
    free(r->preDelay);
    free(r);
}

static float nv_reverb_process(NVFreeverb *r, float dry) {
    r->highPassOut = r->highPassCoef * (r->highPassOut + dry - r->highPassIn);
    r->highPassIn = dry;
    float x = r->highPassOut;
    float input = x;
    if (r->preDelay) {
        float delayed = r->preDelay[r->preDelayPos];
        r->preDelay[r->preDelayPos] = x;
        r->preDelayPos = (r->preDelayPos + 1) % r->preDelaySize;
        input = delayed;
    }
    input *= 0.015f * 2.0f;
    float out = 0.0f;
    for (int c = 0; c < NV_COMBS; c++) {
        int pos = r->combPos[c];
        float y = r->combs[c][pos];
        r->combStore[c] = y * (1.0f - r->damp) + r->combStore[c] * r->damp;
        r->combs[c][pos] = input + r->combStore[c] * r->feedback;
        r->combPos[c] = (pos + 1) % r->combSize[c];
        out += y;
    }
    for (int a = 0; a < NV_ALLPASSES; a++) {
        int pos = r->allpassPos[a];
        float buffered = r->allpasses[a][pos];
        r->allpasses[a][pos] = out + buffered * 0.5f;
        r->allpassPos[a] = (pos + 1) % r->allpassSize[a];
        out = buffered - out;
    }
    return out * 3.0f;
}

// MARK: - The effect

#define NV_WARP_HEADROOM 0.5f

struct NVEffect {
    NVPreset preset;
    int sampleRate;
    NVFormantWarp *warp;
    float inputScale;
    int warpLagLeft;
    NVSonic sonic;
    double ringStep, ringPhase;
    float *echo;
    int echoSize, echoPos;
    float echoDamp;
    NVFreeverb *reverb;
    NVSpectral *spectral;
    int spectralLag, fadeLength;
    double roughPhase;
    float noiseLow;
    int32_t noiseSeed;
    // Scratch buffers, grown as needed.
    int16_t *stage;
    int32_t stageCapacity;
    int16_t *out;
    int32_t outCapacity;
};

static int16_t *nv_reserve(int16_t **buffer, int32_t *capacity, int32_t needed) {
    if (needed > *capacity) {
        int32_t newCapacity = *capacity * 2;
        if (newCapacity < needed) newCapacity = needed;
        int16_t *grown = (int16_t *)realloc(*buffer, sizeof(int16_t) * newCapacity);
        if (!grown) return NULL;
        *buffer = grown;
        *capacity = newCapacity;
    }
    return *buffer;
}

NVEffect *nv_effect_create(int32_t presetId, NVParams params, int32_t sampleRate) {
    if (presetId == NV_PRESET_OFF || !nv_preset_is_known(presetId) || sampleRate <= 0) {
        return NULL;
    }
    NVEffect *e = (NVEffect *)calloc(1, sizeof(NVEffect));
    e->preset = nv_preset_resolve(presetId, params);
    e->sampleRate = sampleRate;
    const NVPreset *p = &e->preset;

    // Sonic moves the formants along with the pitch, so the warp moves them only by what is left over.
    if (p->hasFormant) {
        e->warp = nv_warp_create(powf(2.0f, (p->formant - p->semitones) / 12.0f), sampleRate);
        e->warpLagLeft = e->warp->size;
    }
    e->inputScale = e->warp ? 1.0f / NV_WARP_HEADROOM : 1.0f;

    if (p->semitones != 0.0f || p->rate != 1.0f) {
        e->sonic = nv_sonic_create(sampleRate, 1);
        nv_sonic_set_speed(e->sonic, 1.0f);
        nv_sonic_set_pitch(e->sonic, powf(2.0f, p->semitones / 12.0f));
        // Android plays the samples at sampleRate / rate; sonic's rate is input over output rate.
        int outputRate = (int)lroundf(sampleRate / p->rate);
        nv_sonic_set_rate(e->sonic, (float)sampleRate / (float)outputRate);
    }

    e->ringStep = 2.0 * M_PI * p->ringHz / sampleRate;
    if (p->echoMs > 0.0f) {
        int size = (int)(sampleRate * p->echoMs / 1000.0f);
        e->echoSize = size < 1 ? 1 : size;
        e->echo = (float *)calloc(e->echoSize, sizeof(float));
    }
    if (p->reverbMix > 0.0f) {
        e->reverb = nv_reverb_create(sampleRate, p);
    }
    if (p->robotHz > 0.0f) {
        e->spectral = nv_spectral_create(1, 1024, (int)lroundf(sampleRate / p->robotHz));
    } else if (p->whisper > 0.0f) {
        e->spectral = nv_spectral_create(0, 512, 128);
    }
    e->spectralLag = e->spectral ? e->spectral->size : 0;
    e->fadeLength = (e->echo || e->reverb) ? sampleRate : 0;
    e->noiseSeed = 0x2545F491;
    return e;
}

void nv_effect_destroy(NVEffect *e) {
    if (!e) return;
    nv_warp_destroy(e->warp);
    if (e->sonic) nv_sonic_destroy(e->sonic);
    free(e->echo);
    nv_reverb_destroy(e->reverb);
    nv_spectral_destroy(e->spectral);
    free(e->stage);
    free(e->out);
    free(e);
}

static float nv_next_noise(NVEffect *e) {
    e->noiseSeed = nv_xorshift(e->noiseSeed);
    return e->noiseSeed / 2147483648.0f;
}

// Linear up to 0.9, then bends smoothly toward 1, so loud peaks never clip hard.
static float nv_soft_limit(float x) {
    float a = fabsf(x);
    if (a <= 0.9f) return x;
    float bent = 0.9f + 0.1f * tanhf((a - 0.9f) / 0.1f);
    return x < 0 ? -bent : bent;
}

static void nv_apply_stages(NVEffect *e, int16_t *samples, int32_t count) {
    const NVPreset *p = &e->preset;
    for (int32_t i = 0; i < count; i++) {
        float x = samples[i] / 32768.0f * e->inputScale;

        if (e->spectral) {
            float wet = nv_spectral_process(e->spectral, x);
            x = p->robotHz > 0.0f ? wet : e->spectral->dryDelayed * (1.0f - p->whisper) + wet * p->whisper;
        }
        if (p->ringMix > 0.0f) {
            float ring = x * (float)sin(e->ringPhase);
            x = x * (1.0f - p->ringMix) + ring * p->ringMix;
            e->ringPhase += e->ringStep;
            if (e->ringPhase > 2.0 * M_PI) e->ringPhase -= 2.0 * M_PI;
        }
        if (p->roughness > 0.0f) {
            // An irregular 30..50 Hz flutter of the loudness, like a strained throat.
            e->roughPhase += 2.0 * M_PI * (40.0 + 10.0 * nv_next_noise(e)) / e->sampleRate;
            if (e->roughPhase > 2.0 * M_PI) e->roughPhase -= 2.0 * M_PI;
            x *= 1.0f - p->roughness * (0.5f + 0.5f * (float)sin(e->roughPhase));
        }
        if (p->drive > 0.0f) {
            x = (float)(tanh((double)(x * p->drive)) / tanh((double)p->drive));
        }
        if (e->echo) {
            // A one-pole low-pass in the loop: each repeat loses some treble.
            float past = e->echo[e->echoPos];
            e->echoDamp += (past - e->echoDamp) * 0.6f;
            e->echo[e->echoPos] = x + e->echoDamp * p->echoFeedback;
            e->echoPos = (e->echoPos + 1) % e->echoSize;
            x += e->echoDamp * p->echoMix;
        }
        if (e->reverb) {
            x = x * (1.0f - p->reverbMix * 0.5f) + nv_reverb_process(e->reverb, x) * p->reverbMix;
        }
        if (p->noise > 0.0f) {
            // Softened (low-passed) noise, a hiss rather than a hard white noise.
            e->noiseLow += (nv_next_noise(e) - e->noiseLow) * 0.35f;
            x += e->noiseLow * p->noise * 2.0f;
        }

        x *= p->gain;
        samples[i] = nv_to_short(nv_soft_limit(x) * 32767.0f);
    }
}

// `count` samples through the warp, without its lag at the start; writes into e->stage, returns the count written.
static int32_t nv_warped(NVEffect *e, const int16_t *input, int32_t count) {
    int32_t skip = e->warpLagLeft < count ? e->warpLagLeft : count;
    if (!nv_reserve(&e->stage, &e->stageCapacity, count - skip + 1)) return 0;
    for (int32_t i = 0; i < count; i++) {
        float x = input ? input[i] / 32768.0f : 0.0f;
        float y = nv_warp_process(e->warp, x) * NV_WARP_HEADROOM;
        if (i >= skip) {
            float v = y * 32767.0f;
            if (v < -32768.0f) v = -32768.0f;
            if (v > 32767.0f) v = 32767.0f;
            e->stage[i - skip] = (int16_t)(int)v;
        }
    }
    e->warpLagLeft -= skip;
    return count - skip;
}

// Appends what sonic has ready to e->out after `offset` samples; returns the new total.
static int32_t nv_take_sonic(NVEffect *e, int32_t offset) {
    int32_t available = nv_sonic_samples_available(e->sonic);
    if (!nv_reserve(&e->out, &e->outCapacity, offset + available + 1)) return offset;
    if (available > 0) {
        offset += nv_sonic_read(e->sonic, e->out + offset, available);
    }
    return offset;
}

int32_t nv_effect_process(NVEffect *e, const int16_t *input, int32_t count, const int16_t **output) {
    *output = NULL;
    if (!e || count <= 0) return 0;
    const int16_t *source = input;
    int32_t sourceCount = count;
    if (e->warp) {
        sourceCount = nv_warped(e, input, count);
        source = e->stage;
    }
    int32_t n;
    if (e->sonic) {
        if (sourceCount > 0) nv_sonic_write(e->sonic, source, sourceCount);
        n = nv_take_sonic(e, 0);
    } else {
        if (!nv_reserve(&e->out, &e->outCapacity, sourceCount + 1)) return 0;
        memcpy(e->out, source, sizeof(int16_t) * sourceCount);
        n = sourceCount;
    }
    nv_apply_stages(e, e->out, n);
    *output = e->out;
    return n;
}

int32_t nv_effect_drain(NVEffect *e, const int16_t **output) {
    *output = NULL;
    if (!e) return 0;
    // Silence through the warp first: it still holds the last of the voice.
    int32_t restCount = 0;
    const int16_t *rest = NULL;
    if (e->warp) {
        restCount = nv_warped(e, NULL, e->warp->size);
        rest = e->stage;
    }
    if (e->sonic) {
        if (restCount > 0) nv_sonic_write(e->sonic, rest, restCount);
        nv_sonic_flush(e->sonic);
        restCount = nv_take_sonic(e, 0);
    } else {
        if (!nv_reserve(&e->out, &e->outCapacity, restCount + 1)) return 0;
        if (restCount > 0) memcpy(e->out, rest, sizeof(int16_t) * restCount);
    }
    // Silence pushed through the stages brings out what they still hold; the echo or reverb part fades to nothing.
    int32_t total = restCount + e->spectralLag + e->fadeLength;
    if (!nv_reserve(&e->out, &e->outCapacity, total + 1)) return 0;
    memset(e->out + restCount, 0, sizeof(int16_t) * (total - restCount));
    nv_apply_stages(e, e->out, total);
    int32_t fadeStart = restCount + e->spectralLag;
    for (int32_t i = 0; i < e->fadeLength; i++) {
        e->out[fadeStart + i] = nv_to_short(e->out[fadeStart + i] * (1.0f - (float)i / e->fadeLength));
    }
    *output = e->out;
    return total;
}

// MARK: - Calls

// The choice packed into one value: bits 0..7 preset id, 8..15 tone + 12, 16..19 echo delay, 20..23 echo volume,
// 24..27 noise volume. 0 is off.
static _Atomic uint32_t nv_call_choice = 0;

void nv_call_set_choice(int32_t presetId, NVParams params) {
    uint32_t packed = 0;
    if (presetId != NV_PRESET_OFF && nv_preset_is_known(presetId) && !nv_preset_is_speed(presetId)) {
        params = nv_params_clamped(params);
        packed = (uint32_t)presetId
            | ((uint32_t)(params.tone - NV_TONE_MIN) << 8)
            | ((uint32_t)params.echoDelay << 16)
            | ((uint32_t)params.echoVolume << 20)
            | ((uint32_t)params.noiseVolume << 24);
    }
    atomic_store_explicit(&nv_call_choice, packed, memory_order_release);
}

int nv_call_is_on(void) {
    return atomic_load_explicit(&nv_call_choice, memory_order_relaxed) != 0;
}

typedef struct {
    uint32_t choice;
    int32_t sampleRate;
    NVEffect *effect;
    int16_t *queue;
    int32_t queueCapacity;
    int32_t queued;
    int started;
} NVCallState;

// Only the call's recording thread touches this.
static NVCallState nv_call_state;

static void nv_call_drop(NVCallState *s, int32_t count) {
    memmove(s->queue, s->queue + count, sizeof(int16_t) * (s->queued - count));
    s->queued -= count;
}

void nv_call_process_in_place(int16_t *samples, int32_t count, int32_t sampleRate) {
    if (!samples || count <= 0 || sampleRate <= 0) return;
    NVCallState *s = &nv_call_state;
    uint32_t choice = atomic_load_explicit(&nv_call_choice, memory_order_acquire);
    // A new choice (or a new rate) is a new effect; comparing one number every 10 ms is cheap.
    if (choice != s->choice || sampleRate != s->sampleRate) {
        s->choice = choice;
        s->sampleRate = sampleRate;
        nv_effect_destroy(s->effect);
        s->effect = NULL;
        if (choice != 0) {
            NVParams params;
            params.tone = (int32_t)((choice >> 8) & 0xFF) + NV_TONE_MIN;
            params.echoDelay = (int32_t)((choice >> 16) & 0xF);
            params.echoVolume = (int32_t)((choice >> 20) & 0xF);
            params.noiseVolume = (int32_t)((choice >> 24) & 0xF);
            s->effect = nv_effect_create((int32_t)(choice & 0xFF), params, sampleRate);
        }
        s->queued = 0;
        s->started = 0;
        if (s->effect && s->queueCapacity < sampleRate / 2) {
            free(s->queue);
            s->queueCapacity = sampleRate / 2;
            s->queue = (int16_t *)malloc(sizeof(int16_t) * s->queueCapacity);
        }
    }
    if (!s->effect) return;

    const int16_t *processed = NULL;
    int32_t n = nv_effect_process(s->effect, samples, count, &processed);
    if (n > 0) {
        if (!nv_reserve(&s->queue, &s->queueCapacity, s->queued + n)) return;
        memcpy(s->queue + s->queued, processed, sizeof(int16_t) * n);
        s->queued += n;
    }
    // Silence until the queue holds a buffer to spare; then a buffer out for every buffer in. Should the effect fall
    // behind, the gap is silent; should it run ahead, the oldest samples go rather than the delay growing.
    if (!s->started && s->queued >= count * 2) {
        s->started = 1;
    }
    if (s->queued > count * 6) {
        nv_call_drop(s, s->queued - count * 2);
    }
    if (!s->started) {
        memset(samples, 0, sizeof(int16_t) * count);
        return;
    }
    int32_t take = count < s->queued ? count : s->queued;
    memcpy(samples, s->queue, sizeof(int16_t) * take);
    if (take < count) memset(samples + take, 0, sizeof(int16_t) * (count - take));
    nv_call_drop(s, take);
}

// The copy nv_call_process hands back; 10 ms at 48 kHz is 480 samples, so 4800 is far more than a buffer ever is.
#define NV_CALL_COPY_CAPACITY 4800
static int16_t nv_call_copy[NV_CALL_COPY_CAPACITY];

const void *nv_call_process(const void *samples, size_t count, size_t bytesPerSample, size_t channels, uint32_t sampleRate) {
    if (!samples || bytesPerSample != 2 || channels != 1 || count == 0 || count > NV_CALL_COPY_CAPACITY) {
        return samples;
    }
    // Off: nothing to do, but the effect is dropped (and its memory freed) the next time one is on.
    if (!nv_call_is_on() && nv_call_state.effect == NULL) {
        return samples;
    }
    memcpy(nv_call_copy, samples, count * sizeof(int16_t));
    nv_call_process_in_place(nv_call_copy, (int32_t)count, (int32_t)sampleRate);
    return nv_call_copy;
}
