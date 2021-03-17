Shader "Unlit/Caster" 
{
	Properties 
	{
		_MainTex ("Base", 2D) = "white" {}
	}
	SubShader {
		Tags 
		{ 			
		    "RenderType" = "Opaque"
		}
		Pass {
			Fog { Mode Off }
//			Cull Front

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
	 
			#include "UnityCG.cginc"
	
			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 depth:TEXCOORD0;
				float2 texcoord : TEXCOORD1;
			};
	
			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.depth = o.pos.zw;
				o.texcoord = v.texcoord;
				return o;
			}
			
			fixed4 frag (v2f i) : COLOR
			{
				float4 tex = tex2D (_MainTex, TRANSFORM_TEX(i.texcoord,_MainTex));
				float depth = i.depth.x/i.depth.y;
				#if defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
							depth = depth * 0.5 + 0.5; //(-1, 1)-->(0, 1)
				#elif defined (UNITY_REVERSED_Z)
							depth = 1 - depth;       //(1, 0)-->(0, 1)
				#endif
				//return EncodeFloatRGBA(depth);
				return float4(depth.xxx,tex.a);
			}
			ENDCG 
		}	
	}
}
