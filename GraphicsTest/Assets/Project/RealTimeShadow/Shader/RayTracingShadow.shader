Shader "Unlit/RayTracingShadow"
{
    Properties
    {

    }
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 texcood : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD0;
                float2 uv     : TEXCOORD1;
                float4 PosSS  : TEXCOORD2;
            };

            float3 _LightDir;
            //--球 软阴影
            float sphSoftShadow(float3 ro, float3 rd, float4 sph, float k)
            {
                float3 oc = ro - sph.xyz;
                float b = dot( oc, rd );
                float c = dot( oc, oc ) - sph.w * sph.w;
                float h = b * b - c;
                
            #if 0
                // physically plausible shadow
                float d = sqrt( max(0.0, sph.w * sph.w - h)) - sph.w;
                float t = -b - sqrt( max(h, 0.0) );
                return (t < 0.0) ? 1.0 : smoothstep(0.0, 1.0, 2.5 * k * d/t );
            #else
                // cheap but not plausible alternative
                return (b > 0.0) ? step(-0.0001, c) : smoothstep( 0.0, 1.0, h * k/b );
            #endif    
            }

            //--球面法线计算
            float3 sphNormal(float3 pos, float4 sph)
            {
                return normalize(pos - sph.xyz);
            }

            //--球 碰撞
            float sphIntersect(float3 ro, float3 rd, float4 sph)
            {
                float3 oc = ro - sph.xyz;
                float b = dot(oc, rd);
                float c = dot(oc, oc) - sph.w * sph.w;
                float h = b * b - c;
                if(h < 0)
                    return -1;
                
            	return -b - sqrt(h);
            }

            //--球 AO
            float sphOcclusion(float3 pos, float3 nor, float4 sph)
            {
                float3 r = sph.xyz - pos;
                float l = length(r);
                return dot(nor,r) * (sph.w * sph.w) / (l * l * l);
            }

            //--地面
            float iPlane(float3 ro,float3 rd)
            {
                return (-1.0 - ro.y) / rd.y;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.PosSS = ComputeScreenPos(o.vertex);
                o.uv = v.texcood;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                i.PosSS.xy = i.PosSS.xy / i.PosSS.w;
                i.PosSS.xy *= _ScreenParams.xy;
                float3 ro = float3(0, 0, 4);
                float2 uv = i.uv * float2(4,2.2) + float2(-2.5,-1);
                float3 rd = normalize(float3(uv, -2));
                float4 sph = float4(cos( float3(2.0,1.0,1.0) + 0.0 ) * float3(1.5,0.0,1.0), 1.0);

                float3 lig = normalize(_LightDir);
                float3 finalColor = float3(0,0,0);

                float tmin = 1e10;
                float3 nor;
                float occ = 1.0;

                float t1 = iPlane( ro, rd );
                if( t1 > 0)
                {
                    tmin = t1;
                    float3 pos = ro + t1 * rd;
                    nor = float3(0.0,1.0,0.0);
                    occ = 1.0 - sphOcclusion( pos, nor, sph );
                }
            #if 1
                float t2 = sphIntersect( ro, rd, sph );
                if( t2 > 0.0 && t2 < tmin )
                {
                    tmin = t2;
                    float3 pos = ro + t2 * rd;
                    nor = sphNormal( pos, sph );
                    occ = 0.5 + 0.5 * nor.y;
                }
            #endif 
                if( tmin < 1000.0 )
                {
                    float3 pos = ro + tmin*rd;
                    
                    finalColor = float3(1,1,1);
                    finalColor *= clamp( dot(nor,lig), 0.0, 1.0 );
                    finalColor *= sphSoftShadow( pos, lig, sph, 2.0 );
                    finalColor += 0.05 * occ;
                    finalColor *= exp( -0.05 * tmin );
                }

                finalColor = sqrt(finalColor);
                return float4(finalColor,1);
            }
            ENDCG
        }
    }
}
