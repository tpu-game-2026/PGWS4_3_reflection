Shader "Custom/Shader_15_PBR"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (0.86, 0.39, 0.39, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
        _Emission("Emission", Color) = (0, 0, 0, 0)
        _Fresnel0("Fresnel 0", Range(0, 0.99999)) = 0.8
        _Roughness("Roughness", Range(0, 1)) = 0.4
        _Metallic("Metallic", Range(0, 1)) = 0.6
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
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                half4 _SpecularColor;
                half4 _Emission;
                half _Fresnel0;
                half _Roughness;
                half _Metallic;
            CBUFFER_END

            float FresnelReflectanceAverageDielectric(float cosTheta, float f0, float f90)
            {
                cosTheta = clamp(cosTheta, 0.000001, 0.9999);
                float rootF0 = sqrt(saturate(f0));
                float rootF90 = sqrt(saturate(f90));
                float n = (rootF90 + rootF0) / max(rootF90 - rootF0, 0.000001);
                float nSquared = n * n;
                float sinThetaSquared = 1 - cosTheta * cosTheta;
                float transmittedCosine = sqrt(max(nSquared - sinThetaSquared, 0));
                float transmittedOverNSquared = transmittedCosine / nSquared;
                float reflectanceS = (cosTheta - transmittedCosine) / (cosTheta + transmittedCosine);
                float reflectanceP = (cosTheta - transmittedOverNSquared) / (cosTheta + transmittedOverNSquared);
                return 0.5 * f90 * (reflectanceS * reflectanceS + reflectanceP * reflectanceP);
            }

            half Fresnel(half f0, half f90, float cosTheta)
            {
                return FresnelReflectanceAverageDielectric(cosTheta, f0, f90);
            }

            half FresnelSchlick(half f0, half f90, half cosTheta)
            {
                half oneMinusCosine = 1 - cosTheta;
                half oneMinusCosineSquared = oneMinusCosine * oneMinusCosine;
                return f0 + (f90 - f0) * oneMinusCosineSquared * oneMinusCosineSquared * oneMinusCosine;
            }

            half3 Fr_DisneyDiffuse(half3 albedo, half lightDotNormal, half viewDotNormal, half lightDotHalf, half linearRoughness)
            {
                half energyBias = lerp(0.0, 0.5, linearRoughness);
                half energyFactor = lerp(1.0, 1.0 / 1.51, linearRoughness);
                half fresnel90 = energyBias + 2.0 * lightDotHalf * lightDotHalf * linearRoughness;
                half lightFresnel = FresnelSchlick(1.0, fresnel90, lightDotNormal);
                half viewFresnel = FresnelSchlick(1.0, fresnel90, viewDotNormal);
                return albedo * lightFresnel * viewFresnel * energyFactor;
            }

            float V_SmithGGXCorrelated(float NdotL, float NdotV, float alphaG2)
            {
                float lambdaV = NdotL * sqrt(max((NdotV - NdotV * alphaG2) * NdotV + alphaG2, 0));
                float lambdaL = NdotV * sqrt(max((NdotL - NdotL * alphaG2) * NdotL + alphaG2, 0));
                return 0.5 / max(lambdaV + lambdaL, 0.000001);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 normal = normalize(IN.normalWS);
                half3 viewDirection = normalize(GetWorldSpaceViewDir(IN.positionWS));
                half3 halfVector = normalize(light.direction + viewDirection);
                half lightDotNormal = saturate(dot(light.direction, normal));
                half viewDotNormal = max(0.00001, dot(viewDirection, normal));
                half halfDotNormal = saturate(dot(halfVector, normal));
                half lightDotHalf = saturate(dot(light.direction, halfVector));
                half viewDotHalf = saturate(dot(viewDirection, halfVector));
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;

                half alpha = _Roughness * _Roughness;
                float alphaG2 = max(alpha * alpha, 0.000001);
                float denominator = halfDotNormal * halfDotNormal * (alphaG2 - 1.0) + 1.0;
                float distribution = alphaG2 / (3.14159265 * denominator * denominator);
                float visibility = V_SmithGGXCorrelated(max(lightDotNormal, 0.00001), viewDotNormal, alphaG2);
                half fresnel = Fresnel(_Fresnel0, 1.0, viewDotHalf);

                half3 diffuse = Fr_DisneyDiffuse(baseColor.rgb, lightDotNormal, viewDotNormal, lightDotHalf, alpha) / 3.14159265;
                half3 specular = saturate(_SpecularColor.rgb * distribution * visibility * fresnel);
                half3 color = light.color * lightDotNormal * lerp(diffuse, specular, _Metallic);
                color += _Emission.rgb;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
