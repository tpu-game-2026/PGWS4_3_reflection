Shader "Custom/Shader_16_PBR"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
        _Emission("Emission", Color) = (0, 0, 0, 0)
        _Fresnel0("Frenel0", Range(0, 1)) = 0.8
        _Roughness("Roughness", Range(0, 1)) = 0.05
        _Metallic ("Metallic", Range(0, 1)) = 1

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
                float2 uv : TEXCOORD0;
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionHCS : SV_POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float3 position : TEXCOORD1;
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
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.uv = IN.uv;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.tangent = float4(TransformObjectToWorldNormal(float3(IN.tangent.xyz)).xyz, IN.tangent.w);
                OUT.position = TransformObjectToWorld(IN.positionOS. xyz);
                return OUT;
            }

            half FresnelReflectanceAverageDislectric(float co, float f0, float f90)
            {
                co = min(0.9999, max(0.000001, co));

                float root_f0 = sqrt(f0);
                float root_f90 = sqrt(f90);
                float n = (root_f90 + root_f0) / (root_f90 - root_f0);
                float n2 = n*n;
                
                float si2 = 1 - co * co;
                float nb = sqrt(n2 - si2);
                float bn = nb /n2;
                float r_s = (co - nb) / (co + nb);
                float r_p = (co - bn) / (co + bn);
                return 0.5 * f90 * (r_s * r_s + r_p * r_p );
            }

            half Fresnel(half f0, half f90, float co)
            {
                return f0 + (f90-f0) * pow(1 - co, 5);
            }

            half3 Fr_DisneyDiffuse(half3 albedo, half LdotN, half VdotN, half LdotH, half linearRoughness)
            {
                half enegyBias = lerp(0.0, 0.5, linearRoughness);
                half enegyFactor = lerp(1.0, 1.0/1.51, linearRoughness);
                half Fd90 = enegyBias + 2.0 * LdotH * LdotH * linearRoughness;
                half FL = Fresnel(1, Fd90, LdotN);
                half FV = Fresnel(1, Fd90, VdotN);
                return (albedo * FL * FV * enegyFactor);
            }

            float V_SmithGGXCorrelated(float NdotL, float NdotV, float alphaG2)
            {
                float Lambda_GGXV = NdotL * sqrt((-NdotV * alphaG2 + NdotV) * NdotV + alphaG2);
                float Lambda_GGXL = NdotV * sqrt((-NdotL * alphaG2 + NdotL) * NdotL + alphaG2);
                return 0.5f / (Lambda_GGXV + Lambda_GGXL);
            }

            half4 frag(Varyings IN) : SV_Target
            {
               Light light = GetMainLight();
               half3 normal = normalize(IN.normal);
               half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0))-IN.position);
               half3 half_vector = normalize(light.direction + view_direction);

               half VdotN = max(0.00001, dot(view_direction, normal));
               half LdotN = max(0.0, dot(light.direction, normal));
               half HdotN = max(0.0, dot(half_vector, normal));
               half LdotH = max(0, dot(half_vector, light.direction));
               half VdotH = max(0, dot(half_vector, view_direction));

               half alpha = _Roughness * _Roughness;

               half alpha2 = alpha * alpha;
               float D = alpha2 / (PI * pow(HdotN * HdotN * (alpha2 - 1.0) + 1.0, 2.0));
               half G =V_SmithGGXCorrelated(LdotN, VdotN, alpha2);
               
               half3 F;
               F.r = Fresnel(_Fresnel0 * 1.5, 1, VdotH);
               F.g = Fresnel(_Fresnel0,       1, VdotH);
               F.b = Fresnel(_Fresnel0 * 0.5, 1, VdotH);
               half3 specular = saturate(_SpecularColor.rgb * D * G * F / (4 * LdotN * VdotN));

               half3 rainbow;
               float rings = length(IN.uv - 0.5);
               rainbow.r = sin(rings * 800.0);
               rainbow.g = sin(rings * 800.0 + 2.09);
               rainbow.b = sin(rings * 800.0 + 4.18);
               rainbow = rainbow * 0.5 + 0.5;
               specular *= rainbow * 5.0;

               half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
               half3 diffuse = Fr_DisneyDiffuse(tex.rgb, LdotN, VdotN, LdotH, alpha) / PI;

               half3 color = light.color * LdotN * (diffuse * 0.1 + specular);
               color += _Emission;
               return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
