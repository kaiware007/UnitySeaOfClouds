Shader "Custom/Cloud Sea"
{
	Properties
	{
		_Diffuse("Diffuse (RGB) Occlusion (A)", COLOR) = (0.5, 0.5, 0.5, 1)	// 色

		_Density("Density", Float) = 0.5						// 濃度
		_MaxDistance("Max Distance", Range(0.1,10)) = 0.5		// 透ける距離
		_WaveHeight("Wave Height", Float) = 1					// 波の高さ
		_WaveNoiseScale("Wave Noise Scale", Float) = 1			// 波のノイズの周期
		_NoiseSpeed("Noise Speed", Vector) = (0, 1, 0, 0)		// 波のノイズの速度
		_HolePower("Hole Power", Float) = 10					// 凹ませる強さ
	}

	CGINCLUDE

#include "UnityCG.cginc"
#include "Libs/Utils.cginc"
#include "Libs/Noise.cginc"

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

	struct raymarchOut
	{
		float3 pos;		// ワールド座標
		float length;	// レイが進んだ長さ
	};

	float4 _Diffuse;

	float _Density;
	float _MaxDistance;					// 透ける距離
	float _WaveHeight;
	float _WaveNoiseScale;
	float3 _NoiseSpeed;

	float _HolePower;					// 凹ませる強さ

	UNITY_DECLARE_DEPTH_TEXTURE(_CustomCameraDepthTexture);	// １カメで書き込んだDepthTexture
	
	sampler2D_float _PositionTexture;	// オブジェクトの位置を書き込んだテクスチャ
	float4 _PositionTexture_TexelSize;
	float3 _PositionTextureOffset;
	float _PositionTextureScale;

	float GetDepthNearFar(float depth)
	{
		return lerp(_ProjectionParams.y, _ProjectionParams.z, depth);
	}

	float2 GetDepthUV(float2 screenPos)
	{
		float2 uv = (screenPos.xy + float2(1, 1)) * 0.5;
		
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
		float rayDepth = Linear01Depth(GetDepth(o.pos));
		
		float dist = min(GetDepthNearFar(depth - rayDepth), maxDistance);

		o.length = dist;
		o.pos += rayDir * o.length;

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
		const float delta = 0.01;

		return normalize(float3(
			GetNoise(pos + float4(-delta, 0, 0, 0)) - GetNoise(pos + float4(delta, 0, 0, 0)),
			GetNoise(pos + float4(0, -delta, 0, 0)) - GetNoise(pos + float4(0, delta, 0, 0)),
			GetNoise(pos + float4(0, 0, -delta, 0)) - GetNoise(pos + float4(0, 0, delta, 0))
			)) * 0.5 + 0.5;
	}

	ENDCG

	SubShader
	{
		Tags{ "Queue"="AlphaTest" }

		Pass
		{
			Tags{ "LightMode" = "ForwardBase" }

			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex raymarch_vert
			#pragma fragment raymarch_frag
			#pragma target 3.0
			#pragma multi_compile_fwdbase
			#include "AutoLight.cginc"

			//ライトの色
            fixed4 _LightColor0;

			struct v2f
			{
				float4 pos			: SV_POSITION;
				float4 screenPos	: TEXCOORD0;
				float4 worldPos		: TEXCOORD1;
				float3 worldNormal	: TEXCOORD2;
				float4 localPos		: TEXCOORD3;
				SHADOW_COORDS(4)
			};

			v2f raymarch_vert(appdata_full v)
			{
				v2f o;

				float4 pos = v.vertex;

				v.vertex.y = GetNoise(v.vertex);
				o.localPos = pos;

				o.pos = UnityObjectToClipPos(v.vertex);
				// ラスタライズしてフラグメントシェーダで各ピクセルの座標として使う
				o.screenPos = o.pos;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);

				TRANSFER_SHADOW(o)

				float3 normal = GetNormalNoise(pos);
				o.worldNormal = normal;

				return o;
			}

			half4 raymarch_frag(v2f i) : SV_TARGET
			{
				i.screenPos.xy /= i.screenPos.w;

				float3 normal = GetNormalNoise(i.localPos);
				
				// 球面調和
				float4 diff;
				diff.rgb = ShadeSH9(half4(normalize(mul(normal, (float3x3)unity_WorldToObject)), 1));
				diff.a = 1;

				raymarchOut rayOut;

				float3 rayDir = GetRayDir(i.screenPos);

				rayOut = raymarch(i.screenPos, i.worldPos, rayDir);

				float dens = saturate(rayOut.length / _MaxDistance * _Density);
				
				fixed shadow = SHADOW_ATTENUATION(i);
				half nl = max(0, dot(normal, _WorldSpaceLightPos0.xyz));
				fixed3 lighting = diff + nl * _LightColor0 * shadow;

				return half4(_Diffuse.rgb * lighting, dens);
			}
			ENDCG
		}
		
		// shadow caster rendering pass, implemented manually
        // using macros from UnityCG.cginc
        Pass
        {
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			Fog {Mode Off}

			ZWrite On 
			ZTest LEqual 
			Cull Back

            CGPROGRAM
            #pragma vertex vert_shadow
            #pragma fragment frag_shadow
            #pragma target 3.0	
			#pragma multi_compile_shadowcaster
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "UnityCG.cginc"

			struct v2f_shadow { 
				V2F_SHADOW_CASTER;
			};

			v2f_shadow vert_shadow(appdata_base v)
			{
				v2f_shadow o;

				float4 pos = v.vertex;
				float3 wpos = GetWorldPos(v.vertex);

				v.vertex.y = GetNoise(v.vertex);

				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)

				return o;
			}
			
			
			float4 frag_shadow(v2f_shadow i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			
            ENDCG
        }
		
	}

	Fallback "Transparent/VertexLit"
}
