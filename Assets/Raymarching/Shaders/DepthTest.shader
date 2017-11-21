// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Raymarching/DepthTest"
{
	Properties
	{
		_Diffuse("Diffuse (RGB) Occlusion (A)", COLOR) = (0.5, 0.5, 0.5, 1)
		_Specular("Specular (RGB) Smoothness (A)", COLOR) = (0.5, 0.5, 0.5, 1)
		_Emission("Emission (RGB) NoUse(A)",COLOR) = (0.5 ,0.5 ,0.5 ,1)

		_Position("Position (XYZ) Axis (W) no use", Vector) = (0, 0, 0, 0)
		_Rotation("Rotate (XYZ) Axis (W) no use", Vector) = (0, 0, 0, 0)
		_Scale("Scale (XYZ) Axis (W) no use", Vector) = (1, 1, 1, 0)

		_Density("Density", Float) = 0.5
		_MaxDistance("Max Distance", Range(0,10)) = 0.5 
	}

	CGINCLUDE
//#include "Libs/RaymarchingPreDefine.cginc"

#include "UnityCG.cginc"
#include "Libs/Utils.cginc"
#include "Libs/Noise.cginc"
#include "Libs/Primitives.cginc"
#include "Libs/DistanceFunction.cginc"

#ifndef RAY_HIT_DISTANCE
#define RAY_HIT_DISTANCE 0.0001
#endif

	// ワールド座標系のカメラの位置
	float3 GetCameraPosition() { return _WorldSpaceCameraPos; }
	// 変換行列からカメラの情報を取得
	float3 GetCameraForward() { return -UNITY_MATRIX_V[2].xyz; }
	float3 GetCameraUp() { return UNITY_MATRIX_V[1].xyz; }
	float3 GetCameraRight() { return UNITY_MATRIX_V[0].xyz; }
	float3 GetCameraFocalLength() { return abs(UNITY_MATRIX_P[1][1]); }
	// カメラがレンダリングする最大距離
	float GetCameraMaxDistance() { return _ProjectionParams.z - _ProjectionParams.y; }

	// レイの方向を取得
	float3 GetRayDir(float2 screenPos)
	{
#if UNITY_UV_STARTS_AT_TOP
		screenPos.y *= -1.0;
#endif
		screenPos.x *= _ScreenParams.x / _ScreenParams.y;

		float3 camDir = GetCameraForward();
		float3 camUp = GetCameraUp();
		float3 camSide = GetCameraRight();
		float3 focalLen = GetCameraFocalLength();

		return normalize((camSide * screenPos.x) + (camUp * screenPos.y) + (camDir * focalLen));
	}

	// デプス取得
	float GetDepth(float3 pos)
	{
		float4 vp = mul(UNITY_MATRIX_VP, float4(pos, 1.0));
#if UNITY_UV_STARTS_AT_TOP
		return vp.z / vp.w;
#else
		return (vp.z / vp.w) * 0.5 + 0.5;
#endif
	}

	struct appdata
	{
		float4 vertex : POSITION;
	};

	struct v2f
	{
		float4 vertex		: SV_POSITION;
		float4 screenPos	: TEXCOORD0;
		float4 worldPos		: TEXCOORD1;
	};

	//MRTにより出力するG-Buffer
	struct gbuffer
	{
		half4 diffuse  : SV_Target0;	// rgb: diffuse,  a: occlusion
		half4 specular : SV_Target1;	// rgb: specular, a: smoothness
		half4 normal   : SV_Target2;	// rgb: normal,   a: unused
		half4 emission : SV_Target3;	// rgb: emission, a: unused
		float depth : SV_Depth;		// Depth
	};

	struct raymarchOut
	{
		float3 pos;		// ワールド座標
		int count;		// 試行回数
		float length;	// レイが進んだ長さ
		float distance;	// 最後に試行された距離関数の出力
	};

	struct transform
	{
		float3 pos;
		float3 rot;
		float3 scale;
	};

	gbuffer InitGBuffer(half4 diffuse, half4 specular, half3 normal, half4 emission, float depth)
	{
		gbuffer g;
		g.diffuse = diffuse;
		g.specular = specular;
		g.normal = half4(normal, 1);
		g.emission = emission;
		g.depth = depth;

		return g;
	}

	transform InitTransform(float3 pos, float3 rot, float3 scale) {
		transform tr;
		tr.pos = pos;
		tr.rot = rot;
		tr.scale = scale;

		return tr;
	}

	// ワールド座標からローカル座標に変換
	float3 Localize(float3 pos, transform tr) {
		// Position
		pos -= tr.pos;

		// Rotation
		float3 x = rotateX(pos, radians(tr.rot.x));
		float3 xy = rotateY(x, radians(tr.rot.y));
		float3 xyz = rotateX(xy, radians(tr.rot.z));
		pos.xyz = xyz;

		// Scale
		pos /= tr.scale;

		return pos;
	}

	float4 _Position;
	float4 _Rotation;
	float4 _Scale;

	float4 _Diffuse;
	float4 _Specular;
	float4 _Emission;

	float _Density;
	float _MaxDistance;

	UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

	float CustomDistanceFunction(float3 pos) 
	{
		return box(pos, float3(100, 0.1, 100));
	}

	gbuffer CustomGBufferOutPut(float3 normal, float depth, raymarchOut rayOut)
	{
		float fog = min(1.0, (1.0 / 100)) * float(rayOut.count) * 1.5;
		return InitGBuffer(_Diffuse, _Specular, normal, _Emission * fog, depth);
	}

#define CUSTOM_DISTANCE_FUNCTION(p) CustomDistanceFunction(p)
#define CUSTOM_GBUFFER_OUTPUT(diff, spec, norm, emit, dep) CustomGBufferOutPut(normal, depth, rayOut)
#define CUSTOM_TRANSFORM(p, r, s) InitTransform(_Position, _Rotation, _Scale)


//#include "Libs/Raymarching.cginc"
// Raymarchingの定義（後半）

//// レイがヒットしたとみなす距離
//#ifndef RAY_HIT_DISTANCE
//#define RAY_HIT_DISTANCE 0.000001
//#endif

// CUSTOM_DISTANCE_FUNCTIONが他で未定義の場合に__DefaultDistanceFuncが定義される
#if !defined(CUSTOM_DISTANCE_FUNCTION)
#define CUSTOM_DISTANCE_FUNCTION(p) __DefaultDistanceFunc(p)
// デフォルトの距離関数
// CUSTOM_DISTANCE_FUNCTIONが未定義の場合に呼ばれる
	float __DefaultDistanceFunc(float3 pos)
	{
		return box(repeat(pos, float3(5, 5, 5)), float3(1, 1, 1));
	}
#endif //CUSTOM_DISTANCE_FUNCTION

#if !defined(CUSTOM_TRANSFORM)
#define CUSTOM_TRANSFORM(p, r, s) InitTransform(p, r, s)
#endif //CUSTOM_TRANSFORM

#if !defined(CUSTOM_GBUFFER_OUTPUT)
#define CUSTOM_GBUFFER_OUTPUT(diff, spec, norm, emit , dep) InitGBuffer(diff, spec, norm, emit, dep)
#endif // CUSTOM_GBUFFER_OUTPUT


	// 法線取得
	float3 GetNormal(float3 pos)
	{
		const float delta = 0.001;
		return normalize(float3(
			CUSTOM_DISTANCE_FUNCTION(pos + float3(delta, 0, 0)) - CUSTOM_DISTANCE_FUNCTION(pos + float3(-delta, 0, 0)),
			CUSTOM_DISTANCE_FUNCTION(pos + float3(0, delta, 0)) - CUSTOM_DISTANCE_FUNCTION(pos + float3(0, -delta, 0)),
			CUSTOM_DISTANCE_FUNCTION(pos + float3(0, 0, delta)) - CUSTOM_DISTANCE_FUNCTION(pos + float3(0, 0, -delta))
			)) * 0.5 + 0.5;
	}

	raymarchOut raymarch(v2f In, transform tr, const int trial_num)
	{
		raymarchOut o;

		float3 rayDir = GetRayDir(In.screenPos);
		float3 camPos = GetCameraPosition();
		//float maxDistance = GetCameraMaxDistance();
		float maxDistance = _MaxDistance;

		o.length = 0;
		//o.pos = camPos + _ProjectionParams.y * rayDir;
		o.pos = In.worldPos;
		
		float2 uv = (In.screenPos.xy + float2(1, 1)) * 0.5;
#if UNITY_UV_STARTS_AT_TOP
		uv.y = 1.0 - uv.y;
#endif
		float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv).x);
//		float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv).x;
//#if defined(UNITY_REVERSED_Z)
//		depth = 1.0f - depth;
//#endif
		for (o.count = 0; o.count < trial_num; ++o.count) {
			//o.distance = CUSTOM_DISTANCE_FUNCTION(Localize(o.pos, tr));
			o.distance = 0.01;	// 少しずつ進ませる
			o.length += o.distance;
			o.pos += rayDir * o.distance;
			//float rayDepth = Linear01Depth(GetDepth(o.pos));
			//float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos).x);
			float4 pos = UnityObjectToClipPos(float4(o.pos, 1));
			float rayDepth = Linear01Depth(pos.z / pos.w);
			//if (o.distance < RAY_HIT_DISTANCE || o.length > maxDistance)
			//if (o.distance < RAY_HIT_DISTANCE || o.length > maxDistance || rayDepth >= depth)
			if (o.length > maxDistance || rayDepth >= depth)
			//if (o.length > maxDistance)
				break;
		}

		return o;
	}

	v2f raymarch_vert(appdata v)
	{
		v2f o;
		o.vertex = UnityObjectToClipPos(v.vertex);
		// ラスタライズしてフラグメントシェーダで各ピクセルの座標として使う
		o.screenPos = o.vertex;
		o.worldPos = mul(unity_ObjectToWorld, v.vertex);
		return o;
	}

	//gbuffer raymarch_frag(v2f i)
	half4 raymarch_frag(v2f i) : SV_TARGET
	{
		i.screenPos.xy /= i.screenPos.w;

		raymarchOut rayOut;
		transform tr;
		tr = CUSTOM_TRANSFORM(0, 0, 1);

		rayOut = raymarch(i, tr, 100);
		//clip(-rayOut.distance + RAY_HIT_DISTANCE);

		float2 uv = (i.screenPos.xy + float2(1, 1)) * 0.5;
#if UNITY_UV_STARTS_AT_TOP
		uv.y = 1.0 - uv.y;
#endif
		float4 pos = UnityObjectToClipPos(float4(rayOut.pos, 1));
		float rayDepth = Linear01Depth(pos.z / pos.w);
		//float rayDepth = Linear01Depth(pos.z / pos.w);
		//float rayDepth = GetDepth(rayOut.pos);
		//float rayDepth = Linear01Depth(GetDepth(rayOut.pos));
		float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv).x);

		float3 normal = GetNormal(Localize(rayOut.pos, tr));
		//float dens = rayOut.length / _MaxDistance;
		float dens = saturate(rayOut.count * _Density);

		gbuffer gbOut;
		gbOut = CUSTOM_GBUFFER_OUTPUT(0.5, 0.5, normal, 0.5, rayDepth);

		//half4 col = half4(gbOut.diffuse.rgb, dens);
		
		//return gbOut;
		//return gbOut.depth;
		//return half4(rayOut.pos.y, depth, rayDepth, 1);
		//return half4(worldPos.xyz * 2, 1);
		//return half4(rayOut.pos.xyz, rayDepth);
		//return half4(gbOut.diffuse.rgb, rayDepth);
		//return half4(1, 0, 0, pow(saturate(1 - rayDepth), _Density));
		return half4(rayDepth, dens, 0, 1);

		//return col;
	}
	ENDCG

	SubShader
	{
		//Tags { "RenderType"="Opaque" }

		//Cull Off
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
		//Stencil
		//{
		//	Comp Always
		//	Pass Replace
		//	Ref 128
		//}
		Pass
		{
			//Tags{ "LightMode" = "Deferred" }
			Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
			CGPROGRAM
			#pragma vertex raymarch_vert
			#pragma fragment raymarch_frag
			#pragma target 3.0			
			ENDCG
		}
	}
}
