Shader "Custom/Shader_10_G"
{
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
                half viewDotNormal  = max(0, dot(viewDirection, normal));
                half lightDotNormal = max(0, dot(light.direction, normal));
                half halfDotNormal  = max(0, dot(halfVector, normal));
                half halfDotLight   = max(0.000001h, dot(halfVector, light.direction));
                half halfDotView    = max(0.000001h, dot(halfVector, viewDirection));

                half geometry = min(1, 2 * min(
                    halfDotNormal * viewDotNormal / halfDotView,
                    halfDotNormal * lightDotNormal / halfDotLight));
                return half4(geometry, geometry, geometry, 1);
            }
            ENDHLSL
        }
    }
}
