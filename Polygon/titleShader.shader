Shader "Geometry/TitlePolygon"
{
	Properties
	{
		_Texture("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1, 1, 1, 1)
		[Toggle(EnableDistChagnge)] _EnableDistChange("Enable Dist Change", Float) = 0
		[Toggle(EnableNormal Chagnge)] _EnableNormalChange("Enable Normal Change", Float) = 0
		
		_EmissiveTex("Emissive Tex", 2D) = "white" {}
		_EmissiveColor("Emissive Color", Color) = (1,1,1,1)
		
		_ScalePower("Scale Power", Range(-1,1)) = 0.5
		_RotationPower("Rotation Power", Range(0,1)) = 0.1
		_RotationSpeed("Rotation Speed", Float) = 1

		_StartDistance("Start Distance", Range(0,10)) = 3.0
		_EndDistance("End Distance", Range(0,10)) = 0.3

		_ScaleDistancePower("Scale Distance Power", Vector) = (1,1,1,1)
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		Cull Off
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geo
			#pragma fragment frag

			#include "UnityCG.cginc"

			// Texture設定
			fixed4 _Color;
			sampler2D _Texture;
			float4 _Texture_ST;

			sampler2D _EmissiveTex;
			float4 _EmissiveTex_ST;
			fixed4 _EmissiveColor;

			// Enable
			float _EnableDistChange;
			float _EnableNormalChange;

			// Polygon Setting
			float _ScalePower;
			float _RotationPower;
			float _RotationSpeed;
			float _StartDistance;
			float _EndDistance;
			float4 _ScaleDistancePower;


			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct g2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 distance : TEXCOORD1;
			};

			// 乱数
			float rand(float2 seed)
			{
				return frac(sin(dot(seed.xy, float2(12.9898, 78.233))) * 43758.5453);
			}

			// Pos, Angle, Axis
			float3 rotate(float3 pos, float angle, float3 axis)
           		{
                		float3 a = normalize(axis);
                		float s = sin(angle);
                		float c = cos(angle);
                		float r = 1.0 - c;
                		float3x3 m = float3x3(
                    			a.x * a.x * r + c, a.y * a.x * r + a.z * s, a.z * a.x * r - a.y * s,
                    			a.x * a.y * r - a.z * s, a.y * a.y * r + c, a.z * a.y * r + a.x * s,
                    			a.x * a.z * r + a.y * s, a.y * a.z * r - a.x * s, a.z * a.z * r + c
                			);

               			return mul(m, pos);
            		}

			// vertexShader
			appdata vert(appdata v)
			{
				return v;
			}


			// geometryShader
			[maxvertexcount(3)]
			void geo(triangle appdata input[3], inout TriangleStream<g2f> stream)
			{
				// カメラからポリゴンの重心の距離
				float3 center = (input[0].vertex + input[1].vertex + input[2].vertex) / 3;
				float4 worldPos = mul(unity_ObjectToWorld, float4(center, 1.0));
				float3 dist = length(_WorldSpaceCameraPos - worldPos);
				// -1と1に変換
				float distState = (_EnableDistChange * 2.0f) * -1.0f + 1.0f;
				
				// 法線
				float3 vec1 = input[1].vertex - input[0].vertex;
				float3 vec2 = input[2].vertex - input[0].vertex;
				float3 normal = normalize(cross(vec1, vec2));
				float normalState = (_EnableNormalChange * 2.0f) * -1.0f + 1.0f;

				// 近づくとポリゴン表示
				float destruction = clamp((distState * (_StartDistance - dist)) / (_StartDistance - _EndDistance), 0.0, 1.0);
				
				// 乱数
				float random = rand(center.xy);
				float3 random3 = random.xxx;

				[unroll]
				for (int i = 0; i < 3; i++)
				{
					g2f o;
					appdata v = input[i];
					
					// 法線ベクトルに合わせて移動, その場で回転
					float distRot = (_RotationPower * ((_RotationSpeed * _Time.y) * random3)) * destruction;

					// 回転、移動
					v.vertex.xyz = (v.vertex.xyz - center) * (1.0 - destruction * _ScalePower) + center;
					v.vertex.xyz = rotate(v.vertex.xyz - center, distRot, random3) + center;
					v.vertex.xyz += (normal * normalState) * destruction * random3;
					
					v.vertex.x *= _ScaleDistancePower.x;
					v.vertex.y *= _ScaleDistancePower.y;
					v.vertex.z *= _ScaleDistancePower.z;

					o.vertex = UnityObjectToClipPos(v.vertex);
					o.uv = v.uv;
					o.distance = dist;

					stream.Append(o);
				}

				stream.RestartStrip();
			}

			// fragmentShader
			fixed4 frag(g2f i) : SV_Target
			{
				fixed4 col = 1;
				col *= tex2D(_Texture, TRANSFORM_TEX(i.uv, _Texture)) * _Color;

				col = saturate(col);
				col += tex2D(_EmissiveTex, i.uv) * _EmissiveColor;
				return col;
			}
			ENDCG
		}
	}
}
