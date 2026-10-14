Shader "Custom/Shader_7_Metallic"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _AmbientRate("Ambient Rate", Range(0, 1)) = 0.2
        _SpecularPower("Specular Power", Range(0.001, 300)) = 80
        _SpecularIntensity("Specular Intensity", Range(0, 1)) = 0.3
        _Metallic("Metallic", Range(0, 1)) = 1
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
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                half _AmbientRate;
                half _SpecularPower;
                half _SpecularIntensity;
                half _Metallic;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half3 normal = normalize(IN.normalWS);
                half3 viewDirection = normalize(GetWorldSpaceViewDir(IN.positionWS));
                half3 halfVector = normalize(viewDirection + light.direction);
                half halfDotNormal = max(0, dot(halfVector, normal));

                half3 ambient = baseColor.rgb;
                half3 lambert = baseColor.rgb * max(0, dot(light.direction, normal));
                half3 specular = _SpecularIntensity * pow(halfDotNormal, _SpecularPower);
                half3 color = light.color * lerp(lerp(lambert, ambient, _AmbientRate), specular, _Metallic);
                return half4(color, baseColor.a);
            }
            ENDHLSL
        }
    }
}
