Shader "Noise/SimpleNoiseRGB"
{
    Properties
    {
        [Enum(Base,0,FBM,1)] _Type("Noise Type", Int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "NoiseFunction.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            uniform half _Type;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
 
            fixed4 frag (v2f i) : SV_Target
            {
                float a = 0.0, b = a;
                float2 pos = (i.uv + _Time.y);
                a += hash12(pos);
                b += hashOld12(pos);

                float3 col = float3(a,b,1);

                half4 f = 0;
                if(_Type > 0.5)
                {
                    i.uv            *= 8.0;
                    half2x2 m       = half2x2( 1.6,  1.2, -1.2,  1.6 );
                    f               =  0.5000 * snoise_grad( half3(col)); i.uv = mul(m,i.uv);
                    f               += 0.2500 * snoise_grad( half3(col)); i.uv = mul(m,i.uv);
                    f               += 0.1250 * snoise_grad( half3(col)); i.uv = mul(m,i.uv);
                    f               += 0.0625 * snoise_grad( half3(col)); i.uv = mul(m,i.uv);
                    f               =  0.5 + 0.5 * f;
                    f               *= smoothstep( 0.0, 0.005, abs(i.uv.x - 0.6) );	
                }
                else
                {
                    half3 noise     = half3(i.uv.x * 30 , i.uv.y * 30, abs(sin(cos(i.uv.x + i.uv.y))));
                    f               = snoise_grad(col);
                }
                return f;
            }
            ENDCG 
        }
    }
}
