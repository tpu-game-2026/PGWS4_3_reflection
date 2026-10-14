Shader "Custom/Shader_13_GGX"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (0.86, 0.39, 0.39, 1)
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
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                half4  _BaseColor;
                half   _Fresnel0;
                float  _Roughness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
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
                float viewDotNormal  = max(0.00001, dot(viewDirection, normal));
                float lightDotNormal = max(0.00001, dot(light.direction, normal));
                float halfDotNormal  = max(0.00001, dot(halfVector, normal));
                float halfDotView = saturate(dot(halfVector, viewDirection));

                float roughnessSquared = _Roughness * _Roughness;
                float alpha2 = max(roughnessSquared * roughnessSquared, 1e-8);
                float halfDotNormalSquared = halfDotNormal * halfDotNormal;
                float denom = halfDotNormalSquared * (alpha2 - 1.0) + 1.0;
                float D = alpha2 / (PI * denom * denom);
                half G = min(1, 1
                    / (viewDotNormal + sqrt(alpha2 + (1.0 - alpha2) * viewDotNormal * viewDotNormal))
                    / (lightDotNormal + sqrt(alpha2 + (1.0 - alpha2) * lightDotNormal * lightDotNormal)));
                float fresnel = _Fresnel0 + (1 - _Fresnel0) * pow(1 - halfDotView, 5);
                half3 brdf = saturate(_BaseColor.rgb * (D * G * fresnel)
                    / (4 * lightDotNormal * viewDotNormal));
                half3 color = light.color * lightDotNormal * brdf;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
