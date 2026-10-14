Shader "Custom/Shader_9_Fresnel"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _Fresnel0("Fresnel 0 (RGB)", Color)         = (0.17, 0.17, 0.17, 1)
        [MainTexture] _BaseMap("Base Map", 2D)      = "white"
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
                half4  _BaseColor;
                float4 _BaseMap_ST;
                half4  _Fresnel0;
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
                half viewDotHalf    = saturate(dot(viewDirection, halfVector));
                half fresnelWeight  = pow(1 - viewDotHalf, 5);
                half3 fresnel       = _Fresnel0.rgb + (1 - _Fresnel0.rgb) * fresnelWeight;
                return half4(fresnel, 1);
            }
            ENDHLSL
        }
    }
}
