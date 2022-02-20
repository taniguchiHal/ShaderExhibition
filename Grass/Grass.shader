Shader "Geometry/Grass"
{
	Properties
	{
		[Header(Shading)]
		_TopColor("Top Color", Color) = (1,1,1,1)
		_BottomColor("Bottom Color", Color) = (1,1,1,1)
		_BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2
		_TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1

		[Header(Blade)]
		_BladeWidth("Blade Width", Float) = 0.05
		_BladeWidthRandom("Blade Width Random", Float) = 0.02
		_BladeHeight("Blade Height", Float) = 0.5
		_BladeHeightRandom("Blade Height Random", Float) = 0.3

		[Header(Wind)]
		_WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
		_WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
		_WindStrength("Wind Strength", Float) = 1

		[Header(ObjectHit)]
		_PlayerPos("Player Position", Vector) = (0, 0, 0, 0)
		_PlayerRadius("Player Hit Radius", Float) = 0
		_PlayerFallDownGrass("Player Fall Down Grass", Float) = 1
	}

		CGINCLUDE
		#include "UnityCG.cginc"
		#include "Autolight.cginc"
		#include "CustomTessellation.cginc"

		struct g2f
		{
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;

			unityShadowCoord4 _ShadowCoord : TEXCOORD1;
		};

		// Simple noise
		// http://answers.unity.com/answers/624136/view.html
		float rand(float3 co)
		{
			return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
		}

		// 3x3 Rotation matrix with an angle and an arbitrary vector
		// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
		float3x3 AngleAxis3x3(float angle, float3 axis)
		{
			float c, s;
			sincos(angle, s, c);

			float t = 1 - c;
			float x = axis.x;
			float y = axis.y;
			float z = axis.z;

			return float3x3(
				t * x * x + c, t * x * y - s * z, t * x * z + s * y,
				t * x * y + s * z, t * y * y + c, t * y * z - s * x,
				t * x * z - s * y, t * y * z + s * x, t * z * z + c
				);
		}

		g2f VertexOutput(float3 pos, float2 uv)
		{
			g2f o;
			o.pos = UnityObjectToClipPos(pos);
			o.uv = uv;
			o._ShadowCoord = ComputeScreenPos(o.pos);
			return o;
		}

		g2f GenerateGrassVertex(float3 vertexPosition, float width, float height, float2 uv, float3x3 transformMatrix)
		{
			float3 tangentPoint = float3(width, 0, height);
			float3 localPosition = vertexPosition + mul(transformMatrix, tangentPoint);
			return VertexOutput(localPosition, uv);
		}

		ENDCG

		SubShader
		{
			Cull Off

			Pass
			{
				Tags
				{
					"RenderType" = "Opaque"
					"LightMode" = "ForwardBase"
				}

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma geometry geo
				#pragma hull hull
				#pragma domain domain
				#pragma target 4.6
				#pragma multi_compile_fwdbase

				#include "Lighting.cginc"

				#define BLADE_SEGMENTS 3

				float4 _TopColor;
				float4 _BottomColor;
				float _BendRotationRandom;

				float _BladeWidth;
				float _BladeHeightRandom;
				float _BladeHeight;
				float _BladeWidthRandom;

				sampler2D _WindDistortionMap;
				float4 _WindDistortionMap_ST;
				float2 _WindFrequency;
				float _WindStrength;

				// �O��Param
				float4 _PlayerPos;

				float _PlayerRadius;
				float _PlayerFallDownGrass;

				[maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
				void geo(triangle vertexOutput IN[3], inout TriangleStream<g2f> triStream)
				{
					g2f o;
					float3 pos = IN[0].vertex;
					// �ڋ�Ԃ����߂�->�I�u�W�F�N�g�̐ڐ��ɐ����Ȑ����K�v
					//->2�x�N�g���̊O�ς����߂�3�x�N�g�����
					float3 vNormal = IN[0].normal;
					float4 vTangent = IN[0].tangent;
					float3 vBinormal = cross(vNormal, vTangent) * vTangent.w;

					// �ڋ��3�x�N�g���̍s��
					float3x3 tangentToLocal = float3x3(
						vTangent.x, vBinormal.x, vNormal.x,
						vTangent.y, vBinormal.y, vNormal.y,
						vTangent.z, vBinormal.z, vNormal.z
						);


					float4 worldPos = mul(unity_ObjectToWorld, IN[0].vertex);

					// interactive
					float3 dis = distance(_PlayerPos, worldPos);		// ���_�̃��[���h���W�ƃv���C���[�̍��W�̋���
					float3 radius = 1 - saturate(dis / _PlayerRadius); 
					float3 sphereDisp = worldPos - _PlayerPos;
					sphereDisp *= radius;
					sphereDisp = clamp(sphereDisp.xyz, -0.8, 0.8);

					float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom - _BladeHeight;
					float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;

					// texture�g�p
					float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * (_Time.y);
					float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;	// 0~1�͈̔͂���-1~1�͈̔͂ɍăX�P�[�����O
					float3 wind = normalize(float3(windSample.x, windSample.y, 0));

					// rand()�̈����͈ʒu���g�p����
					float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));							// �p�x�𐶐�
					float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0)); // UNITY_PI*0.5��0~90�x
					float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);
					float3x3 transformationMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix), bendRotationMatrix);	// ��L������tangentToLocal����Z
					float3x3 transformationMatrixFacing = mul(tangentToLocal, facingRotationMatrix);		// �ڋ�Ԃ��g�p���ď�Z

					// 6���_�쐬 -> 1roop�ɂ�2���_�ǉ�
					for (int i = 0; i < BLADE_SEGMENTS; i++) {
						float t = i / (float)BLADE_SEGMENTS;
						float segmentHeight = height * t;
						float segmentWidth = width * (1 - t);
						float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

						float3 interactivePos = i == 0 ? IN[0].vertex : IN[0].vertex + ((float3(sphereDisp.x, sphereDisp.y, sphereDisp.z) + wind) * t);

						triStream.Append(GenerateGrassVertex(interactivePos, segmentWidth, segmentHeight, float2(0, t), transformMatrix));
						triStream.Append(GenerateGrassVertex(interactivePos, -segmentWidth, segmentHeight, float2(1, t), transformMatrix));
					}

					// ���̈�ԏ�ƂȂ�vertex
					triStream.Append(GenerateGrassVertex(
						IN[0].vertex + float3(sphereDisp.x * _PlayerFallDownGrass, 0, sphereDisp.z * _PlayerFallDownGrass) + float3(wind.x, wind.y * 1.2, 0),
						0,
						height,
						float2(0.5, 1),
						transformationMatrix));

					triStream.RestartStrip();
				}

				// fragmentShader
				float4 frag(g2f i, fixed facing : VFACE) : SV_Target
				{
					float4 color = lerp(_BottomColor, _TopColor, i.uv.y);
					color *= _LightColor0;
					color = saturate(color);

					#ifdef EnableShadow
					return SHADOW_ATTENUATION(i);
					#endif
					return color;
				}
				ENDCG
			}
		}
}