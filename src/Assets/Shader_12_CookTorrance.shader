Shader "Custom/Shader_12_CookTorrance"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _Fresnel0("Fresnel0",Range(0,0.9999))=0.8
        _Roughness("Roughness",Range(0.001,1))=0.5
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
                half _Fresnel0;
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

                half3 VdotN = max(0.0001,dot(view_direction,normal));
                half3 LdotN = max(0.0001,dot(light.direction,normal));
                half3 HdotN = max(0.0001,dot(half_vector,normal));
                half LdotH = max(0,dot(half_vector,light.direction));
                half VdotH = max(0,dot(half_vector,view_direction)); 

                float3 reflected_direction = -light.direction +2*normal *dot(light.direction,normal);
                //float3 reflected_direction = reflect(-light.direction,normal);

                half alpha2 = _Roughness * _Roughness * _Roughness * _Roughness;

                float D = exp(-(1-HdotN*HdotN)/(HdotN*HdotN*alpha2))/
                (4*alpha2*HdotN*HdotN*HdotN*HdotN);

                half G = min(1,2*min(HdotN*VdotN/VdotH,HdotN*LdotN/LdotH));

                half F = _Fresnel0 + (1-_Fresnel0)*pow(1-VdotH,5);

                half3 brdf = _BaseColor*D*G*F/(4*LdotN*VdotN);

                half3 color = light.color * LdotN * brdf;
                return half4(color,1);
            }
            ENDHLSL
        }
    }
}
