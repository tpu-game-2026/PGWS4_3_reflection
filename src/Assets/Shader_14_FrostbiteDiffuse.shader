Shader "Custom/Shader_14_FrostbiteDiffuse"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (0.86, 0.39, 0.39, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _Fresnel0("Fresnel 0", Range(0, 1)) = 0.8
        _Roughness("Roughness", Range(0, 1)) = 0.4
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
                half _Roughness;
            CBUFFER_END

            half Fresnel(half f0, half f90, half co)
            {
                return f0 + (f90 - f0) * pow(1 - co, 5);
            }

            half3 Fr_DisneyDiffuse(half3 albedo, half lightDotNormal, half viewDotNormal, half lightDotHalf, half linearRoughness)
            {
                half energyBias = lerp(0.0, 0.5, linearRoughness);
                half energyFactor = lerp(1.0, 1.0 / 1.51, linearRoughness);
                half fresnel90 = energyBias + 2.0 * lightDotHalf * lightDotHalf * linearRoughness;
                half lightFresnel = Fresnel(1.0, fresnel90, lightDotNormal);
                half viewFresnel = Fresnel(1.0, fresnel90, viewDotNormal);
                return albedo * lightFresnel * viewFresnel * energyFactor;
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
                half viewDotNormal = saturate(dot(viewDirection, normal));
                half lightDotNormal = saturate(dot(light.direction, normal));
                half lightDotHalf = saturate(dot(light.direction, halfVector));
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half3 diffuse = Fr_DisneyDiffuse(baseColor.rgb, lightDotNormal, viewDotNormal, lightDotHalf, _Roughness * _Roughness);
                half3 color = light.color * lightDotNormal * diffuse / 3.14159265;
                return half4(color, baseColor.a);
            }
            ENDHLSL
        }
    }
}
