Shader "Unlit/SDFShadow"
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
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 ray : TEXCOORD1;
            };

            uniform float4x4 _Corners;
            uniform float3 _CameraPos;
            uniform float3 _LightDirection;
            
            v2f vert (appdata v)
            {
                v2f o;
                half index = v.vertex.z;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                index = v.uv.x + (2 * o.uv.y);
                o.ray = _Corners[index].xyz;
                return o;
            }

            float sdSphere(float3 rp, float3 c, float r)
            {
                return distance(rp,c) - r;
            }
            
            float sdPlane( float3 p )
            {
                return p.y + 1;
            }
            
            float map(float3 rp)
            {
                float ret;
                float sp = sdSphere(rp, float3(0.0,1.5,0.0), 3.0);
                float py = sdPlane(rp.y);
                ret = (sp < py) ? sp : py;
                return ret;
            }

            float3 calcNorm(float3 p)
            {
                float eps = 0.001;

                float3 norm = float3(
                    map(p + float3(eps, 0, 0)) - map(p - float3(eps, 0, 0)),
                    map(p + float3(0, eps, 0)) - map(p - float3(0, eps, 0)),
                    map(p + float3(0, 0, eps)) - map(p - float3(0, 0, eps))
                );

                return normalize(norm);
            }

            float calcSoftshadow(float3 ro, float3 rd, in float tmin, in float tmax)
            {
                float res = 1.0;
                float t = tmin;
                float ph = 1e10;

                for (int i = 0; i < 32; i++)
                {
                    float h = map(ro + rd * t);
                    float y = h * h / (2.0 * ph);
                    float d = sqrt(h * h - y * y);
                    res = min(res, 10 * d / max(0, t - y));
                    ph = h;

                    t += h;
                    if(res < 0.0001 || t > tmax)
                        break;
                }
                return saturate(res);
            }
            
            float4 rayMarching(float3 rayOrigin, float3 rayDirection)
            {
                float4 ret = float4(0,0,0,0);
                int maxStep = 64;
                float rayDistance = 0;
                for(int i = 0; i < maxStep; i++)
                {
                    float3 p = rayOrigin + rayDirection * rayDistance;
                    float surfaceDistance = map(p);
                    if(surfaceDistance < 0.001)
                    {
                        ret = float4(1,0,0,1);
                        float3 normal = calcNorm(p);
                        ret = saturate(dot(- _LightDirection.xyz,normal)) * calcSoftshadow(p, -_LightDirection,    0.01, 300.0);
                        ret.a = 1;
                        break;
                    }
                    rayDistance += surfaceDistance;
                }
                return ret;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _CameraPos;
                
                float4 rayColor = rayMarching(rayOrigin, rayDirection);
                
                float4 finalColor = float4(rayColor.xyz * rayColor.w, 1);
                return finalColor;
            }
            ENDCG
        }
    }
}
