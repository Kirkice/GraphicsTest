Shader "Noise/Voronoise"
{
    Properties
    {
        [Enum(Square,0,Block,2,FBM,5)] _Type("Noise Type", Int) = 2
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
                half  f = 0;
                half2 p = 0.5 - 0.5 * cos(_Type * half2(1.0,0.5) );

                p = p * p * (3.0 - 2.0 * p);
                p = p * p * (3.0 - 2.0 * p);
                p = p * p * (3.0 - 2.0 * p);
                
                f = voronoise( 24.0 * i.uv, p.x, p.y );

                return f.xxxx;
            }
            ENDCG 
        }
    }
}
