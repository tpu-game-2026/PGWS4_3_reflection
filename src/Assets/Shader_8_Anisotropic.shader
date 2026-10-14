Shader "Custom/Shader_8_Anisotropic"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (0.86, 0.39, 0.39, 1)
        _SpecularIntensity("Specular Intensity", Range(0, 1)) = 0.3
        _AmbientRate("Ambient Rate", Range(0, 1)) = 0.2
        _RoughnessX("Roughness X", Range(0, 1)) = 0.2
        _RoughnessY("Roughness Y", Range(0, 1)) = 0.2
        _Metallic("Metallic", Range(0, 1)) = 0.5
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
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                half _SpecularIntensity;
                half _AmbientRate;
                half _RoughnessX;
                half _RoughnessY;
                half _Metallic;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv          = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.normalWS    = TransformObjectToWorldNormal(IN.normalOS);
                OUT.tangentWS   = float4(TransformObjectToWorldDir(IN.tangentOS.xyz), IN.tangentOS.w * GetOddNegativeScale());
                OUT.positionWS  = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normal        = normalize(IN.normalWS);
                half3 binormal      = normalize(cross(normal, IN.tangentWS.xyz) * IN.tangentWS.w);
                half3 tangent       = cross(binormal, normal) * IN.tangentWS.w;
                Light light         = GetMainLight();
                half3 viewDirection = normalize(GetWorldSpaceViewDir(IN.positionWS));
                half3 halfVector    = normalize(light.direction + viewDirection);
                half viewDotNormal  = max(0.000001h, dot(viewDirection, normal));
                half lightDotNormal = max(0.000001h, dot(light.direction, normal));
                half halfDotNormal  = max(0.000001h, dot(halfVector, normal));

                float alphaX = max(_RoughnessX * _RoughnessX, 0.001);
                float alphaY = max(_RoughnessY * _RoughnessY, 0.001);
                float tangentDotHalf  = dot(tangent, halfVector);
                float binormalDotHalf = dot(binormal, halfVector);
                float c = (tangentDotHalf * tangentDotHalf / (alphaX * alphaX)
                    + binormalDotHalf * binormalDotHalf / (alphaY * alphaY))
                    / (halfDotNormal * halfDotNormal);

                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half3 ambient  = baseColor.rgb;
                half3 lambert  = baseColor.rgb * lightDotNormal;
                half3 specular = _SpecularIntensity * exp(-c)
                    / sqrt(lightDotNormal * viewDotNormal)
                    / (4.0 * 3.14159265 * alphaX * alphaY);
                half3 color = light.color * lerp(lerp(lambert, ambient, _AmbientRate), specular, _Metallic);
                return half4(color, baseColor.a);
            }
            ENDHLSL
        }
    }
}
