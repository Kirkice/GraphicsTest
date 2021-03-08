Shader "SDF/Fractal"
{
    Properties
    {
        _Shape("Shape",Range(0,1)) = 0.2
        _Scale("Scale",Range(0,1)) = 1
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
            #include "fractal_function.hlsl"

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

            uniform half _Scale;
            uniform half _Shape;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            { 
                i.uv        = 3 * half2(i.uv.x - 0.28, i.uv.y - 0.2);

                half2 c     = half2(_Shape,_Shape) +
                        0.30 * half2( cos(0.31 * _Scale), sin(0.37 * _Scale) ) - 
                        0.15 * half2( sin(1.17 * _Scale), cos(2.31 * _Scale) );

                half2 dz    = half2( 1.0, 0.0 );
                half2 z     = i.uv;
                half g      = 1e10;

                for( int i  = 0; i < 100; i++ )
                {
                    if( dot(z, z) > 100.0 ) continue;
                    dz      = cmul( dz, df( z, c ) );	
                    z       = f( z, c );
                    g       = min( g, dot(z - 1.0, z - 1.0) );
                }

                float h     = 0.5 * log(dot(z, z)) * sqrt( dot(z,z) / dot(dz,dz) );
                h           = clamp( h * 250.0, 0.0, 1.0 );

                return half4(h.xxx, 1);
            }
            ENDCG
        }
    }
}
