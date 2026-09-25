#include <metal_stdlib>
using namespace metal;

struct GramDiamondCompositeRaster {
    float4 position [[position]];
    float2 uv;
};

vertex GramDiamondCompositeRaster gramDiamondCompositeVertex(
    constant float4 &rect [[buffer(0)]], uint vertexID [[vertex_id]]) {
    const float2 vertices[6] = {
        float2(0, 0), float2(1, 0), float2(0, 1),
        float2(1, 0), float2(0, 1), float2(1, 1)
    };
    float2 point = vertices[vertexID];
    GramDiamondCompositeRaster out;
    out.position = float4((rect.xy + point * rect.zw) * 2 - 1, 0, 1);
    out.uv = float2(point.x, 1 - point.y);
    return out;
}

fragment float4 gramDiamondCompositeFragment(GramDiamondCompositeRaster in [[stage_in]],
                                             texture2d<float> scene [[texture(0)]]) {
    constexpr sampler sceneSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    return scene.sample(sceneSampler, in.uv);
}

struct StarUniforms {
    float4x4 projection;
    float4 animation; // burst age, transport time, burst enabled, light background
    float4 layout; // viewport pixels, steady instance count, burst seed
};
struct BackgroundStarRaster {
    float4 position [[position]];
    float2 uv;
    float4 color [[flat]];
    float haloOpacity [[flat]];
};

float starRandom(uint seed) {
    seed ^= seed >> 16; seed *= 0x7feb352du;
    seed ^= seed >> 15; seed *= 0x846ca68bu;
    seed ^= seed >> 16;
    return float(seed & 0x00ffffffu) / 16777216.0;
}

vertex BackgroundStarRaster backgroundStarVertex(uint vertexIndex [[vertex_id]], uint instance [[instance_id]],
                                                 constant StarUniforms &u [[buffer(0)]]) {
    const float2 corners[6] = {float2(-1,-1),float2(1,-1),float2(-1,1),
                              float2(-1,1),float2(1,-1),float2(1,1)};
    uint seed = instance*127u + 9137u;
    bool burst = instance >= uint(u.layout.z);
    if (burst) {
        seed += uint(u.layout.w)*104729u;
    }
    float lifetime = mix(4.5,7.5,starRandom(seed+1));
    float clock = u.animation.y + starRandom(seed+2)*lifetime;
    uint cycle = uint(floor(clock/lifetime));
    float age = fmod(clock,lifetime);
    if (burst) {
        const float burstDurationScale = 2.0;
        lifetime = mix(1.8,3.2,starRandom(seed+1));
        age = u.animation.x / burstDurationScale;
        cycle = 0;
    }
    seed += cycle*7919u;
    float progress = saturate(age/lifetime);
    float alive = float(age >= 0 && age < lifetime) * (burst ? u.animation.z : 1);
    float fadeIn = burst ? smoothstep(0.0,0.25,age) : smoothstep(0,0.10,progress);
    float fade = fadeIn * (1-smoothstep(0.62,1.0,progress)) * alive;
    float depth = mix(0.60,1.0,starRandom(seed+3));
    float sector = starRandom(seed+4);
    float spread = starRandom(seed+14);
    const float verticalSpread = 0.78;
    float lowerFanAngle = atan(tan(-M_PI_F/6.0)/verticalSpread);
    float elevation = sector < 0.85 ? mix(lowerFanAngle,0.34,spread) : mix(0.52,1.40,spread);
    float side = starRandom(seed+15) < 0.5 ? -1.0 : 1.0;
    float2 direction = float2(side*cos(elevation),sin(elevation));
    float distance;
    if (burst) {
        float travelTime = max(age,0.0);
        float baseSpeed = mix(4.8,7.2,starRandom(seed+5));
        float initialSpeed = baseSpeed * 1.40;
        float cruiseSpeed = baseSpeed * 0.30;
        const float slowdownTime = 0.40;
        distance = mix(0.10,0.32,starRandom(seed+13)) + cruiseSpeed*travelTime
            + (initialSpeed-cruiseSpeed)*slowdownTime*(1-exp(-travelTime/slowdownTime));
    } else {
        distance = 0.32 + age*mix(0.38,0.63,starRandom(seed+5));
    }
    float drift = sin(age*0.85+starRandom(seed+6)*6.28) * (burst ? 0.06 : 0.16);
    float2 center = direction*distance + float2(-direction.y,direction.x)*drift;
    center *= float2(1,verticalSpread)*depth;
    const float emissionHeight = -0.10;
    center.y += emissionHeight + mix(-0.26,0.24,starRandom(seed+16))*depth;
    if (!burst) {
        float travel = length(direction*float2(1,verticalSpread))*distance*depth;
        float behavior = starRandom(seed+17);
        if (behavior < 0.34) {
            float dimStart = mix(0.76,0.90,starRandom(seed+18));
            float dimEnd = dimStart + mix(0.16,0.22,starRandom(seed+19));
            float returnStart = dimEnd + mix(0.04,0.09,starRandom(seed+20));
            float returnEnd = returnStart + mix(0.14,0.22,starRandom(seed+21));
            float endStart = returnEnd + mix(0.05,0.12,starRandom(seed+22));
            float end = endStart + mix(0.18,0.28,starRandom(seed+23));
            float firstGlow = 1-smoothstep(dimStart,dimEnd,travel);
            float secondGlow = smoothstep(returnStart,returnEnd,travel)
                * (1-smoothstep(endStart,end,travel));
            fade *= firstGlow + secondGlow;
        } else if (behavior < 0.62) {
            float revealStart = mix(0.86,1.10,starRandom(seed+18));
            float revealEnd = revealStart + mix(0.20,0.34,starRandom(seed+19));
            fade *= smoothstep(revealStart,revealEnd,travel);
        }
    }
    float breathPeriod = mix(2.0,3.4,starRandom(seed+24));
    float breathPhase = age*(2*M_PI_F/breathPeriod) + starRandom(seed+25)*2*M_PI_F;
    float breathWave = 0.5-0.5*cos(breathPhase);
    float shine = smoothstep(0.0,1.0,fade) * mix(0.12,1.0,breathWave);
    const float starSizeScale = 1.53;
    float radius = starSizeScale * mix(0.0228,0.084,pow(starRandom(seed+7),1.7))*depth * mix(0.87,1.0,shine);
    fade *= smoothstep(0.72, 1.02, length(center));
    float rotation = starRandom(seed+8)*1.57 + age*mix(-0.20,0.20,starRandom(seed+9));
    float2 uv = corners[vertexIndex]*1.45;
    float2 point = float2(cos(rotation)*uv.x-sin(rotation)*uv.y,
                          sin(rotation)*uv.x+cos(rotation)*uv.y)*radius;
    float choice = starRandom(seed+10);
    float3 darkColor = choice < 0.22 ? float3(0.045,0.36,1) :
                      (choice < 0.50 ? float3(0,0.451,1) :
                      (choice < 0.82 ? float3(0,0.639,1) : float3(0.145,0.792,1)));
    float iridescence = smoothstep(0.12,1.0,shine);
    darkColor = mix(darkColor,float3(0.247,0.894,1),iridescence*0.30);
    float3 lightColor = darkColor * 0.78;
    BackgroundStarRaster out;
    out.position = u.projection*float4(center+point,-1.6-depth,1);
    out.uv = uv;
    out.color = float4(mix(darkColor,lightColor,u.animation.w),
                       fade*mix(0.52,0.95,starRandom(seed+11))*mix(0.80,1.0,depth));
    out.haloOpacity = mix(0.075,0.035,u.animation.w);
    return out;
}

fragment float4 backgroundStarFragment(BackgroundStarRaster in [[stage_in]]) {
    float2 p = abs(in.uv);
    float distance = sqrt(max(p.x,0.00001))+sqrt(max(p.y,0.00001))-1;
    float aa = max(fwidth(distance),0.04);
    float core = 1-smoothstep(-aa,aa,distance);
    float glow = exp(-dot(in.uv,in.uv)*4.5)*in.haloOpacity;
    float alpha = saturate(core+glow)*in.color.a;
    return float4(in.color.rgb*alpha,alpha);
}

struct Vertex { float4 position; float4 normal; float4 surface; };
struct Uniforms {
    float4x4 model;
    float4x4 projection;
    float4x4 inverseModel;
    float4 parameters; // time, refraction, brightness, sparkles
    float4 viewport;   // width, height, optical plane count, unused
    float4 sparkleShape; // main layer scale, contour morph, core scale, star glow scale
    float4 sparkleHalo;  // circular glow scale, main anchor angle/height, visibility
    float4 crownGradient;
    float4 pavilionGradient;
    float4 lightSweep; // diagonal position, environment phase, transmission, reserved
    float4 crownSweep;
    float4 rightCrownSweep;
    float4 leftCrownSweep;
    float4 pavilionSweep;
    float4 rightPavilionSweep;
    float4 leftPavilionSweep;
};
struct Raster {
    float4 position [[position]];
    float3 localPosition;
    float3 normal;
    float3 worldPosition;
    float3 facetWeights; // table, crown, pavilion; interpolated across rounded edges
};

float3 referenceCrown(float2 p, float4 gradient) {
    const float stops[7] = {0, 0.162, 0.324, 0.501, 0.667, 0.833, 1};
    const float3 colors[7] = {float3(0.145,0.792,1), float3(0.373,0.875,1),
        float3(0.6,0.957,1), float3(0.3,0.798,1), float3(0,0.639,1),
        float3(0,0.545,1), float3(0,0.451,1)};
    float2 start = gradient.xy, direction = gradient.zw - start;
    float t = saturate(dot(p-start, direction) / dot(direction,direction));
    for (uint i = 1; i < 7; ++i) {
        if (t <= stops[i]) { return mix(colors[i-1], colors[i], (t-stops[i-1])/(stops[i]-stops[i-1])); }
    }
    return colors[6];
}

float3 referencePavilion(float2 p, float4 gradient) {
    const float greens[9] = {0.502,0.557,0.612,0.545,0.478,0.633,0.788,0.600,0.412};
    float2 direction = gradient.zw - gradient.xy;
    float t = saturate(dot(p-gradient.xy,direction)/dot(direction,direction)) * 8;
    uint i = min(uint(t), 7u);
    return float3(0, mix(greens[i],greens[i+1],t-float(i)), 1);
}

float3 lateralDepth(float3 color, float3 normal, float y, float3 facetWeights,
                    float opticalLuminance) {
    float horizontalNormal = length(normal.xz);
    float side = smoothstep(0.22, 0.80, abs(normal.x) / max(horizontalNormal, 0.001));
    float shoulder = smoothstep(0.06, 0.57, y);
    float lower = smoothstep(0.12, 0.90, -y);
    float reflectedLight = smoothstep(0.28, 0.78, color.g);
    float3 deepBlue = float3(0.008, 0.125, 1.0)
                    * float3(1.0, mix(0.30, 1.0, reflectedLight), mix(0.88, 1.0, reflectedLight));
    float3 sideColor = mix(deepBlue, float3(0.247, 0.894, 1.0), shoulder * 0.80);
    sideColor = mix(sideColor, float3(0.02, 0.42, 1.0), lower * 0.65);
    float reflectionDetail = 0.12 + opticalLuminance * 0.16
                           + smoothstep(0.70, 0.95, color.g) * 0.25;
    sideColor = mix(sideColor, color, reflectionDetail);
    float weight = side * 0.96 * (1.0 - facetWeights.x);
    return mix(color, sideColor, weight);
}

float3 facetBarycentric(float2 p, float2 a, float2 b, float2 c) {
    float2 v = b-a, w = c-a, q = p-a;
    float determinant = v.x*w.y - v.y*w.x;
    float y = (q.x*w.y - q.y*w.x) / determinant;
    float z = (v.x*q.y - v.y*q.x) / determinant;
    return float3(1-y-z, y, z);
}

float facetCoverage(float3 barycentric) {
    float edge = min(barycentric.x, min(barycentric.y, barycentric.z));
    float aa = max(fwidth(edge), 0.0001);
    return smoothstep(-aa, aa, edge);
}

float3 illustratedFacets(float3 color, Raster in, constant Uniforms &u) {
    float3 localNormal = normalize((u.inverseModel * float4(normalize(in.normal), 0)).xyz);
    float3 tangent = float3(localNormal.z, 0, -localNormal.x);
    tangent /= max(length(tangent), 0.0001);
    float x = dot(in.localPosition, tangent) * 225.8 + 257.8;
    float3 worldTangent = (u.model * float4(tangent, 0)).xyz;
    float3 n = normalize(in.normal);
    float3 light = normalize(float3(0.6*sin(u.lightSweep.y), 0.5, 1));
    float leftLight = pow(saturate(dot(normalize(n - worldTangent*0.38), light)), 5.0);
    float rightLight = pow(saturate(dot(normalize(n + worldTangent*0.38), light)), 5.0);
    if (in.facetWeights.y > 0) {
        float2 p = float2(x, 240.8 + (0.025-in.localPosition.y)*239);
        float3 left = facetBarycentric(p, float2(142.1,106.3), float2(253.8,168.9), float2(108.8,240.7));
        float leftStrength = facetCoverage(left) * (0.18 + 0.40*leftLight) * saturate(1-left.y);
        color = mix(color, float3(0.79,0.988,1), leftStrength * in.facetWeights.y);
        float3 right = facetBarycentric(p, float2(406.8,240.8), float2(258.8,128.9), float2(378.5,108.2));
        float3 tint = mix(float3(0.008,0.30,1), float3(0.72,0.988,1),
                          saturate(right.z*0.75 + rightLight*0.35));
        color = mix(color, tint, facetCoverage(right) * 0.64 * in.facetWeights.y);
    }
    if (in.facetWeights.z > 0) {
        float2 p = float2(x, 240.7 + (-0.045-in.localPosition.y)*235);
        float left = max(facetCoverage(facetBarycentric(p, float2(131.8,224),float2(212.8,224),float2(253.8,327))),
                         facetCoverage(facetBarycentric(p, float2(131.8,224),float2(253.8,327),float2(171.8,326))));
        float right = max(facetCoverage(facetBarycentric(p, float2(316.8,224),float2(391.8,224),float2(338.8,336))),
                          facetCoverage(facetBarycentric(p, float2(316.8,224),float2(338.8,336),float2(273.8,360))));
        float fade = 1-smoothstep(275.0,365.0,p.y);
        color = mix(color, float3(0.39,0.92,1), left*fade*(0.16+0.36*leftLight)*in.facetWeights.z);
        color = mix(color, float3(0.24,0.84,1), right*fade*(0.16+0.38*rightLight)*in.facetWeights.z);
        float3 tipLeft = facetBarycentric(p, float2(258.8,375),float2(204.8,396),float2(258.8,479));
        float3 tipRight = facetBarycentric(p, float2(258.8,375),float2(258.8,479),float2(312.8,396));
        color = mix(color, float3(0.71,0.988,1), facetCoverage(tipLeft)*(0.18+0.42*leftLight)*in.facetWeights.z);
        color = mix(color, float3(0.12,0.63,1), facetCoverage(tipRight)*0.48*in.facetWeights.z);
        float3 inner = facetBarycentric(p, float2(258.8,407),float2(220.8,427),float2(258.8,479));
        color = mix(color, float3(0.02,0.40,1), facetCoverage(inner)*0.36*in.facetWeights.z);
    }
    return color;
}

vertex Raster diamondVertex(uint id [[vertex_id]], const device Vertex *vertices [[buffer(0)]],
                            constant Uniforms &u [[buffer(1)]]) {
    Vertex v = vertices[id];
    float4 world = u.model * v.position;
    Raster out;
    out.position = u.projection * world;
    out.localPosition = v.position.xyz;
    out.normal = normalize((u.model * v.normal).xyz);
    out.worldPosition = world.xyz;
    out.facetWeights = v.surface.z == 3 ? float3(v.surface.xy, 1-v.surface.x-v.surface.y)
        : float3(v.surface.z == 0, v.surface.z == 1, v.surface.z == 2);
    return out;
}

float3 studio(float3 d, float phase) {
    float angle = 0.85 * sin(phase);
    d.xz = float2(cos(angle)*d.x - sin(angle)*d.z, sin(angle)*d.x + cos(angle)*d.z);
    float up = smoothstep(-0.65, 0.85, d.y);
    float3 c = mix(float3(0.002, 0.075, 0.88), float3(0.19, 0.78, 1.0), up);
    float key = pow(saturate(dot(d, normalize(float3(-0.6, 0.8, 0.7)))), 10.0);
    float stripPosition = 0.12 + 0.48 * sin(phase);
    float strip = exp(-pow((d.x + d.y * 0.42 - stripPosition) * 9.0, 2.0));
    float side = pow(saturate(dot(d, normalize(float3(0.8, 0.2, -0.5)))), 18.0);
    c = mix(c, float3(0.68, 0.98, 1.0), key * 0.94);
    c = mix(c, float3(0.80, 0.99, 1.0), strip * 0.64);
    c += side * float3(0.1, 0.3, 0.38);
    return c;
}

float nearestExit(float3 origin, float3 ray, const device float4 *planes, uint count,
                  thread float3 &normal) {
    float nearest = 1e5;
    for (uint i = 0; i < count; ++i) {
        float denominator = dot(planes[i].xyz, ray);
        if (denominator > 0.0001) {
            float t = -(dot(planes[i].xyz, origin) + planes[i].w) / denominator;
            if (t > 0.001 && t < nearest) { nearest = t; normal = planes[i].xyz; }
        }
    }
    return nearest;
}

float4 oppositeFacets(float3 p, float3 ray, constant Uniforms &u,
                      const device float4 *planes) {
    float3 origin = p + ray*0.004;
    float3 normal = float3(0,1,0);
    float distance = nearestExit(origin,ray,planes,uint(u.viewport.z),normal);
    if (distance > 100 || normal.y > 0.95) { return 0; }
    float3 hit = origin + ray*distance;
    float3 worldNormal = (u.model*float4(normal,0)).xyz;
    float3 tangent = normalize(float3(normal.z+0.00001,0,-normal.x));
    float across = dot(hit,tangent);
    float2 authored = float2(across*225.8, (normal.y > 0 ? 0.3065-hit.y : -0.54-hit.y)*239);
    float3 color = normal.y > 0 ? referenceCrown(authored,u.crownGradient)
                               : referencePavilion(authored,u.pavilionGradient);
    float response = pow(saturate(dot(worldNormal, normalize(float3(0.7*sin(u.lightSweep.y),0.55,-1)))),4.0);
    color = mix(color*float3(0.45,0.70,0.98), float3(0.60,0.94,1), response*0.55);
    float coverage = smoothstep(0.03,0.35,distance) * exp(-distance*0.16);
    return float4(color,coverage);
}

float sourceBand(float2 p, float4 gradient) {
    float2 direction = gradient.zw-gradient.xy;
    float t = dot(p-gradient.xy,direction)/dot(direction,direction);
    return saturate(1-abs(t-0.49)/0.49);
}

float facetSweep(Raster in, float3 localNormal, constant Uniforms &u) {
    float3 tangent = normalize(float3(localNormal.z+0.00001,0,-localNormal.x));
    float across = dot(in.localPosition,tangent)*225.8;
    float side = smoothstep(0.20,0.50,abs(normalize(in.normal).x));
    bool right = in.normal.x > 0;
    float4 crown = mix(u.crownSweep, right ? u.rightCrownSweep : u.leftCrownSweep, side);
    float4 pavilion = mix(u.pavilionSweep, right ? u.rightPavilionSweep : u.leftPavilionSweep, side);
    return sourceBand(float2(across,(0.3065-in.localPosition.y)*239),crown)*in.facetWeights.y
         + sourceBand(float2(across,(-0.54-in.localPosition.y)*235),pavilion)*in.facetWeights.z;
}

float3 interior(float3 p, float3 direction, constant Uniforms &u,
                const device float4 *planes) {
    float3 accumulated = 0;
    float weight = 0.60;
    float3 origin = p + direction * 0.004;
    for (uint bounce = 0; bounce < 2; ++bounce) {
        float3 n = float3(0, 1, 0);
        float distance = nearestExit(origin, direction, planes, uint(u.viewport.z), n);
        if (distance > 100) { break; }
        float3 hit = origin + direction * distance;
        float3 outgoing = refract(direction, -n, 1.62);
        float3 reflection = reflect(direction, n);
        bool totalReflection = dot(outgoing, outgoing) < 0.01;
        float3 sampleDirection = totalReflection ? reflection : outgoing;
        sampleDirection = normalize((u.model * float4(sampleDirection, 0)).xyz);
        float3 color = studio(sampleDirection, u.lightSweep.y);
        color *= exp(-float3(0.30, 0.07, 0.006) * distance);
        accumulated += weight * color;
        weight *= 0.52;
        direction = reflection;
        origin = hit + direction * 0.004;
    }
    return accumulated;
}

fragment float4 diamondFragment(Raster in [[stage_in]], constant Uniforms &u [[buffer(1)]],
                                const device float4 *planes [[buffer(2)]]) {
    float3 n = normalize(in.normal);
    float3 view = float3(0, 0, 1);
    float3 localView = (u.inverseModel * float4(-view, 0)).xyz;
    float3 localNormal = normalize((u.inverseModel * float4(n, 0)).xyz);
    float3 transmitted = refract(localView, localNormal, 1.0 / 1.62);
    float3 optical = interior(in.localPosition, transmitted, u, planes);
    float3 reflection = studio(reflect(-view, n), u.lightSweep.y);
    float fresnel = 0.08 + 0.46 * pow(1.0 - saturate(dot(n, view)), 4.0);

    float height = saturate((in.localPosition.y + 1.05) / 1.65);
    float key = saturate(dot(n, normalize(float3(-0.65, 0.85, 1.0))));
    float left = saturate(0.52 - in.worldPosition.x * 0.43);
    float3 blue = float3(0.008, 0.22, 1.0);
    float3 cyan = float3(0.29, 0.87, 1.0);
    float3 body = mix(blue, cyan, saturate(key * 0.60 + left * 0.38));
    float verticalBand = 0.5 + 0.5 * sin(height * 18.0 + n.x * 3.0);
    body *= mix(float3(0.24, 0.48, 0.96), float3(1), verticalBand * 0.5 + 0.5);
    float opticalLuminance = smoothstep(0.25, 0.85, optical.g);
    optical = mix(float3(0.005, 0.13, 1.0), float3(0.58, 0.97, 1.0), opticalLuminance);
    float opticalWeight = u.parameters.y * mix(1.0, 0.58, in.facetWeights.y);
    float3 color = mix(body, optical, opticalWeight);
    color = mix(color, reflection, fresnel);

    float crownGlow = smoothstep(0.10, 0.60, in.localPosition.y) * left;
    color = mix(color, float3(0.70, 0.99, 1.0), crownGlow * 0.86);
    float crownLight = pow(saturate(dot(n, normalize(float3(-0.38, 0.55, 1.0)))), 9.0);
    crownLight *= smoothstep(-0.03, 0.28, in.localPosition.y);
    color = mix(color, float3(0.65, 0.98, 1.0), crownLight * 0.66);
    float3 facetBase = color;
    if (in.facetWeights.y > 0) {
        float softbox = exp(-pow((in.worldPosition.x + 0.42) * 1.6, 2.0)
                           -pow((in.worldPosition.y - 0.32) * 2.2, 2.0));
        color = mix(color, float3(0.71, 0.99, 1.0), softbox * crownLight * 0.63);
        float shadow = pow(saturate(1.0 - key), 1.4);
        color = mix(color, float3(0.015, 0.08, 1.0), shadow * 0.7);
        float3 tangent = normalize(float3(localNormal.z, 0, -localNormal.x));
        float2 authoredPosition = float2(dot(in.localPosition, tangent) * 225.8 + n.x * 65,
                                         (0.3065 - in.localPosition.y) * 244);
        color = mix(referenceCrown(authoredPosition, u.crownGradient), color, 0.28);
        color = mix(facetBase, color, in.facetWeights.y);
    }
    if (in.facetWeights.z > 0) {
        float3 tangent = float3(localNormal.z, 0, -localNormal.x);
        tangent /= max(length(tangent), 0.0001);
        float2 authoredPosition = float2(dot(in.localPosition, tangent) * 225.8 + n.x * 45,
                                         (-0.54 - in.localPosition.y) * 230);
        color += (mix(referencePavilion(authoredPosition, u.pavilionGradient), facetBase, 0.55) - facetBase) * in.facetWeights.z;
    }
    float facetFlash = smoothstep(0.20, 0.78, opticalLuminance);
    color *= mix(float3(0.76, 0.82, 0.99), float3(1), facetFlash);
    color = mix(color, float3(0.66, 0.98, 1), pow(facetFlash, 2.0) * 0.24);
    color = lateralDepth(color, n, in.localPosition.y, in.facetWeights, opticalLuminance);
    float3 rearRay = normalize(mix(localView,transmitted,0.18));
    float4 rear = oppositeFacets(in.localPosition,rearRay,u,planes);
    float transmission = (0.12+u.lightSweep.z*0.65) * u.parameters.y;
    float facing = smoothstep(0.12,0.65,n.z);
    color = mix(color,rear.rgb,rear.a*transmission*facing);
    float tipGlow = pow(saturate((-in.localPosition.y - 0.55) / 0.50), 2.0);
    color = mix(color, float3(0.57, 0.96, 1.0), tipGlow * 0.65);
    color = illustratedFacets(color, in, u);
    if (in.facetWeights.z > 0) {
        float angle = atan2(in.localPosition.x, in.localPosition.z);
        float across = fract((angle - M_PI_F / 8.0) / (M_PI_F / 4.0));
        float along = saturate((-in.localPosition.y - 0.06) / 0.96);
        float width = 0.018 + 0.095 * sin(along * M_PI_F);
        float sliver = exp(-pow((across - 0.20 - along * 0.22) / width, 2.0));
        sliver *= pow(sin(along * M_PI_F), 3.0);
        float lighting = pow(saturate(dot(n, normalize(float3(-0.35, -0.25, 1.0)))), 3.0);
        color = mix(color, float3(0.83, 0.99, 1.0), sliver * lighting * 0.90 * in.facetWeights.z);
    }
    color = mix(color, float3(0.63, 0.96, 1), 0.58 * in.facetWeights.x);
    float3 tableNormal = float3(0,1,0);
    float tableDistance = nearestExit(in.localPosition+localView*0.004,localView,
                                     planes,uint(u.viewport.z),tableNormal);
    float table = smoothstep(0.94,0.99,tableNormal.y) * float(tableDistance < 100);
    color = mix(color,float3(0.765,0.988,1),table*(0.57+u.lightSweep.z*0.35)
                *saturate(u.parameters.y/0.72)*in.facetWeights.y);
    color = mix(color,float3(0.592,0.953,1),facetSweep(in,localNormal,u)*0.94);
    float specular = pow(saturate(dot(reflect(-normalize(float3(-0.5, 0.9, 1.4)), n), view)), 75.0);
    color += float3(0.7, 0.91, 1) * specular * 0.48;
    return float4(saturate(color * u.parameters.z), 1);
}

struct SparkleVertex { float4 contours; float4 material; };
struct SparkleRaster {
    float4 position [[position]];
    float2 sourcePoint;
    float strength [[flat]];
    uint layer [[flat]];
};

vertex SparkleRaster sparkleVertex(uint id [[vertex_id]], uint instance [[instance_id]],
                                   const device SparkleVertex *vertices [[buffer(0)]],
                                   constant Uniforms &u [[buffer(1)]],
                                   const device float4 *planes [[buffer(2)]]) {
    SparkleVertex v = vertices[id];
    uint layer = uint(v.material.x);
    float angle = float(instance) * M_PI_F / 4.0 + M_PI_F / 8.0;
    float y = instance % 3 == 0 ? 0.56 : (instance % 3 == 1 ? -0.02 : -0.54);
    const float authoringToWorld = 2.0 / 447.9;
    if (instance == 0) {
        angle = u.sparkleHalo.y;
        y = u.sparkleHalo.z;
    }
    float3 normal = float3(0, 0, 1);
    float3 origin = float3(0, y, 0);
    float3 ray = float3(sin(angle), 0, cos(angle));
    float distance = nearestExit(origin, ray, planes, uint(u.viewport.z), normal);
    float3 local = origin + ray * distance + normal * 0.008;
    float3 worldNormal = (u.model * float4(normal, 0)).xyz;
    float pulse = pow(max(0.0, sin(u.parameters.x * 2.1 + float(instance) * 2.37 + 1.5)), 16.0);
    float front = instance == 0 ? u.sparkleHalo.w : smoothstep(0.15, 0.55, worldNormal.z);
    float strength = front * u.parameters.w;
    float4 center = u.projection * u.model * float4(local, 1);
    if (u.viewport.w > 0) {
        center = float4(0, 0, 0.5, 1);
        strength = instance == 0 ? u.parameters.w : 0;
    }
    float morph = instance == 0 ? u.sparkleShape.y : 0;
    float2 sourcePoint = mix(v.contours.xy, v.contours.zw, morph);
    float groupScale = 1;
    float2 offset = 0;
    if (layer == 0) { groupScale = u.sparkleHalo.x; offset.y = 5.9; }
    if (layer == 1) { groupScale = u.sparkleShape.w; offset.y = -0.8; }
    if (layer == 2) { groupScale = u.sparkleShape.z; offset.y = -0.9; }
    if (layer == 3) { groupScale = 0.309; offset = float2(0.6, -0.4); }
    float mainEnvelope = u.viewport.w > 0 ? 1.0 : u.sparkleHalo.w;
    float scale = instance == 0 ? u.sparkleShape.x * mainEnvelope : (0.632 / 0.75) * pulse;
    float2 point = (sourcePoint * groupScale + offset) * authoringToWorld * scale;
    SparkleRaster out;
    out.position = center + float4(point.x * u.projection[0][0], -point.y * u.projection[1][1], 0, 0);
    out.sourcePoint = sourcePoint;
    out.strength = strength;
    out.layer = layer;
    return out;
}

float radialOpacity(float radius, float first, float middle) {
    if (radius <= first) { return 1; }
    if (radius <= middle) { return mix(1.0, 0.5, (radius-first)/(middle-first)); }
    return 0.5 * saturate((1-radius)/(1-middle));
}

fragment float4 sparkleFragment(SparkleRaster in [[stage_in]]) {
    float alpha = 1;
    float3 color = 1;
    if (in.layer == 0) {
        float r = length(in.sourcePoint - float2(-0.5, 0.2)) / 108.5;
        alpha = radialOpacity(r, 0.312, 0.624) * 0.60;
    } else if (in.layer == 1) {
        float r = length(in.sourcePoint - float2(-0.5, 0.9)) / 113.1;
        alpha = radialOpacity(r, 0.297, 0.503) * 0.60;
        color = float3(0.82, 1, 0.902);
    } else if (in.layer == 2) {
        alpha = 0.96;
    } else if (in.layer == 3) {
        float r = saturate(length(in.sourcePoint) / length(float2(176, -170)));
        alpha = 1 - r;
        color = mix(float3(0.694, 0.969, 1), float3(0.663, 0.957, 1), r);
    }
    alpha *= in.strength;
    return float4(color * alpha, alpha);
}
