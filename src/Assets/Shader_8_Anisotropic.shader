Shader "Custom/Shader_8_Anisotropic"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _AmbientRate("Ambient Rate",Range(0,1))=0.2
        _SpecularPower("Specular Power",Range(0.001,300))=80
        _SpecularIntensity("Specular Intensity",Range(0,1))=0.3
        _Metallic("Metallic",Range(0,1))=0.5
        _RoughnessX("Roughness X",Range(0,1))=0.8
        _RoughnessY("Roughness Y",Range(0,1))=0.2
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
                float4 _BaseMap_ST;
                half _AmbientRate;
                half _SpecularPower;
                half _SpecularIntensity;
                half _Metallic;
                half _RoughnessX;
                half _RoughnessY;
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
                half3 binormal = normalize(cross(normal,IN.tangent.xyz) * IN.tangent.w);
                half3 tangent = cross(binormal,normal)*IN.tangent.w;
                half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0)) - IN.position);
                half3 half_vector = normalize(light.direction+view_direction);

                half3 VdotN = max(0.000001,dot(view_direction,normal));
                half3 LdotN = max(0.000001,dot(light.direction,normal));
                half3 HdotN = max(0.000001,dot(half_vector,normal));

                float3 reflected_direction = -light.direction +2*normal *dot(light.direction,normal);
                //float3 reflected_direction = reflect(-light.direction,normal);

                half alphaX = _RoughnessX*_RoughnessX;
                half alphaY = _RoughnessY*_RoughnessY;
                half XdotH = dot(tangent,half_vector);
                half YdotH = dot(binormal,half_vector);

                half3 ambient = _BaseColor.rgb;
                half3 lambert = _BaseColor.rgb * LdotN;
                half3 c = (XdotH*XdotH/(alphaX*alphaX) + YdotH*YdotH/(alphaY*alphaY))/(HdotN*HdotN);
                half3 specular = _SpecularIntensity*exp(-c) / sqrt(LdotN*VdotN) / (4*PI*alphaX*alphaY);
                half3 color = light.color * 
                lerp(lerp(lambert,ambient,_AmbientRate),specular,_Metallic);
                return half4(color,1);
            }
            ENDHLSL
        }
    }
}
