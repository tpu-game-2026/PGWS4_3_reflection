Shader "Custom/Shader_10_G"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
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
