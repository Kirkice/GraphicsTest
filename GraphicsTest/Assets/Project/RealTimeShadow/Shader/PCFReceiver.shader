Shader "Unlit/PCFReceiver" 
{
    Properties 
    {
        _maxBias("Max Bias",Range(0,0.001)) = 0
        _baseBias("Base Bias", Range(0,0.001)) = 0
        _FilterSize("Filter Size", float) = 1
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
            };

            float4x4 SHADOW_MAP_VP;
            sampler2D ShadowMapTexture;
            float4 ShadowMapTexture_TexelSize;
            float3 worldLightVector;
            float _maxBias;
            float _baseBias;
            float _FilterSize;

            v2f vert (appdata v)
            {
                v2f o;
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

            // float texture2DShadowLerp(float2 uv, float bias)
            // {
            //     float size = 1024.0;
            //     float2 centroidUV = floor(uv * size + 0.5) / size;
            //     float2 f = frac(uv * size + 0.5);

            //     float lb = tex2D(ShadowMapTexture, centroidUV + texelSize * vec2(0.0, 0.0), compare, bias);
            //     float lt = tex2D(ShadowMapTexture, centroidUV + texelSize * vec2(0.0, 1.0), compare, bias);
            //     float rb = tex2D(ShadowMapTexture, centroidUV + texelSize * vec2(1.0, 0.0), compare, bias);
            //     float rt = tex2D(ShadowMapTexture, centroidUV + texelSize * vec2(1.0, 1.0), compare, bias);
            //     float a = lerp(lb, lt, f.y);
            //     float b = lerp(rb, rt, f.y);
            //     float c = lerp(a, b, f.x);
            //     return c;
            // }
            float PercentCloaerFilter(float2 uv , float sceneDepth , float bias)
            {
                float shadow = 0.0;
                float2 texelSize = ShadowMapTexture_TexelSize.xy;
                // texelSize = 1 / texelSize;

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

                float shadow = pow(saturate(PercentCloaerFilter(uvpos.xy, ndcpos.z, bias) + 0.6),3);
                float4 color = lerp(float4(0.05,0.05,0.05,1), float4(0.42,0.42,0.42,1),shadow).xxxx;
                return color;
            }
            ENDCG
        }
    }
}
