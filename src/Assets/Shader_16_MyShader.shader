Shader "Custom/Shader_16_MyShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _SpecularColor("Specular Color",Color)=(1,1,1,1)
        _Emission("Emission",Color)=(0,0,0,0)
        _Fresnel0("Fresnel0",Range(0,0.9999))=0.8
        _Roughness("Roughness",Range(0.001,1))=0.5
        _Metallic("Metallic",Range(0,1))=0.5

        _RainbowScale("Rainbow Scale", Range(0.1, 5)) = 1
        _RainbowOffset("Rainbow Offset", Range(0, 1)) = 0

        _FresnelPower("Fresnel Power", Range(0.5, 8)) = 3
        _FresnelIntensity("Fresnel Intensity", Range(0, 5)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal :NORMAL;
                float4 tangent : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal : NORMAL;
                float3 position : TEXCOORD0;
                float4 tangent : TANGENT;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _SpecularColor;
                half4 _Emission;
                half _Fresnel0;
                half _Roughness;
                half _Metallic;
                half _RainbowScale;
                half _RainbowOffset;
                half _FresnelPower;
                half _FresnelIntensity;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.position = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.tangent = float4(TransformObjectToWorldNormal(IN.tangent.xyz),IN.tangent.w);
                return OUT;
            }

            half3 HSVToRGB(half3 c)
            {
                half4 K = half4(1.0,2.0 / 3.0,1.0 / 3.0,3.0);

                half3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);

                return c.z * lerp(K.xxx,saturate(p - K.xxx),c.y);
            }

            half Fresnel(half f0,half f90,float co)
            {
                return f0 + (f90-f0)*pow(1-co,5);
            }
            half3 FresnelRGB(half3 f0,half f90,float co)
            {
                return f0 + (f90.xxx - f0) *pow(1 - saturate(co), 5);
            }

            half3 Fr_DisneyDiffuse(half3 albedo,half LdotN,half VdotN,half LdotH,half linearRoughness)
            {
                half energyBias = lerp(0.0,0.5,linearRoughness);
                half energyFactor = lerp(1.0,1.0/1.51,linearRoughness);
                half Fd90 = energyBias + 2.0*LdotH*LdotH*linearRoughness;
                half FL = Fresnel(1.0,Fd90,LdotN);
                half FV = Fresnel(1.0,Fd90,VdotN);
                return (albedo*FL*FV*energyFactor);
            }

            half DistributionGGX(half NdotH,half roughness)
            {
                half alpha2 = roughness *roughness *roughness *roughness;

                half demon =NdotH * NdotH * (alpha2 - 1.0) + 1.0;

                return alpha2 /max(PI * demon * demon, 0.0001);
            }

            half GeometryGGX(half NdotV,half NdotL,half roughness)
            {
                half alpha2 = roughness *roughness *roughness *roughness;

                half Gv = 1.0 /(NdotV + sqrt(alpha2 + (1.0 - alpha2) *NdotV * NdotV));

                half Gl = 1.0 /(NdotL + sqrt(alpha2 + (1.0 - alpha2) *NdotL * NdotL));

                return min(1.0, Gv * Gl);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Normalize
                half3 normal = normalize(IN.normal);

                half3 view_direction = normalize(
                    GetWorldSpaceViewDir(IN.position)
                );

                // Main Light
                Light light = GetMainLight();

                half3 light_direction =
                    normalize(light.direction);

                half3 half_vector = normalize(
                    light_direction + view_direction
                );

                // Dot Products
                half VdotN = saturate(
                    dot(view_direction, normal)
                );

                half LdotN = saturate(
                    dot(light_direction, normal)
                );

                half HdotN = saturate(
                    dot(half_vector, normal)
                );

                half LdotH = saturate(
                    dot(half_vector, light_direction)
                );

                half VdotH = saturate(
                    dot(half_vector, view_direction)
                );

                // =================================
                // 1. Rainbow Color
                // =================================

                half hue = frac(
                    (1.0 - VdotN) * _RainbowScale
                    + _RainbowOffset
                );

                half3 rainbowColor = HSVToRGB(
                    half3(hue, 0.9, 1.0)
                );

                // =================================
                // 2. Disney Diffuse
                // =================================

                half3 diffuse = Fr_DisneyDiffuse(
                    _BaseColor.rgb,
                    LdotN,
                    VdotN,
                    LdotH,
                    _Roughness * _Roughness
                ) / PI;

                // =================================
                // 3. GGX
                // =================================

                half D = DistributionGGX(
                    HdotN,
                    _Roughness
                );

                // =================================
                // 4. Geometry
                // =================================

                half G = GeometryGGX(
                    VdotN,
                    LdotN,
                    _Roughness
                );

                // =================================
                // 5. Rainbow Fresnel
                // =================================

                half3 F0 = lerp(
                    _Fresnel0.xxx,
                    rainbowColor,
                    _Metallic
                );

                half3 F = FresnelRGB(
                    F0,
                    1.0,
                    VdotH
                );

                // =================================
                // 6. Cook-Torrance Specular
                // =================================

                half3 specular =
                    _SpecularColor.rgb *
                    D * G * F /
                    max(4.0 * LdotN * VdotN, 0.001);

                // =================================
                // 7. Metallic
                // =================================

                half3 brdf = lerp(
                    diffuse,
                    specular,
                    _Metallic
                );

                half3 color =
                    light.color * LdotN * brdf;

                // =================================
                // 8. Fresnel Rim Emission
                // =================================

                half fresnel = pow(
                    1.0 - VdotN,
                    _FresnelPower
                );

                half3 rimEmission =
                    rainbowColor *
                    fresnel *
                    _FresnelIntensity;

                // =================================
                // 9. Final Color
                // =================================

                color += _Emission.rgb;
                color += rimEmission;

                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
