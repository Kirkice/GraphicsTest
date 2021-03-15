Shader "Unlit/PCFShadow"
{
    Properties {
    }

    SubShader {
        Tags { "RenderType"="Opaque" }
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct v2f {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 depth: TEXCOORD1;
            };

            float4x4 SHADOW_MAP_VP;
            float3 worldLightVector;
            sampler2D _CameraDepthTexture;

            v2f vert(appdata_base v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.depth = o.vertex.zw;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target{
                float depth = i.depth.x / i.depth.y;
                return EncodeFloatRGBA(depth);
            }
            ENDCG
        }
    }
}
