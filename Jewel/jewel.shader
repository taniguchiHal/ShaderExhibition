Shader "Jewel"
{
    Properties
    {
        [Header(Layer0)]
        _LayerTex("Layer Tex",2D) = "white"{}
        _LayerTint("Layer Tint",COLOR) = (1,1,1,1)

	[Header(Layer1)]
	[Toggle(EnableLayer1)] _EnableLayer1("Enable", Float) = 0
	_Layer1Tex("Layer1 Tex",2D) = "white"{}
	_Layer1Tint("Layer1 Tint", COLOR) = (1,1,1,1)

	[Header(Layer2)]
	[Toggle(EnableLayer2)] _EnableLayer2("Enable", Float) = 0
	_Layer2Tex("Layer2 Tex",2D) = "white"{}
	_Layer2Tint("Layer2 Tint", COLOR) = (1,1,1,1)

        [Header(Layers Global Properties)]
        _LayerHeightBias("Layer Height Start Bias", Range(0.0, 0.2)) = 0.1
        _LayerHeightBiasStep("Layer Height Step", Range(0.0, 0.3)) = 0.1
        _LayerDepthFalloff("Layer Depth Fallofff", Range(0.0, 1.0)) = 0.9

        [Header(Volumetric Marble)]
        _MarbleTex("Marble Heightmap Texture", 2D) = "black" {}
        _MarbleTint("Marble Tint", COLOR) = (1,1,1,1)
        _MarbleHeightScale("Marble Height Scale", Range(0.0, 0.5)) = 0.1
        _MarbleHeightCausticOffset("Marble Caustic Offset", Range(-5.0, 5.0)) = 0.1

        [Header(Caustic)]
        [Toggle(EnableCaustic)] _EnableCaustic("Enable Caustic", Float) = 0
        _CausticMap("Caustic Map",2D) = "black" {}
        _CausticTint("Caustic Tint", COLOR) = (1,1,1,1)
        _CausticScrollSpeed("Caustic Scroll Speed X", Range(-5.0,5.0)) = 1.0

        [Header(Fresnel)]
        [Toggle(EnableFresnel)] _EnableFresnel("Enable", Float) = 0
        _FresnelTightness("Fresnel Tightness", Range(0.0, 10.0)) = 4.0
        _FresnelColorInside("Fresnel Color Inside", COLOR) = (1,1,0.5,1)
        _FresnelColorOutside("Fresnel Color Outside", COLOR) = (1,1,1,1)

	[Header(Specular)]
	[Toggle(EnableSpecular)] _EnableSpeqular("Enable", Float) = 0
	_SpecularTightness("Specular Tightness", Range(0.0, 40.0)) = 1.0
	_SpecularBrightness("Specular Brightness", Range(0.0, 5.0)) = 1.0

        [Header(Refraction)]
        [Toggle(EnableRefraction)] _EnableRefraction("Enable Refraction", Float) = 0
        _RefractionStrength("Refraction Strength", Range(0.0, 1.0)) = 0.2

        [Header(Fog)]
        [Toggle(EnableFog)] _EnableFog("Enable Fog", Float) = 0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
	Tags { "LightMode" = "ForwardBase" }
        LOD 100
        GrabPass{"_GrabTexture"}

        Pass{
            CGPROGRAM

            // shaderFeature
            #pragma shader_feature __ EnableLayer1
            #pragma shader_feature __ EnableLayer2
            #pragma shader_feature __ EnableRefraction
            #pragma shader_feature __ EnableCaustic
            #pragma shader_feature __ EnableFresnel
            #pragma shader_feature __ EnablePrism
            #pragma shader_feature __ EnableSpecular

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 pos : POSITION;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
                float2 uv : TEXCOORD0;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;

                float4 lightData : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldNormal : TEXCOORD3;
                float3 worldRefl : TEXCOORD4;
                float3 worldViewDir : TEXCOORD5;
                float3 camPosTexcoord : TEXCOORD6;
                float4 screenPos : TEXCOORD7;
                float3 viewNormal : TEXCOORD8;

                #if defined(EnableFog)
                UNITY_FOG_COORDS(9)
                #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };


            // layerTex
            sampler2D _LayerTex;
            fixed4 _LayerTint;
            float4 _LayerTex_ST;

	    sampler2D _Layer1Tex;
	    fixed4 _Layer1Tint;
	    float4 _Layer1Tex_ST;

	    sampler2D _Layer2Tex;
	    fixed4 _Layer2Tint;
	    float4 _Layer2Tex_ST;

            // global layer param
            float _LayerDepthFalloff;
            float _LayerHeightBias;
            float _LayerHeightBiasStep;

            // marble tex
            sampler2D _MarbleTex;
            float4 _MarbleTex_ST;
            fixed4 _MarbleTint;
            float _MarbleHeightScale;
            float _MarbleHeightCausticOffset;

            // caustic tex
            sampler2D _CausticMap;
            float4 _CausticMap_ST;
            fixed4 _CausticTint;
            float _CausticScrollSpeed;

            // fresnel
            float fresnelPower = 4;
            float fresnelScale = 0.1f;
            float fresnelBias = -0.2f;
	    float _FresnelTightness;
	    float4 _FresnelColorInside;
	    float4 _FresnelColorOutside;

            // specular
	    float _SpecularTightness;
	    float _SpecularBrightness;

            float3 etaRatio = float3(0.83f,0.67f,0.55f);
            sampler2D _GrabTexture;

            // refrection
            float _RefractionStrength;


            v2f vert(appdata v)
            {
                float3 localPos = v.pos;
                float3 worldPos = mul(unity_ObjectToWorld, v.pos).xyz;
                float3 worldNormal = normalize(mul(unity_ObjectToWorld, float4(v.normal, 0.0)).xyz);
                float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                float3 binormal = cross(v.tangent, v.normal);
                float3x3 tbn = float3x3(v.tangent, binormal, v.normal);

                float3 camPosLocal = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0)).xyz;
                float3 dirToCamLocal = camPosLocal - localPos;
                float3 camPosTexcoord = mul(tbn, dirToCamLocal);

                
                v2f o;
                
                // unity
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_SETUP_INSTANCE_ID(y);
                UNITY_TRANSFER_INSTANCE_ID(y, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos = UnityObjectToClipPos(localPos);
                o.uv = v.uv;
                o.worldNormal = worldNormal;
                o.worldRefl = reflect(-worldViewDir, worldNormal);
                o.worldPos = worldPos;
                o.worldViewDir = worldViewDir;
                o.camPosTexcoord = camPosTexcoord;
                o.screenPos = ComputeScreenPos(o.pos);
                o.viewNormal = normalize(mul(UNITY_MATRIX_MV, float4(v.normal, 0.0)).xyz);

                // fog
                #if defined(EnableFog)
                UNITY_TRANSFER_FOG(o, o.pos);
                #endif

                return o;
            }


            fixed4 frag(v2f i) : SV_Target
            {
	        float phong = saturate(dot(i.worldNormal, normalize(_WorldSpaceCameraPos - i.worldPos)));
                UNITY_SETUP_INSTANCE_ID(i);

                // heightMapUV
                float2 uvMarble = i.uv;

                // caustic sampling
                #ifdef EnableCaustic
                float caustic = tex2D(_CausticMap, TRANSFORM_TEX(i.uv, _CausticMap) + float2(0.0, _Time.x * _CausticScrollSpeed)).r;
                uvMarble += float2(caustic, _Time.x) * _MarbleHeightCausticOffset;
                #endif

                // height-field offset
                float3 eyeVec = normalize(i.camPosTexcoord);
                float height = tex2D(_MarbleTex, TRANSFORM_TEX(uvMarble, _MarbleTex)).r;

                // heightMap用uv
                float v = height * _MarbleHeightScale - (_MarbleHeightScale * 0.5);

                // marble用UV
                float2 marbleUV = i.uv + eyeVec.xy * v;


                float3 colorLayerAccum = float3(0.0, 0.0, 0.0);
                float layerDepthFalloffAccum = 1.0;
                float layerHeightBiasAccum = _LayerHeightBias;

                // layer0
                float2 layerBaseUV = TRANSFORM_TEX(i.uv, _LayerTex);
                float2 layerParallaxUV = layerBaseUV + eyeVec.xy * v + eyeVec.xy * -layerHeightBiasAccum;

                colorLayerAccum += tex2D(_LayerTex, layerParallaxUV).xyz * layerDepthFalloffAccum * _LayerTint.xyz;
                layerDepthFalloffAccum *= _LayerDepthFalloff;
                layerHeightBiasAccum += _LayerHeightBiasStep;

                // layer1
	        #ifdef EnableLayer1
	        layerBaseUV = TRANSFORM_TEX(i.uv, _Layer1Tex);
	        layerParallaxUV = layerBaseUV + eyeVec.xy * v + eyeVec.xy * -layerHeightBiasAccum;

	        colorLayerAccum += tex2D(_Layer1Tex, layerParallaxUV).xyz * layerDepthFalloffAccum * _Layer1Tint.xyz;
	        layerDepthFalloffAccum *= _LayerDepthFalloff;
	        layerHeightBiasAccum += _LayerHeightBiasStep;
	        #endif

                // layer2
	        #ifdef EnableLayer2
	        layerBaseUV = TRANSFORM_TEX(i.uv, _Layer2Tex);
	        layerParallaxUV = layerBaseUV + eyeVec.xy * v + eyeVec.xy * -layerHeightBiasAccum;

	        colorLayerAccum += tex2D(_Layer2Tex, layerParallaxUV).xyz * layerDepthFalloffAccum * _Layer2Tint.xyz;
	        layerDepthFalloffAccum *= _LayerDepthFalloff;
	        layerHeightBiasAccum += _LayerHeightBiasStep;
	        #endif


                float3 color = colorLayerAccum;
                float alpha = 0.0;

                // fresnel
                #ifdef EnableFresnel
                float fresnel = pow(1.0 - phong, _FresnelTightness);
                color += lerp(_FresnelColorInside, _FresnelColorOutside, fresnel) * fresnel;
                alpha += fresnel;
                #endif

                // caustic
                #ifdef EnableCaustic
                color += _CausticTint.xyz * caustic;
                alpha += caustic * _CausticTint.w;
                #endif

                // marble
                fixed4 texMarble = tex2D(_MarbleTex, TRANSFORM_TEX(marbleUV, _MarbleTex));
                color += texMarble.xyz * _MarbleTint.xyz;
                alpha += saturate(dot(color, float3(0.299, 0.587, 0.114)));

	        // specular
	        #ifdef EnableSpecular
	        float3 worldNormalNormalized = normalize(i.worldNormal);
	        float3 r = reflect(-_WorldSpaceLightPos0.xyz, worldNormalNormalized);
	        float specular = pow(saturate(dot(r, normalize(i.worldViewDir))), _SpecularTightness);
	        color += _LightColor0.xyz * specular * _SpecularBrightness;
	        alpha += specular * _SpecularBrightness;
	        #endif

                color = saturate(color);
                alpha = saturate(alpha);


	        // reflection
                #ifdef EnableRefraction
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                half4 bgcolor = tex2D(_GrabTexture,
                    screenUV + (-i.viewNormal.xy * 0.5 + float2(height, 0.0)) * _RefractionStrength);
                color = lerp(bgcolor.xyz, color, alpha);
                alpha = 1.0f;
                #endif

                #if defined(EnableFog)
                UNITY_APPLY_FOG(i.fogCoord, color);
                #endif

                return float4(color, alpha);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
