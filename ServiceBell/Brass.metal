#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Polished brass seen from straight above. For every pixel the shader works out which way the surface faces,
// mirrors the view direction about it and looks up what the bar around the bell would show in that direction.
//
// World axes: x to the right, y down the screen (toward the near edge of the counter), z up toward the viewer.

// Where the pendant lamp hangs: above the upper left, high up. Keep in step with the bell's cast shadow.
constant float3 lampDirection = float3(-0.42, -0.52, 0.74);

/// How much of a soft, rounded light reaches direction (`azimuth`, `elevation`): full in the middle, fading out
/// smoothly on every side. `center` and `halfSize` are (azimuth, elevation) in radians.
static float softLight(float azimuth, float elevation, float2 center, float2 halfSize) {
    float2 q = (float2(azimuth, elevation) - center) / halfSize;
    float distance = pow(pow(abs(q.x), 4.0) + pow(abs(q.y), 4.0), 0.25); // rounded rectangle
    return smoothstep(1.0, 0.0, distance);
}

/// What the bar looks like in direction `r`: a warm, fairly bright ceiling (brighter on the lamp's side),
/// walls along the horizon, the counter below, the pendant lamp, a window, and a soft back-bar light.
static float3 environment(float3 r) {
    float azimuth = atan2(r.y, r.x); // 0 = right, pi/2 = toward the viewer
    float elevation = asin(clamp(r.z, -1.0, 1.0));

    float3 walls = float3(0.045, 0.04, 0.034);
    float towardLamp = 0.5 + 0.5 * dot(normalize(r.xy + 1e-5), normalize(lampDirection.xy));
    float3 ceiling = mix(walls, float3(0.78, 0.74, 0.66) * (0.6 + 0.5 * towardLamp), smoothstep(0.1, 0.9, r.z));
    float3 counter = mix(walls, float3(0.10, 0.08, 0.06), towardLamp);
    float3 color = mix(counter, ceiling, smoothstep(-0.05, 0.05, r.z));

    float3 warmLight = float3(1.0, 0.92, 0.78);
    float facing = dot(r, normalize(lampDirection));
    color += warmLight * (8.0 * smoothstep(0.935, 0.965, facing) + 1.2 * pow(saturate(facing), 8.0));

    color += float3(1.0, 0.96, 0.9) * 1.1 * softLight(azimuth, elevation, float2(-0.95, 0.55), float2(0.40, 0.34));
    color += warmLight * 0.9 * softLight(azimuth, elevation, float2(2.2, 0.62), float2(0.85, 0.30));
    return color;
}

/// - `shape` 0: the dome, a gently rounded cap turned on a lathe (fine rings ripple its surface).
///   `shape` 1: the knob, a flat button whose edge rounds off.
/// - `darken` dims the result, e.g. while the knob is pushed down.
[[ stitchable ]] half4 brass(float2 position, half4 color, float2 size, float shape, float darken) {
    if (color.a == 0.0h) return color;

    float2 p = position / size * 2.0 - 1.0;
    float rho = length(p);
    float2 outward = rho > 1e-4 ? p / rho : float2(0.0);
    float2 slope;
    if (shape < 0.5) {
        float lathe = sin(rho * 540.0) * 0.6 + sin(rho * 1370.0 + 1.7) * 0.4;
        slope = p * 0.78 + outward * lathe * 0.005;
    } else {
        float edge = smoothstep(0.80, 1.0, rho);
        slope = outward * edge * edge * 0.65;
    }
    float3 n = normalize(float3(slope, sqrt(max(1.0 - dot(slope, slope), 0.0))));
    float3 r = reflect(float3(0.0, 0.0, -1.0), n);

    // Metals tint what they reflect: deep orange-brown where little light reaches, bright yellow where much does.
    // At grazing angles the tint fades a little toward white (Schlick's Fresnel, toned down).
    float exposure = 3.0;
    float3 light = environment(r) * exposure;
    float brightness = saturate(dot(light, float3(0.2126, 0.7152, 0.0722)) / 2.0);
    float3 f0 = mix(float3(1.0, 0.50, 0.07), float3(1.0, 0.72, 0.16), brightness);
    float3 fresnel = f0 + (1.0 - f0) * 0.5 * pow(1.0 - saturate(n.z), 5.0);
    float3 c = light * fresnel * (1.0 - darken);

    // Roll off by luminance so the gold stays saturated; only the hottest spots bleach toward white
    float luminance = dot(c, float3(0.2126, 0.7152, 0.0722));
    c = mix(c / (1.0 + luminance), c / (1.0 + c), saturate(luminance - 1.5));
    c = pow(saturate(c), 1.0 / 2.2); // to display gamma
    return half4(half3(c) * color.a, color.a);
}
