// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/DepthRender2"
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
      #pragma vertex Vertex
      #pragma fragment Fragment
	  #include "UnityCG.cginc"
      #pragma target 3.5
	  #pragma multi_compile __ DEPTH_DEBUG

	  sampler2D _MainTex;
      UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

	  float _XThreshold;
	  float _YThreshold;
	  float _ZThreshold;

	  float4x4 _InverseView;
	  half _Intensity;

	  struct Varyings
	  {
        float4 position : SV_POSITION;
        float2 texcoord : TEXCOORD0;
        float3 ray : TEXCOORD1;
      };

	  // Vertex shader that procedurally outputs a full screen triangle
    Varyings Vertex(uint vertexID : SV_VertexID)
    {
        // Render settings
        float far = _ProjectionParams.z;
        float2 orthoSize = unity_OrthoParams.xy;
        float isOrtho = unity_OrthoParams.w; // 0: perspective, 1: orthographic

        // Vertex ID -> clip space vertex position
        float x = (vertexID != 1) ? -1 : 3;
        float y = (vertexID == 2) ? -3 : 1;
        float4 vpos = float4(x, y, 1, 1);

        // Perspective: view space vertex position of the far plane
        float3 rayPers = mul(unity_CameraInvProjection, vpos) * far;

        // Orthographic: view space vertex position
        float3 rayOrtho = float3(orthoSize * vpos.xy, 0);

        Varyings o;
        o.position = vpos;
        o.texcoord = (vpos.xy + 1) / 2;
        o.ray = lerp(rayPers, rayOrtho, isOrtho);
        return o;
    }

    float3 ComputeViewSpacePosition(Varyings input)
    {
        // Render settings
        float near = _ProjectionParams.y;
        float far = _ProjectionParams.z;
        float isOrtho = unity_OrthoParams.w; // 0: perspective, 1: orthographic

        // Z buffer sample
        float z = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, input.texcoord);

        // Perspective: view space position = ray * depth
        float3 vposPers = input.ray * Linear01Depth(z);

        // Orthographic: linear depth (with reverse-Z support)
#if defined(UNITY_REVERSED_Z)
        float depthOrtho = -lerp(far, near, z);
#else
        float depthOrtho = -lerp(near, far, z);
#endif

        // Orthographic: view space position
        float3 vposOrtho = float3(input.ray.xy, depthOrtho);

        // Result: view space position
        return lerp(vposPers, vposOrtho, isOrtho);
    }

	half4 VisualizePosition(Varyings input, float3 pos)
    {
        half4 source = tex2D(_MainTex, input.texcoord);
        half3 color = pow(abs(cos(pos * UNITY_PI * 4)), 20);
        return half4(lerp(source.rgb, color, _Intensity), source.a);
    }

    half4 Fragment(Varyings input) : SV_Target
	{
		half4 source = tex2D(_MainTex, input.texcoord);
		float3 vpos = ComputeViewSpacePosition(input);
        float3 wpos = mul(_InverseView, float4(vpos, 1)).xyz;
#ifdef DEPTH_DEBUG
		float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, input.texcoord).x );
		return half4(depth, depth, depth, 1);
#else
		return  lerp(source, half4(wpos.x < _XThreshold ? 0 : 1, wpos.y < _YThreshold ? 0 : 1, wpos.z < _ZThreshold ? 0 : 1, 1), _Intensity);
#endif
        //return VisualizePosition(input, wpos);
    }
      ENDCG
    }
  }
}
