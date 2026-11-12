/* Novagram voice changer: pitch shift and tape speed, derived from the Sonic library.

   Sonic library
   Copyright 2010
   Bill Cox
   This file is part of the Sonic Library.

   This file is licensed under the Apache 2.0 license.

   Changes by Novagram (2026-11-12): trimmed to what the voice changer uses, names renamed to nv_sonic_*.
   See NovagramPitchShift.c and CREDITS.md.
*/
#ifndef NOVAGRAM_PITCH_SHIFT_H
#define NOVAGRAM_PITCH_SHIFT_H

/* The range of voice pitches searched for (Hz); lower than 65 could overflow in findPitchPeriodInRange. */
#define NV_SONIC_MIN_PITCH 65
#define NV_SONIC_MAX_PITCH 400

/* Clamps for the inputs. */
#define NV_SONIC_MIN_SPEED 0.05f
#define NV_SONIC_MAX_SPEED 20.0f
#define NV_SONIC_MIN_PITCH_SETTING 0.05f
#define NV_SONIC_MAX_PITCH_SETTING 20.0f
#define NV_SONIC_MIN_RATE 0.05f
#define NV_SONIC_MAX_RATE 20.0f
#define NV_SONIC_MIN_SAMPLE_RATE 1000
#define NV_SONIC_MAX_SAMPLE_RATE 500000
#define NV_SONIC_MIN_CHANNELS 1
#define NV_SONIC_MAX_CHANNELS 32

/* Inputs are down-sampled to this rate for the pitch search. */
#define NV_SONIC_AMDF_FREQ 4000

typedef struct NVSonicStruct *NVSonic;

/* NULL only when out of memory. */
NVSonic nv_sonic_create(int sampleRate, int numChannels);
void nv_sonic_destroy(NVSonic stream);

/* Speed changes the length and keeps the pitch; pitch changes the pitch and keeps the length; rate does both, like
   playing a tape faster (input rate over output rate). */
void nv_sonic_set_speed(NVSonic stream, float speed);
void nv_sonic_set_pitch(NVSonic stream, float pitch);
void nv_sonic_set_rate(NVSonic stream, float rate);

/* Returns 0 when out of memory. */
int nv_sonic_write(NVSonic stream, const short *samples, int numSamples);
int nv_sonic_read(NVSonic stream, short *samples, int maxSamples);
/* Processes what is left, padding as needed; call at the end of the stream. */
int nv_sonic_flush(NVSonic stream);
int nv_sonic_samples_available(NVSonic stream);

#endif
