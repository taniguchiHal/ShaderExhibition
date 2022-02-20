Shader "summerSea"
{
	Properties
	{
		_GradientPower("Gradient Power", Range(0, 100)) = 10
		_ReflectionPower("Reflection Power", Range(1, 2)) = 1

		[Toggle(EnableFoam)] _EnableFoam("Enable Foam", Float) = 0
		_FoamTex("Foam Texture", 2D) = "white" {}
		_FoamSize("Foam Size", Float) = 1

		[Header(FoamDrawing)] 
		_EnableDrawingDist("Enable Drawing Dist", Range(0,1)) = 0
		_DrawingDistPower("Foam Draw Dist Power", Range(0, 0.5)) = 0.005
		_EdgeWidth("WaterEdgeWidth", Range(0, 10)) = 7.0
		_EdgeFalloff("EdgeFalloff", Range(0, 1.0)) = 0.386

		_FoamScrollSpeed("Nosie Scroll Speed", Float) = 1
	}
	
	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				UNITY_FOG_COORDS(4)
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;

				float3 worldNormal : TEXCOORD1;
				float4 projPos : TEXCOORD2;
				float3 worldPos : TEXCOORD3;
			};


			sampler2D _FoamTex;
			float _EnableFoam;
			float _FoamSize;
			float _EnableDrawingDist;
			float _DrawingDistPower;
			

			float _GradientPower;
			float _ReflectionPower;
			
			float _EdgeWidth;
			float _EdgeFalloff;

			float _FoamScrollSpeed;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);

				o.projPos = ComputeScreenPos(o.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				COMPUTE_EYEDEPTH(o.projPos.z);

				return o;
			}

			// https://sp4ghet.github.io/grad/
			fixed4 cosine_gradient(float x, fixed4 phase, fixed4 amp, fixed4 freq, fixed4 offset) {
				const float TAU = 2. * 3.14159265;
				phase *= TAU;
				x *= TAU;

				return fixed4(
					offset.r + amp.r * 0.5 * cos(x * freq.r + phase.r) + 0.5,
					offset.g + amp.g * 0.5 * cos(x * freq.g + phase.g) + 0.5,
					offset.b + amp.b * 0.5 * cos(x * freq.b + phase.b) + 0.5,
					offset.a + amp.a * 0.5 * cos(x * freq.a + phase.a) + 0.5
				);
			}
			fixed3 toRGB(fixed3 grad) {
				return grad.rgb;
			}


			// valueNoise
			float2 random2(float2 st) {
				st = float2(dot(st, float2(127.1, 311.7)),
					dot(st, float2(269.5, 183.3)));
				return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
			}
			// perinNoise
			float perlinNoise(fixed2 st)
			{
				st.y += _Time[1];
				fixed2 p = floor(st);
				fixed2 f = frac(st);
				fixed2 u = f * f * (3.0 - 2.0 * f);

				float v00 = random2(p + fixed2(0, 0));
				float v10 = random2(p + fixed2(1, 0));
				float v01 = random2(p + fixed2(0, 1));
				float v11 = random2(p + fixed2(1, 1));

				return lerp(lerp(dot(v00, f - fixed2(0, 0)), dot(v10, f - fixed2(1, 0)), u.x),
					lerp(dot(v01, f - fixed2(0, 1)), dot(v11, f - fixed2(1, 1)), u.x),
					u.y) + 0.5f;
			}

			// ノイズをハイトマップに
			// http://marupeke296.com/Shader_No3_WaveSin.html
			float3 swell(float3 normal, float3 pos, float anisotropy) {
				float height = perlinNoise(pos.xz * 0.1);
				height *= anisotropy;
				normal = normalize(
					cross(
						float3(0, ddy(height), 1),
						float3(1, ddx(height), 0)
					)
				);
				return normal;
			}

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);


			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 col = 1;
				
				// 深度計算
				float sceneZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
				float partZ = i.projPos.z;
				float depth = sceneZ - partZ;
				float fadeVolume = saturate(depth / _GradientPower);

				// foam
				// http://fire-face.com/personal/water/
				float2 foamUV = i.worldPos.xz * _FoamSize;
				float scrollFoam = _FoamScrollSpeed * _Time.y;
				float foamTexR = tex2D(_FoamTex, foamUV - float2(scrollFoam, cos(foamUV.x))).r;
				float foamTexB = tex2D(_FoamTex, foamUV * 0.5 + float2(cos(foamUV.y), scrollFoam)).b;
				float mask = (foamTexR + foamTexB) * 0.95;
				mask = saturate(mask * mask);

				float fa = 0;	
				if (depth < _EdgeWidth * _EdgeFalloff) {
					fa = depth / (_EdgeWidth * _EdgeFalloff);
					mask *= fa;
				}

				float falloff = 1.0 - saturate(depth / _EdgeWidth);
				float depthFoam = saturate(falloff - mask);
				depthFoam = mul(depthFoam, _EnableFoam);

				// FoamDrawingDist
				float length2 = length(_WorldSpaceCameraPos - i.worldPos);
				depthFoam = mul(depthFoam, length2 * _EnableDrawingDist);
				depthFoam = mul(depthFoam, length2 * _DrawingDistPower);
				depthFoam = saturate(depthFoam);

				

				// グラデーション値設定
				const fixed4 phases = fixed4(0.28, 0.50, 0.07, 0.);
				const fixed4 amplitudes = fixed4(4.02, 0.34, 0.65, 0.);
				const fixed4 frequencies = fixed4(0.00, 0.48, 0.08, 0.);
				const fixed4 offsets = fixed4(0.00, 0.16, 0.00, 0.);
				fixed4 cos_grad = cosine_gradient(1 - fadeVolume, phases, amplitudes, frequencies, offsets);
				cos_grad = clamp(cos_grad, 0, 1);
				col.rgb = toRGB(cos_grad);
				col.a = saturate(fadeVolume);

				half3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

				//エイリアシング防止
				float3 v = i.worldPos - _WorldSpaceCameraPos;
				float anisotropy = saturate(1 / (ddy(length(v.xz))) / 5);
				float3 swelledNormal = swell(i.worldNormal, i.worldPos, anisotropy);

				// 視線ベクトルを水面で反射させてskyboxから色を取得
				half3 reflDir = reflect(-worldViewDir, swelledNormal);
				fixed4 reflectionColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 0);

				// フレネル反射計算
				// Fr(θ)=F0+(1−F0)(1−cosθ)^5
				// https://ja.wikipedia.org/wiki/%E3%83%95%E3%83%AC%E3%83%8D%E3%83%AB%E3%81%AE%E5%BC%8F
				float f0 = 0.04;
				float vReflect = f0 + (1 - f0) * pow(
					(1 - dot(worldViewDir, swelledNormal)),
					5);
				vReflect = saturate(vReflect * _ReflectionPower);
				

				fixed4 refCol = lerp(col, reflectionColor, vReflect);
				fixed4 foamCol = lerp(refCol, 1, depthFoam);
				col = lerp(refCol, foamCol, foamCol.z);

				return col;
			}
			ENDCG
		}
	}
}
