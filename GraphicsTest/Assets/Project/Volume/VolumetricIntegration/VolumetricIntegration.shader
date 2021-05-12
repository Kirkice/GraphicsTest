Shader "Unlit/VolumetricIntegration"
{
    properties
    {
        _NoiseTex("NoiseTex",2D) = "white"
    }
	HLSLINCLUDE
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
    };
	
    #define D_FOG_NOISE 1.0
    #define D_STRONG_FOG 0.0
    #define D_VOLUME_SHADOW_ENABLE 1
	#define D_USE_IMPROVE_INTEGRATION 1
	
    #define D_STRONG_FOG 2.0
    #define D_FOG_NOISE 3.5
	#define D_VOLUME_SHADOW_ENABLE 0
	
    #define D_UPDATE_TRANS_FIRST 0
	#define D_DETAILED_WALLS 0
	#define D_MAX_STEP_LENGTH_ENABLE 1
	#define LPOS half3( 20.0+15.0*sin(_Time.y), 15.0,-20.0 + 12.0*cos(_Time.y))
    #define LCOL (300.0*half3( 0.2, 0.2 , 1))
	
    sampler2D _NoiseTex;
    float4 _NoiseTex_ST;

    float displacementSimple( half2 p )
    {
        float f;
        f  = 0.5000* tex2Dlod( _NoiseTex, float4(p,0,0) ).x; p = p*2.0;
        f += 0.2500* tex2Dlod( _NoiseTex, float4(p,0,0) ).x; p = p*2.0;
        f += 0.1250* tex2Dlod( _NoiseTex, float4(p,0,0) ).x; p = p*2.0;
        f += 0.0625* tex2Dlod( _NoiseTex, float4(p,0,0) ).x; p = p*2.0;
        return f;
    }

	half3 getSceneColor(half3 p, float material)
	{
		if(material==1.0)
		{
			return half3(1.0, 0.5, 0.5);
		}
		else if(material==2.0)
		{
			return half3(1, 1, 1);
		}
		else if(material==3.0)
		{
			return half3(0.8, 0.8, 0.8);
		}
    	else if(material==4.0)
    	{
    		return half3(0.5, 1, 0.5);
    	}
		
		return half3(0.0, 0.0, 0.0);
	}

	float getClosestDistance(half3 p, out float material)
	{
		float d = 0.0;
	#if D_MAX_STEP_LENGTH_ENABLE
	    float minD = 1.0; // restrict max step for better scattering evaluation
	#else
		float minD = 10000000.0;
	#endif
		material = 0.0;
	    
	    float yNoise = 0.0;
	    float xNoise = 0.0;
	    float zNoise = 0.0;
	#if D_DETAILED_WALLS
	    yNoise = 1.0*clamp(displacementSimple(p.xz*0.005),0.0,1.0);
	    xNoise = 2.0*clamp(displacementSimple(p.zy*0.005),0.0,1.0);
	    zNoise = 0.5*clamp(displacementSimple(p.xy*0.01),0.0,1.0);
	#endif
	    
		d = max(0.0, p.y - yNoise);
		if(d<minD)
		{
			minD = d;
			material = 2.0;
		}
		
		d = max(0.0,p.x - xNoise);
		if(d<minD)
		{
			minD = d;
			material = 1.0;
		}
		
		d = max(0.0,40.0-p.x - xNoise);
		if(d<minD)
		{
			minD = d;
			material = 4.0;
		}
		
		d = max(0.0,-p.z - zNoise);
		if(d<minD)
		{
			minD = d;
			material = 3.0;
	    }
	    
		return minD;
	}


	half3 calcNormal( in half3 pos)
	{
	    float material = 0.0;
	    half3 eps = half3(0.3,0.0,0.0);
		return normalize( half3(
	           getClosestDistance(pos+eps.xyy, material) - getClosestDistance(pos-eps.xyy, material),
	           getClosestDistance(pos+eps.yxy, material) - getClosestDistance(pos-eps.yxy, material),
	           getClosestDistance(pos+eps.yyx, material) - getClosestDistance(pos-eps.yyx, material) ) );

	}

	half3 evaluateLight(in half3 pos)
	{
	    half3 lightPos = LPOS;
	    half3 lightCol = LCOL;
	    half3 L = lightPos-pos;
	    return lightCol * 1.0/dot(L,L);
	}

	half3 evaluateLight(in half3 pos, in half3 normal)
	{
	    half3 lightPos = LPOS;
	    half3 L = lightPos-pos;
	    float distanceToL = length(L);
	    half3 Lnorm = L/distanceToL;
	    return max(0.0,dot(normal,Lnorm)) * evaluateLight(pos);
	}

	// To simplify: wavelength independent scattering and extinction
	void getParticipatingMedia(out float sigmaS, out float sigmaE, in half3 pos)
	{
	    float heightFog = 7.0 + D_FOG_NOISE*3.0*clamp(displacementSimple(pos.xz*0.005 + _Time.y*0.01),0.0,1.0);
	    heightFog = 0.3*clamp((heightFog-pos.y)*1.0, 0.0, 1.0);
	    
	    const float fogFactor = 1.0 + D_STRONG_FOG * 5.0;
	    
	    const float sphereRadius = 0.01;
	    float sphereFog = clamp((sphereRadius-length(pos-half3(20.0,19.0,-17.0)))/sphereRadius, 0.0,1.0);
	    
	    const float constantFog = 0.02;

	    sigmaS = constantFog + heightFog*fogFactor + sphereFog;
	   
	    const float sigmaA = 0.0;
	    sigmaE = max(0.000000001, sigmaA + sigmaS); // to avoid division by zero extinction
	}

	float phaseFunction()
	{
	    return 1.0/(4.0*3.14);
	}

	float volumetricShadow(in half3 from, in half3 to)
	{
	#if D_VOLUME_SHADOW_ENABLE
	    const float numStep = 16.0; // quality control. Bump to avoid shadow alisaing
	    float shadow = 1.0;
	    float sigmaS = 0.0;
	    float sigmaE = 0.0;
	    float dd = length(to-from) / numStep;
	    for(float s=0.5; s<(numStep-0.1); s+=1.0)// start at 0.5 to sample at center of integral part
	    {
	        half3 pos = from + (to-from)*(s/(numStep));
	        getParticipatingMedia(sigmaS, sigmaE, pos);
	        shadow *= exp(-sigmaE * dd);
	    }
	    return shadow;
	#else
	    return 1.0;
	#endif
	}

void traceScene(bool improvedScattering, half3 rO, half3 rD, inout half3 finalPos, inout half3 normal, inout half3 albedo, inout half4 scatTrans)
{
	const int numIter = 100;
	
    float sigmaS = 0.0;
    float sigmaE = 0.0;
    
    half3 lightPos = LPOS;
    
    // Initialise volumetric scattering integration (to view)
    float transmittance = 1.0;
    half3 scatteredLight = half3(0.0, 0.0, 0.0);
    
	float d = 1.0; // hack: always have a first step of 1 unit to go further
	float material = 0.0;
	half3 p = half3(0.0, 0.0, 0.0);
    float dd = 0.0;
	for(int i=0; i<numIter;++i)
	{
		half3 p = rO + d*rD;
    	getParticipatingMedia(sigmaS, sigmaE, p);
        
#ifdef D_DEMO_FREE
        if(D_USE_IMPROVE_INTEGRATION>0) // freedom/tweakable version
#else
        if(improvedScattering)
#endif
        {
            // See slide 28 at http://www.frostbite.com/2015/08/physically-based-unified-volumetric-rendering-in-frostbite/
            half3 S = evaluateLight(p) * sigmaS * phaseFunction()* volumetricShadow(p,lightPos);// incoming light
            half3 Sint = (S - S * exp(-sigmaE * dd)) / sigmaE; // integrate along the current step segment
            scatteredLight += transmittance * Sint; // accumulate and also take into account the transmittance from previous steps

            // Evaluate transmittance to view independentely
            transmittance *= exp(-sigmaE * dd);
        }
		else
        {
            // Basic scatering/transmittance integration
        #if D_UPDATE_TRANS_FIRST
            transmittance *= exp(-sigmaE * dd);
        #endif
            scatteredLight += sigmaS * evaluateLight(p) * phaseFunction() * volumetricShadow(p,lightPos) * transmittance * dd;
        #if !D_UPDATE_TRANS_FIRST
            transmittance *= exp(-sigmaE * dd);
        #endif
        }
        
		
        dd = getClosestDistance(p, material);
        if(dd<0.2)
            break; // give back a lot of performance without too much visual loss
		d += dd;
	}
	
	albedo = getSceneColor(p, material);
	
    finalPos = rO + d*rD;
    
    normal = calcNormal(finalPos);
    
    scatTrans = half4(scatteredLight, transmittance);
}

	
    v2f vert (appdata v)
    {
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.uv = v.uv;
        return o;
    }

    half4 PS (v2f pin) : SV_Target 
    {
    	half2 uv= pin.uv;
	    float hfactor = float(_ScreenParams.y) / float(_ScreenParams.x);
		half2 uv2 = half2(2.0, 2.0*hfactor) * pin.uv - half2(1.0, hfactor);
		half3 camPos = half3( 20.0, 13.0,-50.0);
		half3 camX   = half3( 1.0, 0.0, 0.0);
		half3 camY   = half3( 0.0, 1.0, 0.0);
		half3 camZ   = half3( 0.0, 0.0, 1.0);
		half3 rO = camPos;
		half3 rD = normalize(uv2.x*camX + uv2.y*camY + camZ);
		half3 finalPos = rO;
		half3 albedo = half3( 0.0, 0.0, 0.0 );
		half3 normal = half3( 0.0, 0.0, 0.0 );
	    half4 scatTrans = half4( 0.0, 0.0, 0.0, 0.0 );
	    traceScene( true,
	        rO, rD, finalPos, normal, albedo, scatTrans);

	    //lighting
	    half3 color = (albedo/3.14) * evaluateLight(finalPos, normal) * volumetricShadow(finalPos, LPOS);
	    // Apply scattering/transmittance
	    color = color * scatTrans.w + scatTrans.xyz;
	    
	    // Gamma correction
		color = pow(color, half3(1.0/2.2,1.0/2.2,1.0/2.2)); // simple linear to gamma, exposure of 1.0
        return half4(color,1);
    }
	
	ENDHLSL

    SubShader
    {
        pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment PS
            ENDHLSL
        }
    }
}
