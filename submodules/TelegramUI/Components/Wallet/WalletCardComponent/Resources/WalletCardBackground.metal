#include <metal_stdlib>
using namespace metal;

struct WalletCardVertexOutput {
    float4 position [[position]];
    float2 uv;
};

struct WalletCardShaderUniforms {
    float time;
    float highlightTiltX;
    float highlightTiltY;
    float cornerRadius;
    float2 surfaceTilt;
    float2 cardSize;
};

struct WalletCardVertexUniforms {
    float4 bottomLeft;
    float4 bottomRight;
    float4 topLeft;
    float4 topRight;
};

static inline float walletCardHash(float value) {
    return fract(sin(value * 127.1) * 43758.5453);
}

static inline float3 walletCardLinearToSrgb(float3 value) {
    value = max(value, float3(0.0));
    const float3 linear = value * 12.92;
    const float3 encoded = 1.055 * pow(value, float3(1.0 / 2.4)) - 0.055;
    return select(encoded, linear, value <= float3(0.0031308));
}

static inline float3 walletCardApplySaturation(float3 value) {
    const float luminance = dot(value, float3(0.2126, 0.7152, 0.0722));
    return clamp(mix(float3(luminance), value, 1.6), float3(0.0), float3(1.0));
}

static inline float3 walletCardMatchButtonColor(float3 value) {
    // Calibrated against the rendered #3b86f7 wallet action button so the
    // material's lower-left reference area has the same perceived color.
    const float3 buttonColorGain = float3(1.05933, 0.912212, 0.968627);
    return clamp(value * buttonColorGain, float3(0.0), float3(1.0));
}

vertex WalletCardVertexOutput walletCardBackgroundVertex(
    constant float4 &rect [[buffer(0)]],
    constant WalletCardVertexUniforms &uniforms [[buffer(1)]],
    constant float4 &antialiasingParameters [[buffer(2)]],
    uint vertexID [[vertex_id]]
) {
    const float4 positions[] = {
        uniforms.bottomLeft,
        uniforms.bottomRight,
        uniforms.topLeft,
        uniforms.topRight,
    };
    const float2 textureCoordinates[] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0),
    };
    const float2 cornerDirections[] = {
        float2(-1.0, -1.0),
        float2(1.0, -1.0),
        float2(-1.0, 1.0),
        float2(1.0, 1.0),
    };

    WalletCardVertexOutput output;
    float4 localPosition = positions[vertexID];
    float2 localNdc = localPosition.xy / localPosition.w;
    const float edgeInsetPixels = 2.0;
    const float2 renderPixelSize = max(antialiasingParameters.xy, float2(1.0));
    const float2 cardPixelSize = max(antialiasingParameters.zw, float2(1.0));
    const float2 cornerDirection = cornerDirections[vertexID];
    localNdc += cornerDirection * edgeInsetPixels * 2.0 / renderPixelSize;
    float2 placementPosition = rect.xy + (localNdc * 0.5 + 0.5) * rect.zw;
    float2 placementClip = -1.0 + placementPosition * 2.0;
    output.position = float4(placementClip * localPosition.w, 0.0, localPosition.w);
    output.uv = textureCoordinates[vertexID]
        + float2(cornerDirection.x, -cornerDirection.y)
            * edgeInsetPixels / cardPixelSize;
    return output;
}

fragment float4 walletCardBackgroundFragment(
    WalletCardVertexOutput input [[stage_in]],
    constant WalletCardShaderUniforms &uniforms [[buffer(0)]],
    texture2d<float> starsMap [[texture(0)]],
    texture2d<float> noiseMap [[texture(1)]]
) {
    constexpr sampler cardSampler(filter::linear, address::clamp_to_edge);
    constexpr sampler noiseSampler(filter::linear, address::repeat);

    float2 uv = input.uv;
    float safeWidth = max(uniforms.cardSize.x, 1.0);
    float safeHeight = max(uniforms.cardSize.y, 1.0);

    float2 cardPosition = float2(
        (uv.x - 0.5) * 2.0,
        (0.5 - uv.y) * 2.0 * safeHeight / safeWidth
    );
    float radius = length(cardPosition);
    float centerFade = smoothstep(0.018, 0.090, radius);
    float2 radial = radius > 0.0001 ? cardPosition / radius : float2(1.0, 0.0);
    float2 tangent = float2(-radial.y, radial.x);

    constexpr float radialFrequencyScale = 0.9;
    constexpr float finishDetail = 1.65 * 0.12;
    float ringFrequency = 180.0 * radialFrequencyScale;
    float waveFrequency = 560.0 * radialFrequencyScale;
    float ringIndex = floor(radius * ringFrequency);
    float2 radialDerivatives = float2(dfdx(radius), dfdy(radius));
    float radialFootprint = length(radialDerivatives) * radialFrequencyScale;
    float ringFilter = 1.0 - smoothstep(0.35, 1.10, radialFootprint * 180.0);
    float waveFilter = 1.0 - smoothstep(1.15, 3.10, radialFootprint * 560.0);
    float fineFinish = mix(0.5, walletCardHash(ringIndex), ringFilter)
        + 0.35 * sin(
            radius * waveFrequency
                + walletCardHash(ringIndex * 0.37) * 6.2831853072
        ) * waveFilter;
    constexpr float finishVisibility = 1.0;
    float radialFinish = (fineFinish - 0.5)
        * finishDetail
        * finishVisibility
        * centerFade;

    float colorBlend = clamp(0.30 + uv.y * 0.50 + uv.x * 0.18, 0.0, 1.0);
    colorBlend = colorBlend * colorBlend * (3.0 - 2.0 * colorBlend);
    float3 gradient = mix(
        float3(0.033, 0.205, 0.885),
        float3(0.057, 0.275, 0.955),
        colorBlend
    );

    float brushedGrain = noiseMap.sample(noiseSampler, uv * float2(1.4, 8.0)).r;
    float mediumGrain = noiseMap.sample(noiseSampler, uv * float2(4.0, 3.0)).r;
    float fineGrain = noiseMap.sample(noiseSampler, uv * float2(19.0, 13.0)).r;
    float materialVariation =
        radialFinish * 0.48
        + (brushedGrain - 0.5) * 0.035
        + (mediumGrain - 0.5) * 0.035
        + (fineGrain - 0.5) * 0.018;
    gradient *= 1.0 + materialVariation;

    float2 normalizedTilt = clamp(
        float2(
            uniforms.highlightTiltY / 0.24,
            uniforms.highlightTiltX / 0.17
        ),
        float2(-1.0),
        float2(1.0)
    );
    float2 idleDiagonal = float2(1.0, -safeHeight / safeWidth);
    float2 idleDirection = normalize(idleDiagonal);
    float2 idlePerpendicular = float2(-idleDirection.y, idleDirection.x);
    float2 tiltDirection = float2(-normalizedTilt.x, -normalizedTilt.y);
    float rotationTurn = clamp(
        dot(tiltDirection, idlePerpendicular)
            / max(abs(idlePerpendicular.y), 0.0001),
        -1.0,
        1.0
    );
    float reflectionAngle = rotationTurn * 1.5707963268;
    float sineAngle = sin(reflectionAngle);
    float cosineAngle = cos(reflectionAngle);
    float2 keyDirection = float2(
        idleDirection.x * cosineAngle - idleDirection.y * sineAngle,
        idleDirection.x * sineAngle + idleDirection.y * cosineAngle
    );
    float tangentAlignment = dot(tangent, keyDirection);
    float roughnessNoise =
        radialFinish * 0.18
        + (brushedGrain - 0.5) * 0.025
        + (mediumGrain - 0.5) * 0.025;
    float roughness = clamp(0.20 + roughnessNoise, 0.13, 0.30);
    float wedgeWidth = mix(0.30, 0.44, (roughness - 0.13) / 0.17);
    float reflectionCenterProgress = clamp(
        radius / 0.275,
        0.0,
        1.0
    );
    float reflectionCenterCurve = reflectionCenterProgress
        * reflectionCenterProgress
        * reflectionCenterProgress
        * (reflectionCenterProgress
            * (reflectionCenterProgress * 6.0 - 15.0)
            + 10.0);
    float reflectionCenterFade = mix(0.10, 1.0, reflectionCenterCurve);
    float coreWedge = exp(
        -(tangentAlignment * tangentAlignment)
            / max(2.0 * wedgeWidth * wedgeWidth, 0.0001)
    );
    float haloWidth = wedgeWidth * 1.70;
    float haloWedge = exp(
        -(tangentAlignment * tangentAlignment)
            / max(2.0 * haloWidth * haloWidth, 0.0001)
    );
    float radialWedge = mix(coreWedge, haloWedge, 0.42) * reflectionCenterFade;
    float signedLobe = dot(radial, keyDirection);
    float lobeBalance = mix(0.72, 1.0, 0.5 + 0.5 * signedLobe);
    float fibreReflection = smoothstep(0.47, 0.86, brushedGrain) * 0.58
        + smoothstep(0.56, 0.91, mediumGrain) * 0.42;
    float ringReflection = clamp(
        0.78 + radialFinish * 2.4 + fibreReflection * 0.28,
        0.42,
        1.30
    );
    float studioReflection = radialWedge * lobeBalance * ringReflection;
    constexpr float3 cyanReflection = float3(0.016, 0.565, 0.965);
    gradient += cyanReflection * studioReflection * 0.32;

    float2 normalizedSurfaceTilt = clamp(
        float2(
            uniforms.surfaceTilt.y / 0.24,
            uniforms.surfaceTilt.x / 0.17
        ),
        float2(-1.0),
        float2(1.0)
    );
    constexpr float starDepthPoints = 4.0;
    float2 inverseCardSize = 1.0 / float2(safeWidth, safeHeight);
    float2 starParallax = float2(
        normalizedSurfaceTilt.x,
        -normalizedSurfaceTilt.y
    ) * starDepthPoints * inverseCardSize;
    float4 star = starsMap.sample(cardSampler, uv + starParallax);
    float starPhase = star.g / max(star.a, 0.001);
    float twinkle = 0.6 + 0.4 * sin(uniforms.time * 1.7 + starPhase * 6.28318);
    float highlightCoverage = smoothstep(0.16, 0.58, radialWedge * lobeBalance);
    float starAlpha = 0.5
        * star.a
        * (0.72 + 0.28 * colorBlend)
        * twinkle
        * highlightCoverage;
    float3 lifted = select(
        sqrt(gradient),
        ((16.0 * gradient - 12.0) * gradient + 4.0) * gradient,
        gradient <= float3(0.25)
    );
    gradient = mix(gradient, lifted, starAlpha);
    float3 spark = float3(0.55, 0.8, 1.0)
        * starAlpha * starAlpha * (0.4 + 0.4 * colorBlend);

    gradient += (fineGrain - 0.5) * 0.014;
    gradient *= 1.0 - 0.14 * smoothstep(0.965, 1.0, uv.y);

    float2 halfSize = float2(safeWidth, safeHeight) * 0.5;
    float radiusPoints = min(uniforms.cornerRadius, min(halfSize.x, halfSize.y));
    float2 roundedPoint = abs(uv * float2(safeWidth, safeHeight) - halfSize)
        - (halfSize - radiusPoints);
    float roundedDistance = length(max(roundedPoint, 0.0))
        + min(max(roundedPoint.x, roundedPoint.y), 0.0)
        - radiusPoints;
    const float edgeWidth = max(fwidth(roundedDistance), 0.001);
    float coverage = 1.0 - smoothstep(-edgeWidth, edgeWidth, roundedDistance);

    // MetalEngine renders into a bgra8Unorm IOSurface. The reference renderer
    // used an sRGB drawable, so encode the linear material color explicitly.
    const float3 outputColor = walletCardMatchButtonColor(
        walletCardApplySaturation(
            walletCardLinearToSrgb(gradient + spark)
        )
    );
    return float4(outputColor * coverage, coverage);
}
