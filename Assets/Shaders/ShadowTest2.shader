// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Shadow/ShadowTest2"
{
	SubShader
	{
		Pass
		{
			Name "ShadowCast"
			Tags {"LightMode" = "ShadowCaster"}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"

			struct v2f {
					V2F_SHADOW_CASTER;
			};

			v2f vert(appdata_base v)
			{
					v2f o;
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
					return o;
			}

			float4 frag(v2f i) : SV_Target
			{
					SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}

		Pass
		{
			Name "ShadowReceive"
			Tags {"LightMode" = "ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			#pragma multi_compile_fwdbase

			// shadow helper functions and macros
			#include "AutoLight.cginc"

			struct v2f
			{
				float2 uv : TEXCOORD0;
				SHADOW_COORDS(1) // put shadows data into TEXCOORD1

				float4 pos : SV_POSITION;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				// compute shadows data
				TRANSFER_SHADOW(o)
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				//fixed4 col = fixed4(0.5,0.5,0.5,1);
				fixed4 col = fixed4(1,1,1,1);
				// compute shadow attenuation (1.0 = fully lit, 0.0 = fully shadowed)
				fixed shadow = SHADOW_ATTENUATION(i);
				col.rgb *= shadow;
				return col;
			}

			ENDCG
		}

	}
}