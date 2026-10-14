Shader "Custom/Shader_12_CookTorrance"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (0.86, 0.39, 0.39, 1)
        _Fresnel0("Fresnel 0", Range(0, 0.99999)) = 0.8
        _Roughness("Roughness", Range(0.0001, 1)) = 0.4
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
                half4 _BaseColor;
                half _Fresnel0;
                float _Roughness;
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
                half viewDotNormal  = max(0.00001, dot(viewDirection, normal));
                half lightDotNormal = max(0.00001, dot(light.direction, normal));
                half halfDotNormal  = max(0.00001, dot(halfVector, normal));
                half halfDotLight   = max(0.00001, dot(halfVector, light.direction));
                half halfDotView    = max(0.00001, dot(halfVector, viewDirection));

                float roughnessSquared = _Roughness * _Roughness;
                float alpha2 = max(roughnessSquared * roughnessSquared, 1e-8);
                float halfDotNormalSquared = (float)halfDotNormal * halfDotNormal;
                float D = exp(-(1 - halfDotNormalSquared)
                    / (halfDotNormalSquared * alpha2))
                    / (4 * alpha2 * halfDotNormalSquared * halfDotNormalSquared);
                half G = min(1, 2 * min(
                    halfDotNormal * viewDotNormal / halfDotView,
                    halfDotNormal * lightDotNormal / halfDotLight));
                half F = _Fresnel0 + (1 - _Fresnel0) * pow(1 - halfDotView, 5);
                half3 brdf = _BaseColor.rgb * (D * G * F)
                    / (4 * lightDotNormal * viewDotNormal);
                half3 color = light.color * lightDotNormal * brdf;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
