#include <metal_stdlib>
using namespace metal;

// Must match CallStatusBarWavesLayer.Uniforms (CallStatusBarWavesLayer.swift) field for field.
struct CallStatusBarWavesUniforms {
    float4 gradientColor0;
    float4 gradientColor1;
    // Per wave, bottom to top (big, medium, small): x = alpha, y = fill, z = saturation, w = matte.
    float4 waveStyle[3];
    // Per wave: x = rim opacity, y = 1 when the wave refracts.
    float4 waveRimGlass[3];
    // Layer size in points.
    float2 boundsSize;
    // Rendered size in pixels, excluding the edge inset.
    float2 renderSize;
    float edgeInset;
    float gradientLength;
    float crestSpacing;
    float shadowStrength;
    float shadowSigma;
    float shadowDrop;
    float rimScale;
    float rimWidth;
    float glassBand;
    float glassShift;
    float glassAmount;
    // 0: waves, 1: liquid glass waves, 2: flat bar.
    int mode;
};

constant static int callStatusBarCrestSampleCount = 128;
constant static int callStatusBarCrestPointCount = 6;

// Must match CallStatusBarWavesLayer.CrestWave.
struct CallStatusBarCrestWave {
    // Normalized: x in 0...1 across the bar, y in units of the amplitude.
    float2 fromPoints[callStatusBarCrestPointCount];
    float2 toPoints[callStatusBarCrestPointCount];
    // Eased progress from `fromPoints` to `toPoints`.
    float progress;
    // How far the wave has sunk with the audio level, in points.
    float offset;
};

// Must match CallStatusBarWavesLayer.CrestParameters.
struct CallStatusBarCrestParameters {
    CallStatusBarCrestWave waves[3];
    float width;
    float restY;
    float amplitude;
    float smoothness;
};

struct CallStatusBarCrestSegment {
    float2 start;
    float2 control1;
    float2 control2;
    float2 end;
};

static float2 callStatusBarCrestPoint(constant float2 *points, int index, constant CallStatusBarCrestParameters &parameters) {
    float2 point = points[clamp(index, 0, callStatusBarCrestPointCount - 1)];
    return float2(point.x * parameters.width, parameters.restY + point.y * parameters.amplitude);
}

// Segment `index` of the smooth curve through `points`. Each point's handles follow the direction from its
// previous to its next neighbor, a `smoothness` fraction of the chord long. Neighbors are clamped at the ends
// rather than wrapped around: wrapping turns the end tangents outwards and the curve overshoots the screen edge
// in a diagonal beak.
static CallStatusBarCrestSegment callStatusBarCrestSegment(constant float2 *points, int index, constant CallStatusBarCrestParameters &parameters) {
    float2 previous = callStatusBarCrestPoint(points, index - 1, parameters);
    float2 start = callStatusBarCrestPoint(points, index, parameters);
    float2 end = callStatusBarCrestPoint(points, index + 1, parameters);
    float2 afterEnd = callStatusBarCrestPoint(points, index + 2, parameters);
    float handleLength = parameters.smoothness * distance(start, end);

    CallStatusBarCrestSegment segment;
    segment.start = start;
    segment.control1 = start + normalize(end - previous) * handleLength;
    segment.control2 = end - normalize(afterEnd - start) * handleLength;
    segment.end = end;
    return segment;
}

static float2 callStatusBarCrestSegmentPoint(CallStatusBarCrestSegment segment, float t) {
    float u = 1.0 - t;
    return u * u * u * segment.start + 3.0 * u * u * t * segment.control1 + 3.0 * u * t * t * segment.control2 + t * t * t * segment.end;
}

// Samples each wave's crest at evenly spaced x for the render passes. The crest eases from one shape to the next
// like a CAShapeLayer path animation would: the bezier control points are interpolated, not the points.
// One threadgroup per wave; its threads share the samples, whatever the threadgroup size.
kernel void callStatusBarWavesCrestKernel(
    constant CallStatusBarCrestParameters &parameters [[ buffer(0) ]],
    device float *crests [[ buffer(1) ]],
    uint threadIndex [[ thread_position_in_threadgroup ]],
    uint threadCount [[ threads_per_threadgroup ]],
    uint waveIndex [[ threadgroup_position_in_grid ]]
) {
    if (waveIndex >= 3) {
        return;
    }
    constant CallStatusBarCrestWave &wave = parameters.waves[waveIndex];
    
    for (uint sampleIndex = threadIndex; sampleIndex < uint(callStatusBarCrestSampleCount); sampleIndex += threadCount) {
        float x = parameters.width * float(sampleIndex) / float(callStatusBarCrestSampleCount - 1);
        
        int segmentIndex = 0;
        for (int i = 1; i < callStatusBarCrestPointCount - 1; i++) {
            float knot = mix(wave.fromPoints[i].x, wave.toPoints[i].x, wave.progress) * parameters.width;
            if (x >= knot) {
                segmentIndex = i;
            }
        }
        
        CallStatusBarCrestSegment from = callStatusBarCrestSegment(wave.fromPoints, segmentIndex, parameters);
        CallStatusBarCrestSegment to = callStatusBarCrestSegment(wave.toPoints, segmentIndex, parameters);
        CallStatusBarCrestSegment segment;
        segment.start = mix(from.start, to.start, wave.progress);
        segment.control1 = mix(from.control1, to.control1, wave.progress);
        segment.control2 = mix(from.control2, to.control2, wave.progress);
        segment.end = mix(from.end, to.end, wave.progress);
        
        // The crest runs left to right, so bisect the curve parameter for this x.
        float lower = 0.0;
        float upper = 1.0;
        for (int i = 0; i < 20; i++) {
            float middle = 0.5 * (lower + upper);
            if (callStatusBarCrestSegmentPoint(segment, middle).x < x) {
                lower = middle;
            } else {
                upper = middle;
            }
        }
        float y = callStatusBarCrestSegmentPoint(segment, 0.5 * (lower + upper)).y;
        
        crests[waveIndex * callStatusBarCrestSampleCount + sampleIndex] = y + wave.offset;
    }
}

constant static float2 callStatusBarQuadVertices[6] = {
    float2(0.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0)
};

struct CallStatusBarWavesVertexOut {
    float4 position [[position]];
    float2 uv;
};

// `rect` is the allocation in normalized surface coordinates, y pointing up. uv.y = 0 is the top edge of the layer.
vertex CallStatusBarWavesVertexOut callStatusBarWavesVertex(
    constant float4 &rect [[ buffer(0) ]],
    unsigned int vid [[ vertex_id ]]
) {
    float2 quadVertex = callStatusBarQuadVertices[vid];

    CallStatusBarWavesVertexOut out;
    float x = rect.x + quadVertex.x * rect.z;
    float y = rect.y + (1.0 - quadVertex.y) * rect.w;
    out.position = float4(-1.0 + x * 2.0, -1.0 + y * 2.0, 0.0, 1.0);
    out.uv = quadVertex;
    return out;
}

struct CallStatusBarWaveSample {
    // Signed distance to the crest in points, positive inside the wave (above the crest).
    float distance;
    // Unit normal of the crest pointing into the wave.
    float2 inwardNormal;
};

static CallStatusBarWaveSample callStatusBarWave(constant float *crests, int wave, float2 point, float spacing) {
    constant float *crest = crests + wave * callStatusBarCrestSampleCount;

    float position = clamp(point.x / spacing, 0.0, float(callStatusBarCrestSampleCount - 1));
    int index = min(int(position), callStatusBarCrestSampleCount - 2);
    float t = position - float(index);
    float y0 = crest[index];
    float y1 = crest[index + 1];
    float slope = (y1 - y0) / spacing;
    float normalization = rsqrt(1.0 + slope * slope);

    CallStatusBarWaveSample result;
    result.distance = (mix(y0, y1, t) - point.y) * normalization;
    result.inwardNormal = float2(slope, -1.0) * normalization;
    return result;
}

static float callStatusBarCoverage(float distance, float pixelsPerPoint) {
    return saturate(distance * pixelsPerPoint + 0.5);
}

static float callStatusBarErf(float x) {
    // Winitzki's approximation, absolute error below 1.3e-4.
    const float a = 0.147;
    float x2 = x * x;
    float t = 1.0 - exp(-x2 * (1.2732395 + a * x2) / (1.0 + a * x2));
    return sign(x) * sqrt(max(t, 0.0));
}

// Coverage of a Gaussian-blurred edge at `distance` from it.
static float callStatusBarBlurredCoverage(float distance, float sigma) {
    return 0.5 * (1.0 + callStatusBarErf(distance / (sigma * 1.41421356)));
}

static float2 callStatusBarPoint(float2 uv, constant CallStatusBarWavesUniforms &uniforms, thread float &pixelsPerPoint) {
    float2 allocationSize = uniforms.renderSize + 2.0 * uniforms.edgeInset;
    float2 pixel = uv * allocationSize - uniforms.edgeInset;
    pixelsPerPoint = uniforms.renderSize.y / uniforms.boundsSize.y;
    return pixel * uniforms.boundsSize / uniforms.renderSize;
}

// What the bar does to the content behind it, as an affine function of that content B: B * multiplier + addend.
// Composing the layer stack in this form lets the multiplied color (which needs B) be split into one multiply
// layer and one additive layer.
struct CallStatusBarComposite {
    float3 multiplier;
    float3 addend;
};

static void callStatusBarApplyOver(thread CallStatusBarComposite &composite, float3 premultipliedColor, float alpha) {
    composite.multiplier *= 1.0 - alpha;
    composite.addend = composite.addend * (1.0 - alpha) + premultipliedColor;
}

static CallStatusBarComposite callStatusBarComposite(float2 point, float pixelsPerPoint, constant CallStatusBarWavesUniforms &uniforms, constant float *crests) {
    float3 gradient = mix(uniforms.gradientColor0.rgb, uniforms.gradientColor1.rgb, saturate(point.x / uniforms.gradientLength));

    CallStatusBarComposite composite;
    composite.multiplier = float3(1.0);
    composite.addend = float3(0.0);

    CallStatusBarWaveSample waves[3];
    float coverage[3];
    for (int i = 0; i < 3; i++) {
        waves[i] = callStatusBarWave(crests, i, point, uniforms.crestSpacing);
        coverage[i] = callStatusBarCoverage(waves[i].distance, pixelsPerPoint);
    }

    if (uniforms.mode == 2) {
        // All crests are the resting line.
        callStatusBarApplyOver(composite, gradient * coverage[2], coverage[2]);
        return composite;
    }

    // A soft shadow cast by the lowest wave, under everything else.
    float shadowDistance = waves[0].distance - uniforms.shadowDrop * waves[0].inwardNormal.y;
    float shadow = uniforms.shadowStrength * callStatusBarBlurredCoverage(shadowDistance, uniforms.shadowSigma);
    callStatusBarApplyOver(composite, float3(0.0), shadow);

    if (uniforms.mode == 0) {
        // The gradient masked by the three waves at their own alphas.
        float transparency = 1.0;
        for (int i = 0; i < 3; i++) {
            transparency *= 1.0 - uniforms.waveStyle[i].x * coverage[i];
        }
        float alpha = 1.0 - transparency;
        callStatusBarApplyOver(composite, gradient * alpha, alpha);
        return composite;
    }

    // Liquid waves. Each wave is a gradient fill with a white matte above it, composited as a group and clipped
    // to the wave.
    for (int i = 0; i < 3; i++) {
        float4 style = uniforms.waveStyle[i];
        float fillAlpha = style.x * style.y;
        float matteAlpha = style.w * style.x;
        float3 groupColor = gradient * fillAlpha * (1.0 - matteAlpha) + matteAlpha;
        float groupAlpha = fillAlpha + matteAlpha - fillAlpha * matteAlpha;
        callStatusBarApplyOver(composite, groupColor * coverage[i], groupAlpha * coverage[i]);
    }
    // The state color multiplied over the waves keeps them saturated without hiding the content behind.
    for (int i = 0; i < 3; i++) {
        float amount = uniforms.waveStyle[i].z * coverage[i];
        float3 factor = 1.0 - amount * (1.0 - gradient);
        composite.multiplier *= factor;
        composite.addend *= factor;
    }
    // Highlight along each crest, above the color so that the multiply does not swallow it.
    for (int i = 0; i < 3; i++) {
        float rim = uniforms.waveRimGlass[i].x * uniforms.rimScale;
        float line = saturate((0.5 * uniforms.rimWidth - abs(waves[i].distance)) * pixelsPerPoint + 0.5);
        float alpha = rim * line;
        callStatusBarApplyOver(composite, float3(alpha), alpha);
    }
    return composite;
}

fragment half4 callStatusBarWavesContentFragment(
    CallStatusBarWavesVertexOut in [[stage_in]],
    constant CallStatusBarWavesUniforms &uniforms [[ buffer(0) ]],
    constant float *crests [[ buffer(1) ]]
) {
    float pixelsPerPoint;
    float2 point = callStatusBarPoint(in.uv, uniforms, pixelsPerPoint);
    CallStatusBarComposite composite = callStatusBarComposite(point, pixelsPerPoint, uniforms, crests);

    if (uniforms.mode == 1) {
        // Added over the multiply layer (`plusL`). Zero alpha: the multiply layer already carries the coverage, and
        // where the group below is transparent (the outer half of a rim line) any alpha here would be counted twice.
        return half4(half3(composite.addend), 0.0);
    } else {
        // Source-over: the multiplier is a gray level here.
        return half4(half3(composite.addend), half(1.0 - composite.multiplier.r));
    }
}

fragment half4 callStatusBarWavesMultiplyFragment(
    CallStatusBarWavesVertexOut in [[stage_in]],
    constant CallStatusBarWavesUniforms &uniforms [[ buffer(0) ]],
    constant float *crests [[ buffer(1) ]]
) {
    float pixelsPerPoint;
    float2 point = callStatusBarPoint(in.uv, uniforms, pixelsPerPoint);
    CallStatusBarComposite composite = callStatusBarComposite(point, pixelsPerPoint, uniforms, crests);

    // Over an opaque destination D, multiply blending of a premultiplied (S, Sa) gives D * (S + 1 - Sa), so any
    // Sa >= 1 - min(m) with S = m - (1 - Sa) multiplies by m. The smallest such alpha matters where there is
    // nothing to multiply: the bar is composited as an offscreen group, and outside the waves (where the masked
    // backdrop leaves the group transparent) multiply blending just returns the source. With this choice the
    // source there is transparent, or plain black at the shadow's alpha, which is exactly right over anything.
    float3 multiplier = composite.multiplier;
    float minimum = min(multiplier.r, min(multiplier.g, multiplier.b));
    return half4(half3(multiplier - minimum), half(1.0 - minimum));
}

// Mask of the backdrop: the union of the waves, so that the blurred backdrop covers only what is under them.
fragment half4 callStatusBarWavesMaskFragment(
    CallStatusBarWavesVertexOut in [[stage_in]],
    constant CallStatusBarWavesUniforms &uniforms [[ buffer(0) ]],
    constant float *crests [[ buffer(1) ]]
) {
    float pixelsPerPoint;
    float2 point = callStatusBarPoint(in.uv, uniforms, pixelsPerPoint);

    float coverage = 0.0;
    for (int i = 0; i < 3; i++) {
        CallStatusBarWaveSample wave = callStatusBarWave(crests, i, point, uniforms.crestSpacing);
        coverage = max(coverage, callStatusBarCoverage(wave.distance, pixelsPerPoint));
    }
    return half4(half(coverage));
}

// Displacement map for the `displacementMap` filter, encoded like SpaceWarpView's: red and green carry the
// x and y offset by which content moves, 0.5 meaning none, scaled by the filter's amount.
fragment half4 callStatusBarWavesDisplacementFragment(
    CallStatusBarWavesVertexOut in [[stage_in]],
    constant CallStatusBarWavesUniforms &uniforms [[ buffer(0) ]],
    constant float *crests [[ buffer(1) ]]
) {
    float pixelsPerPoint;
    float2 point = callStatusBarPoint(in.uv, uniforms, pixelsPerPoint);

    // Each wave is a slab of glass with a rounded edge along its crest. Light entering the bevel bends towards
    // the inside of the wave, so near the crest the glass shows content from further inside: strongest at the
    // edge, fading out across the band.
    float2 sampleOffset = float2(0.0);
    for (int i = 0; i < 3; i++) {
        if (uniforms.waveRimGlass[i].y == 0.0) {
            continue;
        }
        CallStatusBarWaveSample wave = callStatusBarWave(crests, i, point, uniforms.crestSpacing);
        float coverage = callStatusBarCoverage(wave.distance, pixelsPerPoint);
        float falloff = 1.0 - saturate(max(wave.distance, 0.0) / uniforms.glassBand);
        sampleOffset += wave.inwardNormal * (uniforms.glassShift * falloff * falloff * coverage);
    }

    // Sampling from inside means content moves the opposite way.
    float2 encoded = saturate(0.5 - 0.5 * sampleOffset / uniforms.glassAmount);
    return half4(half(encoded.x), half(encoded.y), 1.0, 1.0);
}
