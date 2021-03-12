Shader "Unlit/PlanerShadow"
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
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half3 normal = normalize(i.normal);
                half lambert = saturate(dot(normal,_WorldSpaceLightPos0.xyz));
                half4 col = lambert.xxxx;
                return col;
            }
            ENDCG
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_planeShadow
            #pragma fragment frag_planeShadow
            #include "UnityCG.cginc"

            struct appdata_planeShadow
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            struct v2f_planeShadow
            {
                float4 vertex : SV_POSITION;
                float3 xlv_TEXCOORD0 : TEXCOORD0;
                float3 xlv_TEXCOORD1 : TEXCOORD1;
                float2 uv            : TEXCOORD2;
            };
            uniform half _ShadowOffset;
            uniform half3 _ShadowPlane;
            uniform half3 _WorldPos;
            uniform half _ShadowInvLen;
            uniform half3 _ShadowFadeParams;

            v2f_planeShadow vert_planeShadow(appdata_planeShadow v)
            {
                v2f_planeShadow o;
                float3 lightdir = normalize(_WorldSpaceLightPos0.xyz);
                float3 worldpos = mul(unity_ObjectToWorld, v.vertex).xyz;
                float distance = (_ShadowOffset - dot(_ShadowPlane.xyz, worldpos)) / dot(_ShadowPlane.xyz, lightdir.xyz);
                worldpos = worldpos + distance * lightdir.xyz;
                o.vertex = mul(unity_MatrixVP, float4(worldpos, 1.0));

                o.xlv_TEXCOORD0 = _WorldPos.xyz;
                o.xlv_TEXCOORD1 = worldpos;
                o.uv = v.uv;
                return o;
            }

            float4 frag_planeShadow(v2f_planeShadow i) : SV_Target
            {
                float3 posToPlane_2 = (i.xlv_TEXCOORD0 - i.xlv_TEXCOORD1);
                float4 color;
                color.xyz = half3(0,0,0);
                color.w = saturate(pow((1.0 - clamp(((sqrt(dot(posToPlane_2, posToPlane_2)) * _ShadowInvLen) - _ShadowFadeParams.x), 0.0, 1.0)), _ShadowFadeParams.y) * _ShadowFadeParams.z + 0.35);
                return color;
            }

            ENDCG
        }
    }
}
