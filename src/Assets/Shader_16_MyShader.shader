// Shader_16_MyShader
// 異方性PBR + テクスチャ + 複数の反射モデル + 分散(波長依存)対応 (URP / Unity 6)
//  - 分布関数 D : GGX / Beckmann / Blinn-Phong(Ashikhmin-Shirley 異方性)
//  - フレネル   : 厳密(Fresnel方程式) / Schlick / FarCry
//  - 分散       : Cauchyの式 n(λ)=n0+B(1/λ²-1/λg²) をR/G/Bの代表波長で評価
//  - 干渉       : 薄膜干渉(Airy式)を波長ごとに評価 → 玉虫色(分散と連動)
//  - 環境光     : SH環境光 + リフレクションプローブ(異方性bent normal) + メインライト影
Shader "Custom/Shader_16_MyShader"
{
    Properties
    {
        [Header(Base)]
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map (Tiling/Offset共通)", 2D) = "white" {}
        [Normal][NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale("Normal Scale", Range(0, 2)) = 1
        [NoScaleOffset] _MetallicRoughnessMap("Metallic (R) Roughness (G) Occlusion (B)", 2D) = "white" {}
        _Metallic("Metallic", Range(0, 1)) = 0
        _Roughness("Roughness", Range(0.02, 1)) = 0.4
        _OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1
        _SpecularColor("Dielectric Specular Tint", Color) = (1, 1, 1, 1)

        [Header(Anisotropy)]
        [NoScaleOffset] _AnisotropyMap("Anisotropy Map (R)", 2D) = "white" {}
        _Anisotropy("Anisotropy", Range(-0.95, 0.95)) = 0
        _AnisotropyRotation("Anisotropy Rotation (deg)", Range(0, 180)) = 0

        [Header(Reflection Model)]
        [KeywordEnum(GGX, Beckmann, BlinnPhong)] _DistributionModel("Microfacet Distribution", Float) = 0
        [KeywordEnum(Exact, Schlick, FarCry)] _FresnelModel("Fresnel Model", Float) = 0
        _IOR("Index of Refraction", Range(1.01, 2.5)) = 1.5

        [Header(Dispersion and Thin Film)]
        _Dispersion("Dispersion (Cauchy B, um^2)", Range(0, 0.1)) = 0
        [Toggle(_IRIDESCENCE_ON)] _Iridescence("Thin Film Iridescence", Float) = 0
        _IridescenceStrength("Iridescence Strength", Range(0, 1)) = 1
        _FilmThickness("Film Thickness (nm)", Range(0, 1000)) = 400
        _FilmIOR("Film IOR", Range(1.1, 2.5)) = 1.45

        [Header(Emission)]
        [NoScaleOffset] _EmissionMap("Emission Map", 2D) = "white" {}
        [HDR] _EmissionColor("Emission", Color) = (0, 0, 0, 1)
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_BaseMap);              SAMPLER(sampler_BaseMap);
        TEXTURE2D(_NormalMap);            SAMPLER(sampler_NormalMap);
        TEXTURE2D(_MetallicRoughnessMap); SAMPLER(sampler_MetallicRoughnessMap);
        TEXTURE2D(_AnisotropyMap);        SAMPLER(sampler_AnisotropyMap);
        TEXTURE2D(_EmissionMap);          SAMPLER(sampler_EmissionMap);

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _BaseColor;
            float4 _SpecularColor;
            float4 _EmissionColor;
            float _NormalScale;
            float _Metallic;
            float _Roughness;
            float _OcclusionStrength;
            float _Anisotropy;
            float _AnisotropyRotation;
            float _IOR;
            float _Dispersion;
            float _IridescenceStrength;
            float _FilmThickness;
            float _FilmIOR;
        CBUFFER_END
        ENDHLSL


        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local_fragment _DISTRIBUTIONMODEL_GGX _DISTRIBUTIONMODEL_BECKMANN _DISTRIBUTIONMODEL_BLINNPHONG
            #pragma shader_feature_local_fragment _FRESNELMODEL_EXACT _FRESNELMODEL_SCHLICK _FRESNELMODEL_FARCRY
            #pragma shader_feature_local_fragment _IRIDESCENCE_ON
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH

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

            // 代表波長(nm) R/G/B と Cauchy 用(um)
            static const float3 kWavelengthNm = float3(650.0, 550.0, 450.0);

            float IORToF0(float ior)
            {
                float r = (ior - 1.0) / (ior + 1.0);
                return r * r;
            }

            float3 IORToF0(float3 ior)
            {
                float3 r = (ior - 1.0) / (ior + 1.0);
                return r * r;
            }

            // Cauchyの式: 緑(550nm)を基準IORに固定し、赤は低く青は高くなる
            float3 SpectralIOR(float baseIor, float cauchyB)
            {
                float3 lambdaUm = kWavelengthNm * 0.001;
                float3 invSq = 1.0 / (lambdaUm * lambdaUm);
                return max(baseIor + cauchyB * (invSq - invSq.y), 1.001);
            }

            float FresnelExact(float cosTheta, float f0)
            {
                cosTheta = clamp(cosTheta, 0.000001, 0.9999);
                float rootF0 = sqrt(saturate(f0));
                float n = (1.0 + rootF0) / max(1.0 - rootF0, 0.000001);
                float nSq = n * n;
                float tc = sqrt(max(nSq - (1.0 - cosTheta * cosTheta), 0.0));
                float rs = (cosTheta - tc) / (cosTheta + tc);
                float rp = (cosTheta - tc / nSq) / (cosTheta + tc / nSq);
                return 0.5 * (rs * rs + rp * rp);
            }

            float3 FresnelTerm(float3 f0, float cosTheta)
            {
                float m = saturate(1.0 - cosTheta);
                float m2 = m * m;
                #if defined(_FRESNELMODEL_SCHLICK)
                    return f0 + (1.0 - f0) * m2 * m2 * m;
                #elif defined(_FRESNELMODEL_FARCRY)
                    return f0 + (1.0 - f0) * exp(-6.0 * cosTheta);
                #else
                    return float3(FresnelExact(cosTheta, f0.r), FresnelExact(cosTheta, f0.g), FresnelExact(cosTheta, f0.b));
                #endif
            }

            // 薄膜干渉(空気 | 薄膜 | 基板)。Airy式で波長ごとに反射率を計算
            float3 ThinFilmFresnel(float cosTheta1, float3 baseF0, float3 filmIor, float thicknessNm)
            {
                cosTheta1 = clamp(cosTheta1, 0.0001, 1.0);
                float sin1Sq = 1.0 - cosTheta1 * cosTheta1;
                float3 cosTheta2 = sqrt(saturate(1.0 - sin1Sq / (filmIor * filmIor)));

                float3 f120 = IORToF0(filmIor);
                float3 F12 = float3(FresnelExact(cosTheta1, f120.r), FresnelExact(cosTheta1, f120.g), FresnelExact(cosTheta1, f120.b));
                float3 m = 1.0 - cosTheta2;
                float3 m2 = m * m;
                float3 F23 = baseF0 + (1.0 - baseF0) * m2 * m2 * m;

                float3 r12 = sqrt(F12);
                float3 r23 = sqrt(F23);
                float3 phase = 4.0 * PI * filmIor * thicknessNm * cosTheta2 / kWavelengthNm;
                float3 cross2 = 2.0 * r12 * r23 * cos(phase);
                return saturate((F12 + F23 + cross2) / (1.0 + F12 * F23 + cross2));
            }

            float3 Fresnel(float3 f0, float cosTheta, float3 filmIor)
            {
                float3 f = FresnelTerm(f0, cosTheta);
                #if defined(_IRIDESCENCE_ON)
                    f = lerp(f, ThinFilmFresnel(cosTheta, f0, filmIor, _FilmThickness), _IridescenceStrength);
                #endif
                return f;
            }

            float FresnelSchlickScalar(float f0, float f90, float cosTheta)
            {
                float m = saturate(1.0 - cosTheta);
                float m2 = m * m;
                return f0 + (f90 - f0) * m2 * m2 * m;
            }

            float3 DisneyDiffuse(float3 albedo, float NdotL, float NdotV, float LdotH, float linearRoughness)
            {
                float energyFactor = lerp(1.0, 1.0 / 1.51, linearRoughness);
                float fd90 = lerp(0.0, 0.5, linearRoughness) + 2.0 * LdotH * LdotH * linearRoughness;
                float lightF = FresnelSchlickScalar(1.0, fd90, NdotL);
                float viewF = FresnelSchlickScalar(1.0, fd90, NdotV);
                return albedo * lightF * viewF * energyFactor;
            }

            float D_GGX_Aniso(float NdotH, float TdotH, float BdotH, float ax, float ay)
            {
                float x = TdotH / ax;
                float y = BdotH / ay;
                float d = x * x + y * y + NdotH * NdotH;
                return 1.0 / max(PI * ax * ay * d * d, 1e-6);
            }

            float D_Beckmann_Aniso(float NdotH, float TdotH, float BdotH, float ax, float ay)
            {
                float x = TdotH / ax;
                float y = BdotH / ay;
                float nh2 = max(NdotH * NdotH, 1e-6);
                return exp(-(x * x + y * y) / nh2) / max(PI * ax * ay * nh2 * nh2, 1e-6);
            }

            // Blinn-Phong の異方性版 (Ashikhmin-Shirley)
            float D_BlinnPhong_Aniso(float NdotH, float TdotH, float BdotH, float ax, float ay)
            {
                float nu = max(2.0 / (ax * ax) - 2.0, 0.0);
                float nv = max(2.0 / (ay * ay) - 2.0, 0.0);
                float denom = max(1.0 - NdotH * NdotH, 1e-4);
                float exponent = (nu * TdotH * TdotH + nv * BdotH * BdotH) / denom;
                return sqrt((nu + 1.0) * (nv + 1.0)) / (2.0 * PI) * pow(max(NdotH, 1e-4), exponent);
            }

            // Smith G2 (高さ相関, 異方性)
            float G_Smith_Aniso(float NdotL, float NdotV, float TdotL, float BdotL, float TdotV, float BdotV, float ax, float ay)
            {
                float lL = 0.5 * (sqrt(1.0 + (ax * ax * TdotL * TdotL + ay * ay * BdotL * BdotL) / max(NdotL * NdotL, 1e-6)) - 1.0);
                float lV = 0.5 * (sqrt(1.0 + (ax * ax * TdotV * TdotV + ay * ay * BdotV * BdotV) / max(NdotV * NdotV, 1e-6)) - 1.0);
                return 1.0 / (1.0 + lL + lV);
            }

            // Karis の環境BRDF近似
            float3 EnvBRDFApprox(float3 f0, float roughness, float NdotV)
            {
                const float4 c0 = float4(-1.0, -0.0275, -0.572, 0.022);
                const float4 c1 = float4(1.0, 0.0425, 1.04, -0.04);
                float4 r = roughness * c0 + c1;
                float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
                float2 ab = float2(-1.04, 1.04) * a004 + r.zw;
                return f0 * ab.x + ab.y;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.tangentWS = float4(TransformObjectToWorldDir(IN.tangentOS.xyz), IN.tangentOS.w * GetOddNegativeScale());
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // ---- テクスチャ ----
                float2 uv = IN.uv;
                float4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;
                float3 mro = SAMPLE_TEXTURE2D(_MetallicRoughnessMap, sampler_MetallicRoughnessMap, uv).rgb;
                float anisoMask = SAMPLE_TEXTURE2D(_AnisotropyMap, sampler_AnisotropyMap, uv).r;
                float3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor.rgb;

                float3 albedo = baseSample.rgb;
                float metallic = saturate(_Metallic * mro.r);
                float roughness = clamp(_Roughness * mro.g, 0.02, 1.0);
                float occlusion = lerp(1.0, mro.b, _OcclusionStrength);
                float anisotropy = clamp(_Anisotropy * anisoMask, -0.95, 0.95);

                // ---- 接空間フレーム ----
                float3 Ng = normalize(IN.normalWS);
                float3 T = normalize(IN.tangentWS.xyz - Ng * dot(Ng, IN.tangentWS.xyz));
                float3 B = cross(Ng, T) * IN.tangentWS.w;
                float3 nTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv), _NormalScale);
                float3 N = normalize(T * nTS.x + B * nTS.y + Ng * nTS.z);
                T = normalize(T - N * dot(N, T));
                B = cross(N, T) * IN.tangentWS.w;

                // 異方性の向きを回転
                float s, c;
                sincos(radians(_AnisotropyRotation), s, c);
                float3 Tr = c * T + s * B;
                float3 Br = c * B - s * T;
                T = Tr;
                B = Br;

                // ---- ベクトル ----
                float3 V = normalize(GetWorldSpaceViewDir(IN.positionWS));
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light light = GetMainLight(shadowCoord);
                float3 L = normalize(light.direction);
                float3 H = normalize(L + V);

                float NdotL = saturate(dot(N, L));
                float NdotV = max(dot(N, V), 1e-4);
                float NdotH = max(dot(N, H), 1e-4);
                float LdotH = saturate(dot(L, H));
                float VdotH = saturate(dot(V, H));
                float TdotH = dot(T, H);
                float BdotH = dot(B, H);

                // ---- 分散: 波長ごとのIOR ----
                float3 iorRGB = SpectralIOR(_IOR, _Dispersion);
                float3 filmIorRGB = SpectralIOR(_FilmIOR, _Dispersion);
                float3 dielectricF0 = IORToF0(iorRGB) * _SpecularColor.rgb;
                float3 F0 = lerp(dielectricF0, albedo, metallic);

                // ---- 異方性ラフネス ----
                float alpha = roughness * roughness;
                float aspect = sqrt(1.0 - 0.9 * abs(anisotropy));
                float ax = max(alpha / aspect, 0.001);
                float ay = max(alpha * aspect, 0.001);
                if (anisotropy < 0.0)
                {
                    float tmp = ax;
                    ax = ay;
                    ay = tmp;
                }

                // ---- 直接光 ----
                float D;
                #if defined(_DISTRIBUTIONMODEL_BECKMANN)
                    D = D_Beckmann_Aniso(NdotH, TdotH, BdotH, ax, ay);
                #elif defined(_DISTRIBUTIONMODEL_BLINNPHONG)
                    D = D_BlinnPhong_Aniso(NdotH, TdotH, BdotH, ax, ay);
                #else
                    D = D_GGX_Aniso(NdotH, TdotH, BdotH, ax, ay);
                #endif
                float G = G_Smith_Aniso(NdotL, NdotV, dot(T, L), dot(B, L), dot(T, V), dot(B, V), ax, ay);
                float3 F = Fresnel(F0, VdotH, filmIorRGB);
                float3 specular = D * G * F / max(4.0 * NdotL * NdotV, 1e-4);
                float3 diffuse = DisneyDiffuse(albedo * (1.0 - metallic), NdotL, NdotV, LdotH, alpha) / PI;

                // URPのライト色はπ込みの慣習なのでπを掛けて Lit と明るさを揃える
                float3 radiance = light.color * (light.distanceAttenuation * light.shadowAttenuation) * NdotL * PI;
                float3 color = (diffuse + specular) * radiance;

                // ---- 環境光 ----
                float3 ambient = SampleSH(N) * albedo * (1.0 - metallic) * occlusion;

                // 異方性を反映した反射ベクトル(bent normal)
                float3 anisoDir = (anisotropy >= 0.0) ? B : T;
                float3 anisoTangent = cross(anisoDir, V);
                float3 anisoNormal = cross(anisoTangent, anisoDir);
                float3 bentNormal = normalize(lerp(N, anisoNormal, abs(anisotropy)));
                float3 R = reflect(-V, bentNormal);

                float mip = PerceptualRoughnessToMipmapLevel(roughness);
                float4 encoded = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, R, mip);
                float3 envColor = DecodeHDREnvironment(encoded, unity_SpecCube0_HDR);

                float3 F0Env = F0;
                #if defined(_IRIDESCENCE_ON)
                    F0Env = lerp(F0, ThinFilmFresnel(NdotV, F0, filmIorRGB, _FilmThickness), _IridescenceStrength);
                #endif
                float3 envSpecular = envColor * EnvBRDFApprox(F0Env, roughness, NdotV) * occlusion;

                color += ambient + envSpecular + emission;
                return float4(color, 1.0);
            }
            ENDHLSL
        }


        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct ShadowVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            ShadowVaryings ShadowVert(ShadowAttributes IN)
            {
                ShadowVaryings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
                #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif
                OUT.positionCS = positionCS;
                return OUT;
            }

            half4 ShadowFrag(ShadowVaryings IN) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }


        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthVert
            #pragma fragment DepthFrag

            struct DepthAttributes
            {
                float4 positionOS : POSITION;
            };

            struct DepthVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            DepthVaryings DepthVert(DepthAttributes IN)
            {
                DepthVaryings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half DepthFrag(DepthVaryings IN) : SV_Target
            {
                return IN.positionCS.z;
            }
            ENDHLSL
        }
    }
}
