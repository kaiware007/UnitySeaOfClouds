Shader "Raymarching/Raymarching Box and Sphere blend"
{
	Properties
	{
		_Diffuse("Diffuse (RGB) Occlusion (A)", COLOR) = (0.5, 0.5, 0.5, 1)
		_Specular("Specular (RGB) Smoothness (A)", COLOR) = (0.5, 0.5, 0.5, 1)
		_Emission("Emission (RGB) NoUse(A)",COLOR) = (0.5 ,0.5 ,0.5 ,1)

		_Position("Position (XYZ) Axis (W) no use", Vector) = (0, 0, 0, 0)
		_Rotation("Rotate (XYZ) Axis (W) no use", Vector) = (0, 0, 0, 0)
		_Scale("Scale (XYZ) Axis (W) no use", Vector) = (1, 1, 1, 0)
	}

	CGINCLUDE
#include "Libs/RaymarchingPreDefine.cginc"

	float4 _Position;
	float4 _Rotation;
	float4 _Scale;

	float4 _Diffuse;
	float4 _Specular;
	float4 _Emission;

	float CustomDistanceFunction(float3 pos) 
	{
		float bo = box(pos - float3(0.5, 0, 0), float3(1, 1, 1));
		float sp = sphere(pos + float3(0.5, 0, 0), 1);
		return smoothMin(bo, sp, 10);
	}

	gbuffer CustomGBufferOutPut(float3 normal, float depth, raymarchOut rayOut)
	{
		float fog = min(1.0, (1.0 / 100)) * float(rayOut.count) * 1.5;
		return InitGBuffer(_Diffuse, _Specular, normal, _Emission * fog, depth);
	}

#define CUSTOM_DISTANCE_FUNCTION(p) CustomDistanceFunction(p)
#define CUSTOM_GBUFFER_OUTPUT(diff, spec, norm, emit, dep) CustomGBufferOutPut(normal, depth, rayOut)
#define CUSTOM_TRANSFORM(p, r, s) InitTransform(_Position, _Rotation, _Scale)


#include "Libs/Raymarching.cginc"
	ENDCG

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		Cull Off
		Stencil
		{
			Comp Always
			Pass Replace
			Ref 128
		}
		Pass
		{
			Tags{ "LightMode" = "Deferred" }
			CGPROGRAM
			#pragma vertex raymarch_vert
			#pragma fragment raymarch_frag
			#pragma target 3.0			
			ENDCG
		}
	}
}
