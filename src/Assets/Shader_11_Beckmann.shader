Shader "Custom/Shader_11_Beckmann"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (0.86, 0.39, 0.39, 1)
        _Roughness("Roughness", Range(0, 1)) = 0.4
        [MainTexture] _BaseMap("Base Map", 2D) = "white"
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

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv          = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.normalWS    = TransformObjectToWorldNormal(IN.normalOS);
                OUT.positionWS  = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light         = GetMainLight();
                half3 normal        = normalize(IN.normalWS);
                half3 viewDirection = normalize(GetWorldSpaceViewDir(IN.positionWS));
                half3 halfVector    = normalize(light.direction + viewDirection);
                float viewDotNormal = max(0.00001, dot(viewDirection, normal));
                float lightDotNormal = max(0.00001, dot(light.direction, normal));
                float halfDotNormal = max(0.0001, dot(halfVector, normal));

                float roughnessSquared = max(_Roughness * _Roughness, 0.001);
                float alpha2 = roughnessSquared * roughnessSquared;
                float halfDotNormalSquared = halfDotNormal * halfDotNormal;
                float distribution = exp(-(1 - halfDotNormalSquared)
                    / (halfDotNormalSquared * alpha2))
                    / (4 * alpha2 * halfDotNormalSquared * halfDotNormalSquared);
                float brdf = saturate(distribution / (4 * lightDotNormal * viewDotNormal));
                return half4(brdf, brdf, brdf, 1);
            }
            ENDHLSL
        }
    }
}
