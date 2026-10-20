Shader "Custom/Shader_8_Anisotropic"
{
     Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        //[MainTexture] _BaseMap("Base Map", 2D) = "white"
        _AmbientRate("Ambient Rate",Range(0,1))=0.2
        _RoughnessX("Roughness X",Range(0.000001,1))=0.8
        _RoughnessY("Roughness Y",Range(0.000001,1))=0.2
        _SpecularPower("Specular Power",Range(0.001,300))=80
        _SpecularIntensity("Specular Intensity",Range(0,1))=0.3
        _Metallic("Metallic",Range(0,1)) = 0.5
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
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                //float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float3 position : TEXCOORD0;
                //float2 uv : TEXCOORD0;
            };

            // TEXTURE2D(_BaseMap);
            // SAMPLER(sampler_BaseMap);


            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _AmbientRate;
                half _SpecularPower;
                half _SpecularIntensity;
                half _RoughnessX;
                half _RoughnessY;
                half _Metallic;
                //float4 _BaseMap_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.tangent = float4(TransformObjectToWorldNormal(float3(IN.tangent.xyz)).xyz,IN.tangent.w);
                OUT.position = TransformObjectToWorld(IN.positionOS.xyz);

                //OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                //return color;

                half3 normal = normalize(IN.normal);
                half3 binormal = normalize(cross(normal,IN.tangent.xyz)*IN.tangent.w);
                half3 tangent = cross(binormal,normal)*IN.tangent.w;
                
                Light light = GetMainLight();
                half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0)) - IN.position);
                float3  half_vector = normalize(view_direction + light.direction);
                half VdotN = max(0.000001, dot(view_direction, normal));
                half LdotN = max(0.000001, dot(light.direction, normal));
                half HdotN = max(0,dot(half_vector,normal));

                half alphaX = _RoughnessX * _RoughnessX;
                half alphaY = _RoughnessY * _RoughnessY;
                half XdotH = dot(tangent, half_vector);
                half YdotH = dot(binormal, half_vector);

                half3 ambient = _BaseColor.rgb;
                half3 lambert = _BaseColor.rgb * LdotN;
                half c = (XdotH*XdotH/(alphaX*alphaX) + YdotH*YdotH/(alphaY*alphaY))/(HdotN*HdotN);
                half3 specular = _SpecularIntensity * exp(-c) / sqrt(LdotN * VdotN) / (4 * PI *alphaX * alphaY);
                half3 color = light.color*lerp(lerp(lambert,ambient,_AmbientRate),specular,_Metallic);
                return half4 (color,1);
            }
            ENDHLSL
        }
    }
}
