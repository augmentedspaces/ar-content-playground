//
//  earth.metal
//  DriftSolarSystem
//
//  Created by Sebastian Buys on 11/4/21.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;


[[visible]]
void passthroughSurfaceShader(realitykit::surface_parameters params)
{
    constexpr sampler samplerBilinear(coord::normalized,
                                      address::repeat,
                                      filter::linear,
                                      mip_filter::nearest);

    auto tex = params.textures();
    auto surface = params.surface();
    float2 uv = params.geometry().uv0();
    // USD textures require uvs to be flipped.
    uv.y = 1.0 - uv.y;

    half4 colorSample = tex.base_color().sample(samplerBilinear, uv);
    half4 emissiveSample = tex.emissive_color().sample(samplerBilinear, uv);

    // Color
    surface.set_base_color(colorSample.rgb * half3(params.material_constants().base_color_tint()));
    surface.set_emissive_color(max(emissiveSample.rgb, half3(params.material_constants().emissive_color())));

    // Opacity
    surface.set_opacity(tex.opacity().sample(samplerBilinear, uv).r
                        * params.material_constants().opacity_scale()
                        * colorSample.a);

    // Normal
    half3 normal = realitykit::unpack_normal(tex.normal().sample(samplerBilinear, uv).rgb);
    surface.set_normal(float3(normal));

    // Roughness and Metallic
    surface.set_roughness(tex.roughness().sample(samplerBilinear, uv).r
                          * params.material_constants().roughness_scale());
    surface.set_metallic(tex.metallic().sample(samplerBilinear, uv).r
                         * params.material_constants().metallic_scale());

    // Ambient and Specular
    surface.set_ambient_occlusion(tex.ambient_occlusion().sample(samplerBilinear, uv).r);
    surface.set_specular(tex.specular().sample(samplerBilinear, uv).r
                         * params.material_constants().specular_scale());
}


[[visible]]
void pulsingSurfaceShader(realitykit::surface_parameters params)
{
    float intensity = sin(params.uniforms().time());
    params.surface().set_base_color(half3(intensity));
}


[[visible]]
void myEmptyShader(realitykit::surface_parameters params)
{

}


float3 noise3D(float3 worldPos, float time) {
    float spatialScale = 8.0;
    return float3(sin(spatialScale * 1.1 * (worldPos.x + time)),
                  sin(spatialScale * 1.2 * (worldPos.y + time)),
                  sin(spatialScale * 1.2 * (worldPos.z + time)));
}

[[visible]]
void wrapGeometry(realitykit::geometry_parameters params)
{
    float3 worldPos = params.geometry().world_position();

    float phaseOffset = 3.0 * dot(params.geometry().world_position(), float3(0.7, 0.3, 0.7));
    float time = 0.1 * params.uniforms().time() + phaseOffset;
    float amplitude = 0.5;
    float3 maxOffset = noise3D(worldPos, time);
    float3 offset = maxOffset * amplitude * max(0.0, params.geometry().model_position().y);
    params.geometry().set_model_position_offset(offset);
}

