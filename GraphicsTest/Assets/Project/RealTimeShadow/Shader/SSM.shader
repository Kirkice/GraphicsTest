Shader "Unlit/SSMReceiver" {

	Properties {
		_Color ("Main Color", Color) = (1,1,1,1)
		_MainTex ("Base", 2D) = "white" {}
		[HDR]_ShadowColor("Shadow Color",color) = (1,1,1,1)
        _maxBias("Max Bias",Range(0,0.001)) = 0
        _baseBias("Base Bias", Range(0,0.001)) = 0
        _FilterSize("Filter Size", float) = 1
	}

	CGINCLUDE		
	#include "UnityCG.cginc"
	struct v2f_full
	{
		half4 pos : SV_POSITION;
		half2 uv : TEXCOORD0;
		float3 normal : TEXCOORD1;
		half4 screenPos : TEXCOORD2;
		half3 posW : TEXCOORD3;
	};


	half4 _Color;
	sampler2D _MainTex;
	float4 _MainTex_ST;
	uniform sampler2D _WindowSTextures;
	uniform sampler2D _ScreenSpceShadowTexture;
	uniform float4 _ScreenSpceShadowTexture_TexelSize;
    float _maxBias;
    float _baseBias;
    float _FilterSize;
	float4 _ShadowColor;
    float3 worldLightVector;
	ENDCG 

	SubShader 
	{
		Pass 
		{

			CGPROGRAM
			v2f_full vert (appdata_full v) 
			{
				v2f_full o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.texcoord,_MainTex);
				o.screenPos = o.pos;
				o.normal = UnityObjectToWorldNormal(v.normal);
		        o.posW = mul(unity_ObjectToWorld, v.vertex);
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
			
			float PercentCloaerFilter(float2 uv , float sceneDepth , float bias)
            {
                float shadow = 0.0;
                float shadowNoise = 0.0;
                float2 texelSize = _ScreenSpceShadowTexture_TexelSize.xy;
		
                for(int x = -_FilterSize; x <= _FilterSize; ++x)
                {
                    for(int y = -_FilterSize; y <= _FilterSize; ++y)
                    {
                        float2 uv_offset = float2(x,y) * texelSize;
                        float depth = DecodeFloatRGBA(tex2D(_ScreenSpceShadowTexture, uv + uv_offset));
                        shadow += (sceneDepth - bias > depth ? 1.0 : 0.0);   
                    }    
                }
                float total = (_FilterSize * 2 + 1) * (_FilterSize * 2 + 1);
                shadow /= total;

                return shadow;
			}
			float3 GetShadow(float2 uv)
			{
		        float3 shadow = float3(0,0,0);
                float2 texelSize = _ScreenSpceShadowTexture_TexelSize.xy;
				for(int x = -_FilterSize; x <= _FilterSize; ++x)
                {
                    for(int y = -_FilterSize; y <= _FilterSize; ++y)
                    {
                        float2 uv_offset = float2(x,y) * texelSize;
                    	float4 tex = tex2D(_ScreenSpceShadowTexture, uv + uv_offset);
                        float3 color = float3(tex.g,tex.b,tex.a);
                        shadow += color;   
                    }    
                }
                float total = (_FilterSize * 2 + 1) * (_FilterSize * 2 + 1);
                shadow = float3((shadow.r / total),(shadow.g / total),(shadow.b / total));

                return shadow;
			}
			fixed4 frag (v2f_full i) : COLOR0 
			{
				fixed4 tex = tex2D (_MainTex, i.uv.xy);
				half lambert = saturate(dot(normalize(i.normal),normalize(_WorldSpaceLightPos0.xyz)));
				i.screenPos.xyz = i.screenPos.xyz / i.screenPos.w;
				float2 sceneUVs = i.screenPos.xy * 0.5 + 0.5;
				
				#if UNITY_UV_STARTS_AT_TOP
					sceneUVs.y = _ProjectionParams.x < 0 ? 1 - sceneUVs.y : sceneUVs.y;
				#endif

				float3 pcfColor = GetShadow(sceneUVs);
				pcfColor = pcfColor * tex * _ShadowColor + 0.6 * pcfColor * tex;
                float bias = GetShadowBias(_WorldSpaceLightPos0.xyz, i.normal, _maxBias, _baseBias);
				float shadow = saturate(PercentCloaerFilter(sceneUVs.xy, i.screenPos.z, bias));
				float3 planeColor = _Color * tex;
				float4 finalRGBA = float4(lerp(planeColor,pcfColor,shadow),1);

				return finalRGBA;
			}	
		
			#pragma vertex vert
			#pragma fragment frag
			ENDCG
		}
	}

	FallBack "Mobile/Diffuse"
}
