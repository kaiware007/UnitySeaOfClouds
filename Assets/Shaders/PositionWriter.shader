Shader "Custom/PositionWriter"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			struct PositionData
			{
				float2 position;    // 座標
				float radius;		// 円の半径
			};

			sampler2D _MainTex;
			float4 _MainTex_TexelSize;
			float4 _MainTex_ST;
			
			StructuredBuffer<PositionData> _PositionBuffer;
			int _PositionIndex;
			//float2 _InvWorldScale;
			float _FadeoutPower;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{
				// old texture
				float col = DecodeFloatRGBA(tex2D(_MainTex, i.uv));

				// 円描画
				float circleCol = (float)0;
				for(int j = 0; j < _PositionIndex; j++){
					float2 pos = _PositionBuffer[j].position;
					float radius = _PositionBuffer[j].radius;
					float len = smoothstep(0, 1, radius / length(i.uv - pos));
					circleCol += saturate(len);
				}
				
				return EncodeFloatRGBA(saturate(circleCol + col) * _FadeoutPower);
			}
			ENDCG
		}
	}
}
