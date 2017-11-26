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
		_MaxDistance("Max Distance", Range(0.1,10)) = 0.5 
		_WaveHeight("Wave Height", Float) = 1
		_WaveNoiseScale("Wave Noise Scale", Float) = 1
		_NoiseSpeed("Noise Speed", Vector) = (0, 1, 0, 0)
		_HolePower("Hole Power", Float) = 10
	}

	CGINCLUDE
//#include "Libs/RaymarchingPreDefine.cginc"

#include "UnityCG.cginc"
#include "Libs/Utils.cginc"
#include "Libs/Noise.cginc"
#include "Libs/Primitives.cginc"
#include "Libs/DistanceFunction.cginc"
//#include "UnityLightingCommon.cginc" // for _LightColor0
//#include "Lighting.cginc"

 // compile shader into multiple variants, with and without shadows
// (we don't care about any lightmaps yet, so skip these variants)
//#pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
//#pragma multi_compile_fwdbase
// shadow helper functions and macros
//#include "AutoLight.cginc"

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
	/*
	struct v2f
	{
		float4 vertex		: SV_POSITION;
		float4 screenPos	: TEXCOORD0;
		float4 worldPos		: TEXCOORD1;
		float3 worldNormal	: TEXCOORD2;
		//fixed4 diff			: COLOR0;
		//fixed3 ambient		: COLOR1;
		SHADOW_COORDS(3) // put shadows data into TEXCOORD3
		//float3 normal		: TEXCOORD4;
	};
	*/
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

	inline float3 ToLocal(float3 pos)
	{
		return mul(unity_WorldToObject, float4(pos, 1.0)).xyz;
	}

	float4 _Position;
	float4 _Rotation;
	float4 _Scale;

	float4 _Diffuse;
	float4 _Specular;
	float4 _Emission;

	float _Density;
	float _MaxDistance;
	float _WaveHeight;
	float _WaveNoiseScale;
	float3 _NoiseSpeed;

	float3 _PositionTextureOffset;
	float _HolePower;

	UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
	UNITY_DECLARE_DEPTH_TEXTURE(_LastCameraDepthTexture);

	UNITY_DECLARE_DEPTH_TEXTURE(_CustomCameraDepthTexture);
	
	sampler2D_float _PositionTexture;	// オブジェクトの位置を書き込んだテクスチャ
	float4 _PositionTexture_TexelSize;
	float _PositionTextureScale;

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

#if !defined(CUSTOM_DISTANCE_FUNCTION_OS)
#define CUSTOM_DISTANCE_FUNCTION_OS(p) CUSTOM_DISTANCE_FUNCTION(ToLocal(p))
#endif

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
	/*
	float3 GetNormalObjectSpace(float3 pos)
	{
		const float delta = 0.001;
		return normalize(float3(
			CUSTOM_DISTANCE_FUNCTION_OS(pos + float3(delta, 0, 0)) - CUSTOM_DISTANCE_FUNCTION_OS(pos + float3(-delta, 0, 0)),
			CUSTOM_DISTANCE_FUNCTION_OS(pos + float3(0, delta, 0)) - CUSTOM_DISTANCE_FUNCTION_OS(pos + float3(0, -delta, 0)),
			CUSTOM_DISTANCE_FUNCTION_OS(pos + float3(0, 0, delta)) - CUSTOM_DISTANCE_FUNCTION_OS(pos + float3(0, 0, -delta))
			)) * 0.5 + 0.5;
	}
	*/
	float GetDepthNearFar(float depth)
	{
		return lerp(_ProjectionParams.y, _ProjectionParams.z, depth);
	}

	float2 GetDepthUV(float2 screenPos)
	{
		float2 uv = (screenPos.xy + float2(1, 1)) * 0.5;
		//float2 uv = screenPos.xy;
#if UNITY_UV_STARTS_AT_TOP
		uv.y = 1.0 - uv.y;
#endif
		return uv;
	}

	float GetDepthTex2D(float2 uv)
	{
		return  Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CustomCameraDepthTexture, uv).x);
	}

	raymarchOut raymarch(float2 screenPos, float3 worldPos, float3 rayDir)
	{
		raymarchOut o;

		float maxDistance = _MaxDistance;

		o.pos = worldPos;
		
		float2 uv = GetDepthUV(screenPos.xy);

		float depth = GetDepthTex2D(uv);
		//float depth = Linear01Depth(tex2D(_CustomCameraDepthTexture, uv).x);
		//float depth = tex2D(_CustomCameraDepthTexture, uv).x;
		//float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CustomCameraDepthTexture, uv).x);
		//float depth = SAMPLE_DEPTH_TEXTURE(_CustomCameraDepthTexture, uv).x;
		float rayDepth = Linear01Depth(GetDepth(o.pos));
		
		float dist = min(GetDepthNearFar(depth - rayDepth), maxDistance);

		o.distance = o.length = dist;
		o.pos += rayDir * o.distance;

		return o;
	}

	float3 GetWorldPos(float4 pos)
	{
		return mul(unity_ObjectToWorld, pos).xyz * _WaveNoiseScale + _NoiseSpeed * _Time.y;
	}

	
	// PostionTexture内でのUV座標に変換
	float2 GetWorldPositionTexturePosition(float3 pos)
	{
		return (pos.xz - _PositionTextureOffset.xz) / _PositionTextureScale * 0.5 + 0.5;
		//return pos.xz / _PositionTextureScale * 0.5 + 0.5;
	}

	float GetWorldPositionTextureHeight(float4 pos)
	{
		float2 posUV = GetWorldPositionTexturePosition(mul(unity_ObjectToWorld, pos).xyz);
		float col = DecodeFloatRGBA(tex2Dlod(_PositionTexture, float4(posUV, 0,0)));

		return col * _HolePower;
	}

	float GetNoise(float4 vertex)
	{
		float3 wpos = GetWorldPos(vertex);

		// ノイズで歪ませてみる
		vertex.y += (fbm(wpos) - 0.5) * _WaveHeight;

		// オブジェクトの位置をへこませる
		vertex.y -= GetWorldPositionTextureHeight(vertex);
		
		return vertex.y;
	}

	float3 GetNormalNoise(float4 pos)
	{
		const float delta = 0.001;
		
		return normalize(float3(
			GetNoise(pos + float4(-delta, 0, 0, 0)) - GetNoise(pos + float4(delta, 0, 0, 0)),
			GetNoise(pos + float4(0, -delta, 0, 0)) - GetNoise(pos + float4(0, delta, 0, 0)),
			GetNoise(pos + float4(0, 0, -delta, 0)) - GetNoise(pos + float4(0, 0, delta, 0))
			)) * 0.5 + 0.5;
	}

	ENDCG

	SubShader
	{
		//Tags { "RenderType"="Opaque" }
		Tags{ "Queue"="AlphaTest" }

		Pass
		{
			Tags{ "LightMode" = "ForwardBase" }

			//ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			//Blend DstColor Zero // Multiplicative
			//Cull Off
			//Offset 1000,0

			CGPROGRAM
			#pragma vertex raymarch_vert
			#pragma fragment raymarch_frag
			#pragma target 3.0
			#pragma multi_compile_fwdbase
			#include "AutoLight.cginc"
			//#include "Lighting.cginc"

			//ライトの色
            fixed4 _LightColor0;

			struct v2f
			{
				float4 pos			: SV_POSITION;
				float4 screenPos	: TEXCOORD0;
				float4 worldPos		: TEXCOORD1;
				float3 worldNormal	: TEXCOORD2;
				float4 diff			: COLOR0;
				//fixed3 ambient		: COLOR1;
				SHADOW_COORDS(3) // put shadows data into TEXCOORD3
				//float3 normal		: TEXCOORD4;
				//LIGHTING_COORDS(5,7)
			};

			v2f raymarch_vert(appdata_full v)
			{
				v2f o;

				float4 pos = v.vertex;
				//float3 wpos = mul(unity_ObjectToWorld, v.vertex).xyz * _WaveNoiseScale + float3(-0.63, 0.85, 1) * _Time.y;
				float3 wpos = GetWorldPos(v.vertex);

				// ノイズで歪ませてみる
				v.vertex.y += (fbm(wpos) - 0.5) * _WaveHeight;

				// オブジェクトの位置をへこませる
				v.vertex.y -= GetWorldPositionTextureHeight(v.vertex);

				o.pos = UnityObjectToClipPos(v.vertex);
				// ラスタライズしてフラグメントシェーダで各ピクセルの座標として使う
				o.screenPos = o.pos;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);

				float3 normal = GetNormalNoise(pos);
				//o.worldNormal = UnityObjectToWorldNormal(normal);
				o.worldNormal = normal;

				TRANSFER_SHADOW(o)

				//half nl = max(0, dot(o.worldNormal, _WorldSpaceLightPos0.xyz));
				//o.diff = nl * _LightColor0;
				//o.diff.rgb = ShadeSH9(half4(o.normal,1));
				//o.diff.rgb = ShadeSH9(half4(o.worldNormal,1));
				o.diff.rgb = ShadeSH9(half4( normalize(mul(normal, (float3x3)unity_WorldToObject)),1));
				//o.diff.rgb = ShadeSH9(mul(unity_WorldToObject, half4(o.worldNormal,1)));
				o.diff.a = 1;

				//TRANSFER_VERTEX_TO_FRAGMENT(o);

				return o;
			}

			//gbuffer raymarch_frag(v2f i)
			half4 raymarch_frag(v2f i) : SV_TARGET
			{
				i.screenPos.xy /= i.screenPos.w;

				raymarchOut rayOut;
				transform tr;
				tr = CUSTOM_TRANSFORM(0, 0, 1);

				float3 rayDir = GetRayDir(i.screenPos);

				rayOut = raymarch(i.screenPos, i.worldPos, rayDir);
				//clip(-rayOut.distance + RAY_HIT_DISTANCE);

				//float2 uv = GetDepthUV(i.screenPos.xy);

				//float4 pos = UnityObjectToClipPos(float4(rayOut.pos, 1));
				//float rayDepth = Linear01Depth(pos.z / pos.w);
				//float rayDepth = Linear01Depth(pos.z / pos.w);
				//float rayDepth = GetDepth(rayOut.pos);
				//float rayDepth = Linear01Depth(GetDepth(rayOut.pos));
				//float rayDepth = Linear01Depth(GetDepth(i.worldPos));

				//float depth = GetDepthTex2D(uv);

				float3 normal = GetNormal(Localize(rayOut.pos, tr));
				float dens = saturate(rayOut.length / _MaxDistance * _Density);

				
				fixed shadow = SHADOW_ATTENUATION(i);
				half nl = max(0, dot(i.worldNormal, _WorldSpaceLightPos0.xyz));
				fixed3 lighting = i.diff + nl * _LightColor0 * shadow;
				
				//return gbOut;
				//return gbOut.depth;
				//return half4(depth, 0, 0, 1);
				//return half4(rayOut.length, depth, rayDepth, 1);
				//return half4(rayDepth,rayDepth,rayDepth,1);
				//return half4(rayOut.pos.y, depth, rayDepth, 1);
				//return half4(worldPos.xyz * 2, 1);
				//return half4(rayOut.pos.xyz, rayDepth);
				//return half4(gbOut.diffuse.rgb, rayDepth);
				//return half4(1, 0, 0, pow(saturate(1 - rayDepth), _Density));
				//return half4(rayDepth, depth, dens, 1);
				//return half4(gbOut.diffuse.rgb * shadow, dens);
				//return half4(i.worldNormal, dens);
				//return half4(i.worldNormal.z * 0.5 + 0.5, 0, 0, dens);
				//return half4((i.worldNormal * 0.5 + 0.5) * lighting, 1);
				//return half4((i.worldNormal * 0.5 + 0.5), dens);
				//return half4(i.normal * 0.5 + 0.5, dens);
				//return half4(gbOut.diffuse.rgb, dens);
				//return half4(gbOut.diffuse.rgb * lighting, 1);
				//return half4((i.worldNormal.rgb * 0.5 + 0.5)* lighting, dens);
				//return half4((i.worldNormal.rgb * 0.5 + 0.5), 1);	// test
				//return half4(1,0,0,1);
				//return depth;

				//float test = Linear01Depth(DecodeFloatRGBA(tex2D(_CustomCameraDepthTexture, uv)));
				//float test = Linear01Depth(DecodeFloatRGBA(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv)));
				//return half4(test, test, test, 1);

				return half4(_Diffuse.rgb * lighting, dens);
			}
			ENDCG
		}

		// shadow casting support
        //UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		
		// shadow caster rendering pass, implemented manually
        // using macros from UnityCG.cginc
        Pass
        {
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			//Blend SrcAlpha OneMinusSrcAlpha 

			Fog {Mode Off}
			//ZWrite Off
			ZWrite On 
			ZTest LEqual 
			Cull Back
			//Offset 1, 1

            CGPROGRAM
            #pragma vertex vert_shadow
            #pragma fragment frag_shadow
            #pragma target 3.0	
			#pragma multi_compile_shadowcaster
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "UnityCG.cginc"
			//#include "AutoLight.cginc"

			struct v2f_shadow { 
				V2F_SHADOW_CASTER;
				//float4 vertex		: SV_POSITION;
				float4 screenPos	: TEXCOORD1;
				float4 worldPos		: TEXCOORD2;
				float3 worldNormal	: TEXCOORD3;
			};

			// レイの方向を取得
			float3 GetRayDirForShadow(float4 screenPos)
			{
				float4 sp = screenPos;

#if UNITY_UV_STARTS_AT_TOP
				sp.y *= -1.0;
#endif
				//screenPos.x *= _ScreenParams.x / _ScreenParams.y;
				sp.xy /= sp.w;

				float3 camDir = GetCameraForward();
				float3 camUp = GetCameraUp();
				float3 camSide = GetCameraRight();
				float3 focalLen = GetCameraFocalLength();

				return normalize((camSide * sp.x) + (camUp * sp.y) + (camDir * focalLen));
			}

			v2f_shadow vert_shadow(appdata_base v)
			{
				v2f_shadow o;

				float4 pos = v.vertex;
				float3 wpos = GetWorldPos(v.vertex);

				// ノイズで歪ませてみる
				v.vertex.y += (fbm(wpos) - 0.5) * _WaveHeight;

				// オブジェクトの位置をへこませる
				v.vertex.y -= GetWorldPositionTextureHeight(v.vertex);

				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				// ラスタライズしてフラグメントシェーダで各ピクセルの座標として使う
				o.screenPos = o.pos;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);

				float3 normal = GetNormalNoise(pos);
				o.worldNormal = normal;

				return o;
			}
			
			
			float4 frag_shadow(v2f_shadow i) : SV_Target
			{

				float3 rayDir = GetRayDirForShadow(i.screenPos);

				raymarchOut rayOut;
				
				rayOut = raymarch(i.screenPos, i.worldPos, rayDir);

				SHADOW_CASTER_FRAGMENT(i)
			}
			
            ENDCG
        }
		
		
	}

	Fallback "Transparent/VertexLit"
}
