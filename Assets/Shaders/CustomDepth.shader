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
				float2 uv : TEXCOORD1;
			};

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
			sampler2D _MainTex;

			v2f vert(appdata_img  v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = MultiplyUV(UNITY_MATRIX_TEXTURE0, v.texcoord.xy);
				return o;
			}

			float4 frag(v2f i) : SV_TARGET
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				
				return tex2D(_CameraDepthTexture, i.uv);
			}
			ENDCG
		}
	}
	
}
