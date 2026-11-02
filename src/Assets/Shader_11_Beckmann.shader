Shader "Custom/Shader_11_Beckmann"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _Roughness("Roughness",Range(0,1))=0.5
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
                float3 normal :NORMAL;
                float4 tangent : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal : NORMAL;
                float3 position : TEXCOORD0;
                float4 tangent : TANGENT;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _Roughness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.position = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.tangent = float4(TransformObjectToWorldNormal(IN.tangent.xyz),IN.tangent.w);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 normal = normalize(IN.normal);
                half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0)) - IN.position);
                half3 half_vector = normalize(light.direction+view_direction);
                
                half VdotN = max(0,dot(view_direction,normal));
                half LdotN = max(0,dot(light.direction,normal));
                half HdotN = max(0,dot(half_vector,normal));

                half alpha2 = _Roughness * _Roughness * _Roughness * _Roughness;

                float D = exp(-(1-HdotN*HdotN)/(HdotN*HdotN*alpha2))/(4*alpha2*HdotN*HdotN*HdotN*HdotN);


                half3 color = D/(4*LdotN*VdotN);
                color = saturate(color);
                return half4(color,1);
            }
            ENDHLSL
        }
    }
}