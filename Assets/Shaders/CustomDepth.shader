// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/CustomDepth"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	
	SubShader
	{
		ZTest Always
		Cull Off
		ZWrite Off
		Fog{ Mode Off }
		Tags{ "RenderType" = "Opaque" }

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma vertex vert
			#pragma fragment frag
			#pragma only_renderers d3d9 d3d11 glcore gles gles3 metal xboxone ps4 
			#pragma target 3.0

			struct v2f 
			{
				float4 pos : SV_POSITION;
				float4 pos2 : TEXCOORD0;
				float2 uv : TEXCOORD1;
			};
			/*
			struct appdata
			{
				float4 vertex : POSITION;
				float4 pos2 : TEXCOORD0;
				float2 uv : TEXCOORD1;
			};
			*/

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
			sampler2D _MainTex;

			float2 GetDepthUV(float2 screenPos)
			{
				float2 uv = (screenPos.xy + float2(1, 1)) * 0.5;
#if UNITY_UV_STARTS_AT_TOP
				//uv.y = 1.0 - uv.y;
#endif
				return uv;
			}

			v2f vert(appdata_img  v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				//o.pos2 = o.pos;
				o.uv = MultiplyUV(UNITY_MATRIX_TEXTURE0, v.texcoord.xy);
				//o.uv = v.uv;
#if UNITY_UV_STARTS_AT_TOP
				//o.uv.y = 1.0 - o.uv.y;
#endif
				return o;
			}

			float4 frag(v2f i) : SV_TARGET
			{
				fixed4 col = tex2D(_MainTex, i.uv);

				//float2 uv = GetDepthUV(i.pos2);
				float2 uv = i.uv;
				//float depth = tex2D(_CameraDepthTexture, uv).r;
				//float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
				//float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv.xy);
				//float depth = SAMPLE_RAW_DEPTH_TEXTURE(_CameraDepthTexture, uv.xy);
				//float depth = Linear01Depth(SAMPLE_RAW_DEPTH_TEXTURE(_CameraDepthTexture, uv.xy));
				//float depth = Linear01Depth(tex2D(_CameraDepthTexture, uv.xy).x);
				//float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv.xy));
				//float depth = input.pos2.z / input.pos2.w; // Perspective division.
				//return depth.xxxx;
				//return depth;
				//float depth = 1.0 / (_ZBufferParams.x * tex2D(_CameraDepthTexture, uv.xy).x + _ZBufferParams.y);
				
				return tex2D(_CameraDepthTexture, uv);
				//return depth;
				//return col;
			}
			ENDCG
		}
	}
	
	/*
	SubShader {
         Tags { "RenderType"="Opaque" }
         Pass {
             ZWrite On
             ColorMask 0
             Fog { Mode Off }
         }
     }
	 */
}
