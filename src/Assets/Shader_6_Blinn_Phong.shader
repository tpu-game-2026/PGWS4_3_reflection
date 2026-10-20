Shader "Custom/Shader_6_Blinn_Phong"
{    
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _AmbientRate("Ambient Rate", Range(0,1)) = 0.2
        _SpecularPower("Specular Power",Range(0.001,300)) = 80
        _SpecularIntensity("Specular Intensity", Range(0, 1)) = 0.3
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // í«â¡

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal : NORMAL;
                float3 position : TEXCOORDO;
            };


            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _AmbientRate;
                half _SpecularPower;
                half _SpecularIntensity;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.position = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // í«â¡
                Light light = GetMainLight();
                half3 normal = normalize(IN.normal); // ääÇÁÇ©Ç…Ç∑ÇÈÇΩÇﬂÇ…ê≥ãKâªÇµÇ»Ç®Ç∑
                half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0)) - IN.position);
                float3 half_vector = normalize(view_direction + light.direction);
                half HdotN = max(0,dot(half_vector,normal));

                half3 ambient = _BaseColor.rgb;
                half3 lambert = _BaseColor.rgb * max(0, dot(light.direction, normal));
                half3 specular = _SpecularIntensity * pow(HdotN, _SpecularPower);
                
                half3 color = light.color * (specular + lerp(lambert, ambient, _AmbientRate));                
                return half4(color,1);
            }
            ENDHLSL
        }
    }
}