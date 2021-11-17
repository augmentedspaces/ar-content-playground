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
void myGeometryModifier(realitykit::geometry_parameters params)
{
    float3 zOffset = float3(0.0, 0.0, params.uniforms().time() / 50.0);
    params.geometry().set_world_position_offset(zOffset);
}


[[visible]]
void mySurfaceShader(realitykit::surface_parameters params)
{
    constexpr sampler samplerBilinear(coord::normalized,
                                      address::repeat,
                                      filter::linear,
                                      mip_filter::nearest);
    
    // Retrieve the base color tint from the entity's material.
    half3 baseColorTint = (half3)params.material_constants().base_color_tint();
    
    // Retrieve the entity's texture coordinates.
    float2 uv = params.geometry().uv0();

    // Flip the texture coordinates y-axis. This is only needed for entities
    // loaded from USDZ or .reality files.
    uv.y = 1.0 - uv.y;
    
    // Sample a value from the material's base color texture based on the
    // flipped UV coordinates.
    auto tex = params.textures();
    half3 color = (half3)tex.base_color().sample(samplerBilinear, uv).rgb;
    
    // Multiply the tint by the sampled value from the texture, and
    // assign the result to the shader's base color property.
    color *= baseColorTint;
    params.surface().set_base_color(color);
}



float3 noise3D(float3 worldPos, float time) {
    float spatialScale = 8.0;
    return float3(sin(spatialScale * 1.1 * (worldPos.x + time)),
                  sin(spatialScale * 1.2 * (worldPos.y + time)),
                  sin(spatialScale * 1.2 * (worldPos.z + time)));
}

[[visible]]
void seaweedGeometry(realitykit::geometry_parameters params)
{
    float3 worldPos = params.geometry().world_position();

    float phaseOffset = 3.0 * dot(params.geometry().world_position(), float3(0.7, 0.3, 0.7));
    float time = 0.1 * params.uniforms().time() + phaseOffset;
    float amplitude = 0.5;
    float3 maxOffset = noise3D(worldPos, time);
    float3 offset = maxOffset * amplitude * max(0.0, params.geometry().model_position().y);
    params.geometry().set_model_position_offset(offset);
}

