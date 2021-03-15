Shader "Unlit/PCFReceiver" 
{
    Properties 
    {
        _maxBias("Max Bias",Range(0,0.001)) = 0
        _baseBias("Base Bias", Range(0,0.001)) = 0
        _FilterSize("Filter Size", float) = 1
        [Toggle]_UsePoissionDisk("Use Poission",float) = 0
        [Toggle]_UseLINEAR("Use LINEAR",float) = 0
        [Toggle]_UseStratified("Use Stratified",float) = 0
    }

    SubShader 
    {
        Tags { "RenderType"="Opaque" }
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float4 worldPos : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float3 posL : TEXCOORD2;
            };


            float4x4 SHADOW_MAP_VP;
            sampler2D ShadowMapTexture;
            float4 ShadowMapTexture_TexelSize;
            float3 worldLightVector;
            float _maxBias;
            float _baseBias;
            float _FilterSize;
            float _UsePoissionDisk;
            float _UseLINEAR;
            float _UseStratified;

            v2f vert (appdata v)
            {
                v2f o;
                o.posL = v.vertex;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.uv;
                return o;
            }

            float GetShadowBias(float3 lightDir , float3 normal , float maxBias, float baseBias)
            {
                float cos_val = saturate(dot(lightDir, normal));
                float sin_val = sqrt(1 - cos_val * cos_val); // sin(acos(L·N))
                float tan_val = sin_val / cos_val;    // tan(acos(L·N))

                float bias = baseBias + clamp(tan_val, 0 , maxBias) ;

                return bias ;
            }

            float texture2DShadowLerp(float2 uv, float sceneDepth, float bias)
            {
                float2 texelSize = ShadowMapTexture_TexelSize.xy;
                float size = ShadowMapTexture_TexelSize.z;
                float2 centroidUV = floor(uv * size + 0.5) / size;
                float2 f = frac(uv * size + 0.5);

                float lb = DecodeFloatRGBA(tex2D(ShadowMapTexture, centroidUV + texelSize * float2(0.0, 0.0)));
                lb = sceneDepth - bias > lb ? 1.0 : 0.0;
                float lt = DecodeFloatRGBA(tex2D(ShadowMapTexture, centroidUV + texelSize * float2(0.0, 1.0)));
                lt = sceneDepth - bias > lt ? 1.0 : 0.0;
                float rb = DecodeFloatRGBA(tex2D(ShadowMapTexture, centroidUV + texelSize * float2(1.0, 0.0)));
                rb = sceneDepth - bias > rb ? 1.0 : 0.0;
                float rt = DecodeFloatRGBA(tex2D(ShadowMapTexture, centroidUV + texelSize * float2(1.0, 1.0)));
                rt = sceneDepth - bias > rt ? 1.0 : 0.0;
                float a = lerp(lb, lt, f.y);
                float b = lerp(rb, rt, f.y);
                float c = lerp(a, b, f.x);
                return c;
            }

            float random(float3 seed, int i) {
                float4 seed4 = float4(seed,i);
                float dot_product = dot(seed4, float4(12.9898,78.233,45.164,94.673));
                return frac(sin(dot_product) * 43758.5453);
            }

            //泊松分布采样值
            float2 poissonDisk[16];

            void BuildPoissonDisk()
            {
                poissonDisk[0] = float2(-0.94201624, -0.39906216);
                poissonDisk[1] = float2(0.94558609, -0.76890725);
                poissonDisk[2] = float2(-0.094184101, -0.92938870);
                poissonDisk[3] = float2(0.34495938, 0.29387760);
                poissonDisk[4] = float2(-0.91588581, 0.45771432);
                poissonDisk[5] = float2(-0.81544232, -0.87912464);
                poissonDisk[6] = float2(-0.38277543, 0.27676845);
                poissonDisk[7] = float2(0.97484398, 0.75648379);
                poissonDisk[8] = float2(0.44323325, -0.97511554);
                poissonDisk[9] = float2(0.53742981, -0.47373420);
                poissonDisk[10] = float2(-0.26496911, -0.41893023);
                poissonDisk[11] = float2(0.79197514, 0.19090188);
                poissonDisk[12] = float2(-0.24188840, 0.99706507);
                poissonDisk[13] = float2(-0.81409955, 0.91437590);
                poissonDisk[14] = float2(0.19984126, 0.78641367);
                poissonDisk[15] = float2(0.14383161, -0.14100790);
            }

            float PercentCloaerFilter(float3 posVertex,float2 uv , float sceneDepth , float bias)
            {
                float shadow = 0.0;
                float shadowNoise = 0.0;
                float2 texelSize = ShadowMapTexture_TexelSize.xy;
                if(_UsePoissionDisk > 0.5)
                {
                    float total = (_FilterSize * 2 + 2) * (_FilterSize * 2 + 2);
                    for(int i = 0; i < total; ++i)
                    {
                        float2 uv_offset = poissonDisk[i] * texelSize;
                        float depth = DecodeFloatRGBA(tex2D(ShadowMapTexture, uv + uv_offset));
                        shadow += (sceneDepth - bias > depth ? 1.0 : 0.0);    
                    }
                    shadow /= total;
                    return shadow;
                }

                if(_UseLINEAR > 0.5)
                {
                    for(int x = -_FilterSize; x <= _FilterSize; ++x)
                    {
                        for(int y = -_FilterSize; y <= _FilterSize; ++y)
                        {
                            float2 uv_offset = float2(x,y) * texelSize;
                            float depth = texture2DShadowLerp(uv + uv_offset,sceneDepth,bias);
                            shadow += depth;   
                        }    
                    }
                    float total = (_FilterSize * 2 + 1) * (_FilterSize * 2 + 1);
                    shadow /= total;
                    return shadow;
                }

                if(_UseStratified > 0.5)
                {
                    float total = (_FilterSize * 2 + 2) * (_FilterSize * 2 + 2);
                    for(int i = 0; i < total; ++i)
                    {
                        int index = int(fmod((16.0 * random(floor(posVertex.xyz * 1000.0), i)), 16.0));
                        float2 uv_offset_noise = poissonDisk[index] * texelSize;
                        float2 uv_offset = poissonDisk[i] * texelSize;
                        float depthNoise = DecodeFloatRGBA(tex2D(ShadowMapTexture, uv + uv_offset_noise));
                        float depth = DecodeFloatRGBA(tex2D(ShadowMapTexture, uv + uv_offset));
                        shadow += (sceneDepth - bias > depth ? 1.0 : 0.0);  
                        shadowNoise += (sceneDepth - bias > depthNoise ? 1.0 : 0.0);
                    }
                    shadow /= total;
                    shadowNoise /= total;
                    float area = step(shadow,0.43);
                    return (1 - area) * shadow + area * shadowNoise;
                }

                for(int x = -_FilterSize; x <= _FilterSize; ++x)
                {
                    for(int y = -_FilterSize; y <= _FilterSize; ++y)
                    {
                        float2 uv_offset = float2(x,y) * texelSize;
                        float depth = DecodeFloatRGBA(tex2D(ShadowMapTexture, uv + uv_offset));
                        shadow += (sceneDepth - bias > depth ? 1.0 : 0.0);   
                    }    
                }
                float total = (_FilterSize * 2 + 1) * (_FilterSize * 2 + 1);
                shadow /= total;

                return shadow;
            }

            float4 frag(v2f i) : SV_Target
            {
                float bias = GetShadowBias(worldLightVector, i.normal, _maxBias, _baseBias);
                float d = step(dot(worldLightVector, i.normal), 0);
                float4 ndcpos = mul(SHADOW_MAP_VP , i.worldPos);
                ndcpos.xyz = ndcpos.xyz / ndcpos.w;
                float3 uvpos = ndcpos * 0.5 + 0.5;
                BuildPoissonDisk();
                // float shadow = PercentCloaerFilter(i.worldPos.xyz,uvpos.xy, ndcpos.z, bias);
                float shadow = pow(saturate(PercentCloaerFilter(i.worldPos.xyz,uvpos.xy, ndcpos.z, bias) + 0.6),3);
                float4 color = lerp(float4(0.05,0.05,0.05,1), float4(0.42,0.42,0.42,1),shadow).xxxx;
                return color;
            }
            ENDCG
        }
    }
}

                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                