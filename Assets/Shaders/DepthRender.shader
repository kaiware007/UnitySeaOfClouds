// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/DepthRender"
{
	Properties
	{
		_MainTex ("Main Texture", 2D) = "" {}
		_XThreshold("X Threshold", Float) = 0
		_YThreshold("Y Threshold", Float) = 0
		_ZThreshold("Z Threshold", Float) = 0
		[Toggle(DEPTH_DEBUG)] _DepthDebug("Depth Debug", Float) = 0
	}

    SubShader {
    ZTest Always
    Cull Off
    ZWrite Off
    Fog{ Mode Off }

    Tags{ "RenderType" = "Opaque" }

    Pass {
      CGPROGRAM
      #pragma vertex vert
      #pragma fragment frag
      #include "UnityCG.cginc"
      #pragma target 3.0
	  #pragma multi_compile __ DEPTH_DEBUG

	  sampler2D _MainTex;
      UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

	  float _XThreshold;
	  float _YThreshold;
	  float _ZThreshold;

	  float4x4 _TRS;
	  float4x4 _InvVP;
	  half _Intensity;

      struct v2f {
	    float4 pos : SV_POSITION;
		float4 screenPos : TEXCOORD0;
	    float2 uv : TEXCOORD1;
      };

      v2f vert (appdata_img v) {
	    v2f o = (v2f)0;
	    o.pos = UnityObjectToClipPos(v.vertex);
		o.screenPos = o.pos;
	    o.uv = MultiplyUV(UNITY_MATRIX_TEXTURE0, v.texcoord.xy);
	    return o;
      }

	  float2 GetScreenPos(float4 screenPos) {
#if UNITY_UV_STARTS_AT_TOP
	    screenPos.y *= -1.0;
#endif
		screenPos.x *= _ScreenParams.x / _ScreenParams.y;
		return screenPos.xy / screenPos.w;
		//return screenPos.xy;
	  }

	  float3 GetCameraForward()     { return UNITY_MATRIX_V[2].xyz;    }
	  float3 GetCameraUp()          { return UNITY_MATRIX_V[1].xyz;     }
	  float3 GetCameraRight()       { return UNITY_MATRIX_V[0].xyz;     }
	  float  GetCameraFocalLength() { return abs(UNITY_MATRIX_P[1][1]); }

	  float3 GetRayDirection(float4 screenPos) {
		float2 sp = GetScreenPos(screenPos);

		float3 camDir      = GetCameraForward();
		float3 camUp       = GetCameraUp();
		float3 camSide     = GetCameraRight();
		float  focalLen    = GetCameraFocalLength();

		return normalize((camSide * sp.x) + (camUp * sp.y) + (camDir * focalLen));
	  }

	  float depthLength(float depth)
	  {
		return lerp(_ProjectionParams.y, _ProjectionParams.z, depth);
	  }

	  float3 GetPositionFromDepth(float depth, float2 uv, float4x4 invVP)
	  {
		//float len = depthLength(depth);
		float4 projPos = float4(uv.xy * 2.0 - float2(1.0, 1.0), depth, 1.0);
		//float4 projPos = float4(uv.xy, depth, 1.0);
		//projPos.xyz *= len;
		float4 pos = mul(invVP, projPos);
		//pos.y *= -_ProjectionParams.x;
		//float len = depthLength(pos.w);
		//float4 pos = mul(unity_CameraInvProjection, projPos);
		pos.xyz *= pos.w * 0.25;
		
		//return mul(_InvVP, float4(pos.xyz, 1)).xyz;

		//pos.z *= len;
		return pos.xyz;
		//return pos.xyz * len;
		//return pos.xyz / pos.w * len;
		//return pos.xyz / pos.w;
	  }

      float4 frag(v2f i) : SV_TARGET{
		half4 source = tex2D(_MainTex, i.uv);
		float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv).x );
		//float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv).x;
		//float3 cameraPos = _WorldSpaceCameraPos;
		//float3 rayDir = GetRayDirection(i.screenPos);
		//rayDir = mul(_TRS, rayDir);
		//float screenDistance = length(i.screenPos.xy);

		//rayDir.z *= screenDistance + 1.0;
		//rayDir.z /= 1 - screenDistance * 0.2;
		//depth *= screenDistance + 1.0;

		//float3 depthPos = cameraPos + rayDir * depthLength(depth);
		//float3 depthPos = cameraPos + GetPositionFromDepth(depth, i.uv, _InvVP);
		float3 depthPos = GetPositionFromDepth(depth, i.uv, _InvVP);
		//float3 depthPos =  (GetPositionFromDepth(depth, i.uv, _InvVP)) * depthLength(depth);

#ifdef DEPTH_DEBUG
		return float4(depth, depth, depth, 1);
#else
		return  lerp(source, float4(depthPos.x < _XThreshold ? 0 : 1, depthPos.y < _YThreshold ? 0 : 1, depthPos.z < _ZThreshold ? 0 : 1, 1), _Intensity);
#endif
      }
      ENDCG
    }
  }
}
