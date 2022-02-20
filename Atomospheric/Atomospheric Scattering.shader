Shader "yomo/Atomospheric Scattering"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_InnerRadius("InnerRadius", Float) = 10000
		_OuterRadius("OuterRadius", Float) = 10250
		_Kr("RayleighScatteringCoefficient", Float) = 0.0025
		_Km("MieScatteringCoefficient", Float) = 0
	}
		SubShader
		{
			Tags { "RenderType" = "Background" "Queue" = "Background" "Preview Type" = "Skybox"}

			Pass
			{
				Tags { "LightMode" = "ForwardBase" }

				Cull Off

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag

				#include "UnityCG.cginc"

				#define PI 3.14159265359

				struct appdata
				{
					float4 vertex : POSITION;
					float2 uv : TEXCOORD0;
				};

				struct v2f
				{
					float2 uv : TEXCOORD0;
					float4 vertex : SV_POSITION;
					float3 worldPos :TEXCOORD1;
				};

				sampler2D _MainTex;
				float4 _MainTex_ST;

				float _InnerRadius;
				float _OuterRadius;

				// レイリー散乱
				float _Kr;
				// ミー散乱
				float _Km;

				// 計算用const変数
				static const float fSamples = 2.0;

				static const float3 three_primary_colors = float3(0.68, 0.55, 0.44);
				static const float3 v3InvWaveLength = 1.0 / pow(three_primary_colors, 4.0);

				static const float fOuterRadius = _OuterRadius;
				static const float fInnerRadius = _InnerRadius;

				static const float fESun = 20.0;
				static const float fKrESun = _Kr * fESun;
				static const float fKmESun = _Km * fESun;

				static const float fKr4PI = _Kr * 4.0 * PI;
				static const float fKm4PI = _Km * 4.0 * PI;

				static const float fScale = 1.0 / (_OuterRadius - _InnerRadius);;
				static const float fScaleDepth = 0.25;
				static const float fScaleOverScaleDepth = fScale / fScaleDepth;

				static const float g = -0.999f;
				static const float g2 = g * g;


				v2f vert(appdata v)
				{
					v2f o;
					float4 vt = v.vertex;
					o.vertex = UnityObjectToClipPos(vt);
					o.uv = TRANSFORM_TEX(v.uv, _MainTex);
					o.worldPos = normalize(mul(unity_ObjectToWorld, vt).xyz) * fOuterRadius;
					return o;
				}

				float Scale(float fcos) {
					float x = 1.0 - fcos;
					return fScaleDepth * exp(-0.00287 + x * (0.459 + x * (3.83 + x * (-6.8 + x * 5.25))));
				}

				float3 IntersectionPos(float3 dir, float3 a, float radius)
				{
					float b = dot(a, dir);
					float c = dot(a, a) - radius * radius;
					float d = max(b * b - c, 0.0);

					return a + dir * (-b + sqrt(d));
				}

				fixed4 frag(v2f i) : SV_Target
				{
					float3 worldPos = i.worldPos;
					worldPos = IntersectionPos(normalize(worldPos), float3(0.0, fInnerRadius, 0.0), fOuterRadius);
					float3 v3CameraPos = float3(0.0, fInnerRadius, 0.0);
					float3 v3LightDir = normalize(UnityWorldSpaceLightDir(worldPos));

					float3 v3Ray = worldPos - v3CameraPos;
					float fFar = length(v3Ray);
					v3Ray /= fFar;

					float3 v3Start = v3CameraPos;
					float fCameraHeight = length(v3CameraPos);
					float fStartAngle = dot(v3Ray, v3Start) / fCameraHeight;
					float fStartDepth = exp(fScaleOverScaleDepth * (fInnerRadius - fCameraHeight));
					float fStartOffset = fStartDepth * Scale(fStartAngle);

					float fSampleLength = fFar / fSamples;
					float fScaledLength = fSampleLength * fScale;
					float3 v3SampleRay = v3Ray * fSampleLength;
					float3 v3SamplePoint = v3Start + v3SampleRay * 0.5;

					float3 v3FrontColor = 0.0;
					for (int n = 0; n < int(fSamples); n++) {
						float fHeight = length(v3SamplePoint);
						float fDepth = exp(fScaleOverScaleDepth * (fInnerRadius - fHeight));
						float fLightAngle = dot(v3LightDir, v3SamplePoint) / fHeight;
						float fCameraAngle = dot(v3Ray, v3SamplePoint) / fHeight;
						float fScatter = (fStartOffset + fDepth * (Scale(fLightAngle) - Scale(fCameraAngle)));
						float3 v3Attenuate = exp(-fScatter * (v3InvWaveLength * fKr4PI + fKm4PI));
						v3FrontColor += v3Attenuate * (fDepth * fScaledLength);
						v3SamplePoint += v3SampleRay;
					}

					float3 c0 = v3FrontColor * (v3InvWaveLength * fKrESun);
					float3 c1 = v3FrontColor * fKmESun;
					float3 v3Direction = v3CameraPos - worldPos;

					float fcos = dot(v3LightDir, v3Direction) / length(v3Direction);
					float fcos2 = fcos * fcos;

					float rayleighPhase = 0.75 * (1.0 + fcos2);
					float miePhase = 1.5 * ((1.0 - g2) / (2.0 + g2)) * (1.0 + fcos2) / pow(1.0 + g2 - 2.0 * g * fcos, 1.5);

					fixed4 col = 1.0;
					col.rgb = rayleighPhase * c0 + miePhase * c1;
					return col;
				}
				ENDCG
			}
		}
}