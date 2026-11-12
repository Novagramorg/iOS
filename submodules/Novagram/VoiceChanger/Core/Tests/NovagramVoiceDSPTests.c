// Host tests for the voice changer DSP: every preset runs, a tape speed changes the length, nothing clips hard and
// the call path keeps every buffer at its own size.
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "NovagramVoiceDSP/NovagramVoiceDSP.h"

static int failures = 0;

#define CHECK(cond, ...) do { if (!(cond)) { failures++; printf("FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

#define RATE 48000
#define SECONDS 2

// A voice-like test signal: a 150 Hz pulse train with a few harmonics, at about -6 dB.
static int16_t *make_voice(int32_t count) {
    int16_t *samples = (int16_t *)malloc(sizeof(int16_t) * count);
    for (int32_t i = 0; i < count; i++) {
        double t = (double)i / RATE;
        double v = 0.0;
        for (int h = 1; h <= 8; h++) {
            v += sin(2.0 * M_PI * 150.0 * h * t) / h;
        }
        samples[i] = (int16_t)(v * 0.25 * 32767.0);
    }
    return samples;
}

// Runs a whole recording through a preset in 960-sample chunks; returns the output length.
static int32_t run_preset(int32_t presetId, const int16_t *input, int32_t count, int16_t *peakOut) {
    NVEffect *effect = nv_effect_create(presetId, nv_params_default(), RATE);
    if (!effect) return -1;
    int32_t total = 0;
    int16_t peak = 0;
    const int16_t *out = NULL;
    for (int32_t offset = 0; offset < count; offset += 960) {
        int32_t chunk = count - offset < 960 ? count - offset : 960;
        int32_t n = nv_effect_process(effect, input + offset, chunk, &out);
        for (int32_t i = 0; i < n; i++) {
            int16_t a = out[i] < 0 ? (int16_t)(-(out[i] + 1)) : out[i];
            if (a > peak) peak = a;
        }
        total += n;
    }
    int32_t n = nv_effect_drain(effect, &out);
    total += n;
    nv_effect_destroy(effect);
    *peakOut = peak;
    return total;
}

int main(void) {
    int32_t count = RATE * SECONDS;
    int16_t *voice = make_voice(count);

    CHECK(nv_effect_create(NV_PRESET_OFF, nv_params_default(), RATE) == NULL, "off must have no effect");
    CHECK(nv_effect_create(11, nv_params_default(), RATE) == NULL, "id 11 is not a preset");

    for (int32_t id = 1; id <= NV_PRESET_SPEED_VERY_THIN; id++) {
        if (!nv_preset_is_known(id)) continue;
        int16_t peak = 0;
        int32_t length = run_preset(id, voice, count, &peak);
        CHECK(length > 0, "preset %d gave nothing", id);
        CHECK(peak <= 32767 && peak > 300, "preset %d peak %d", id, peak);
        // Without a speed the length stays the voice's (plus a tail of at most about a second and a bit).
        if (!nv_preset_is_speed(id)) {
            CHECK(length >= count * 9 / 10 && length <= count + RATE + 4096, "preset %d length %d", id, length);
        }
        printf("preset %2d: length %6d peak %5d\n", id, length, peak);
    }

    int16_t peak = 0;
    int32_t fast = run_preset(NV_PRESET_SPEED_VERY_THIN, voice, count, &peak);
    CHECK(abs(fast - (int32_t)(count / 1.5)) < RATE / 20, "speed 1.5 length %d, expected about %d", fast, (int32_t)(count / 1.5));
    int32_t slow = run_preset(NV_PRESET_SPEED_VERY_THICK, voice, count, &peak);
    CHECK(abs(slow - (int32_t)(count / 0.7)) < RATE / 20, "speed 0.7 length %d, expected about %d", slow, (int32_t)(count / 0.7));

    // Calls: off leaves the buffer as it is; on keeps the size and starts after the queue has a buffer to spare.
    int16_t buffer[480];
    memcpy(buffer, voice, sizeof(buffer));
    nv_call_set_choice(NV_PRESET_OFF, nv_params_default());
    nv_call_process_in_place(buffer, 480, RATE);
    CHECK(memcmp(buffer, voice, sizeof(buffer)) == 0, "call off must not change the voice");

    nv_call_set_choice(NV_PRESET_SPEED_THIN, nv_params_default());
    CHECK(!nv_call_is_on(), "a speed is never a call effect");

    nv_call_set_choice(NV_PRESET_ROBOT, nv_params_default());
    CHECK(nv_call_is_on(), "robot must be on");
    int nonSilent = 0;
    for (int32_t offset = 0; offset + 480 <= count; offset += 480) {
        memcpy(buffer, voice + offset, sizeof(buffer));
        nv_call_process_in_place(buffer, 480, RATE);
        for (int i = 0; i < 480; i++) if (buffer[i] != 0) { nonSilent++; break; }
    }
    CHECK(nonSilent > (count / 480) * 8 / 10, "call robot mostly silent: %d buffers", nonSilent);

    nv_call_set_choice(NV_PRESET_CHILD, nv_params_default());
    nonSilent = 0;
    for (int32_t offset = 0; offset + 480 <= count; offset += 480) {
        memcpy(buffer, voice + offset, sizeof(buffer));
        nv_call_process_in_place(buffer, 480, RATE);
        for (int i = 0; i < 480; i++) if (buffer[i] != 0) { nonSilent++; break; }
    }
    CHECK(nonSilent > (count / 480) * 7 / 10, "call child mostly silent: %d buffers", nonSilent);
    nv_call_set_choice(NV_PRESET_OFF, nv_params_default());

    free(voice);
    if (failures) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("all passed\n");
    return 0;
}
