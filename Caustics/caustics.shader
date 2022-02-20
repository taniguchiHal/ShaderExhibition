Shader "Projector/caustics"
{
    Properties
    {
        _CausticsTex("Caustics Texture", 2D) = "black" {}
        _CausticsColor("Caustics Color", COLOR) = (0,0,0,1)

        _CausticsScrollSpeed("Caustics Scroll Speed", Float) = 1
        _CausticsDiffraction("Caustics Diffraction",Range(0,0.5)) = 0.1
        _BlendCaustics("Blend Caustics", Range(0,1)) = 0.1
        _ColorMul("Color Mul", Range(0.1,10)) = 0.1

        [Header(Noise)]
        [Toggle(EnableNoise)]_EnableNoise("Enable Noise", Float) = 0
        _NoiseTilling("Noise Tilling", Range(0.001,0.1)) = 0.01
        _NoiseScrollSpeed("Nosie Scroll Speed", Float) = 1
    }

    Subshader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent+100" }
        Pass {
            ZWrite Off
            Offset -1, -1
            Blend DstColor One
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 tangent : TANGENT;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float2 uv : TEXCOORD1;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;

                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            sampler2D _CausticsTex;
            float4 _CausticsTex_ST;

            float4 _CausticsColor;
            float4x4 unity_Projector;
            float _CausticsScrollSpeed;
            float _CausticsDiffraction;
            float _BlendCaustics;
            float _ColorMul;

            float _EnableDistortion;
            float _NoiseTilling;
            float _NoiseScrollSpeed;
            float _EnableNoise;

            // vertex
            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(mul(unity_Projector, v.vertex).xy, _CausticsTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.worldNormal = normalize(mul(float4(v.normal, 0.0), unity_ObjectToWorld).xyz);
                return o;
            }

            // 各blendNormal値とworldUvを使用
            // <https://qiita.com/edo_m18/items/c8995fe91778895c875e>
            fixed4 triplanarUV(float3 blendNormal, float3 wpos)
            {
                float2 finaluv = wpos.xy;
                float2 x = wpos.yz;
                float2 y = wpos.xz;
                // 法線がどの平面により向いてるかを元にUVに合成
                finaluv = lerp(finaluv, x, blendNormal.x);
                finaluv = lerp(finaluv, y, blendNormal.y);
                finaluv *= 0.005; 
                return half4(finaluv.x, finaluv.y, 0, 0);
            }

            // valueNoise
            float2 random2(float2 st) {
                st = float2(dot(st, float2(127.1, 311.7)),
                    dot(st, float2(269.5, 183.3)));
                return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
            }

            // Gradient Noise by Inigo Quilez - iq/2013
            // <https://www.shadertoy.com/view/XdXGW8>
            float valueNoise(float2 st) {
                float2 i = floor(st);
                float2 f = frac(st);

                float2 u = f * f * (3.0 - 2.0 * f);

                return lerp(lerp(dot(random2(i + float2(0.0, 0.0)), f - float2(0.0, 0.0)),
                    dot(random2(i + float2(1.0, 0.0)), f - float2(1.0, 0.0)), u.x),
                    lerp(dot(random2(i + float2(0.0, 1.0)), f - float2(0.0, 1.0)),
                        dot(random2(i + float2(1.0, 1.0)), f - float2(1.0, 1.0)), u.x), u.y);
            }


            // perinNoise
            float perlinNoise(fixed2 st)
            {
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

            // fBmNoise
            float fBm(fixed2 st)
            {
                float f = 0;
                fixed2 q = st;

                f += 0.5000 * perlinNoise(q); q = q * 2.01;
                f += 0.2500 * perlinNoise(q); q = q * 2.02;
                f += 0.1250 * perlinNoise(q); q = q * 2.03;
                f += 0.0625 * perlinNoise(q); q = q * 2.01;

                return f;
            }


            // fragment
            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 col = fixed3(0,0,0);
                float alpha = 1;

                float2 noise = float2(mul(_NoiseScrollSpeed, _Time.y), mul(_NoiseScrollSpeed, _Time.y));
                noise = (i.uv * _NoiseTilling) + noise;

                // noiseUV作成
                float2 noiseUV = valueNoise(noise) * fBm(noise);

                // textureの値調整に使用するので, 法線を0~1の値にした後に, 0ベクトル回避
                // 飛ばした先の法線方向をabsでマイナスの値を回避する
                float3 blending = abs(i.worldNormal);
                // 0ベクトルにならないように0.00001を最低値とする
                float3 blendNormal = normalize(max(blending , 0.00001));
                // 合計値を1に調整
                float b = (blendNormal.x + blendNormal.y + blendNormal.z);
                blendNormal /= float3(b, b, b);

                float2 uvTotal = triplanarUV(blendNormal, i.worldPos) * _CausticsTex_ST;


                float scroll = frac(_CausticsScrollSpeed / 100 * _Time.y);
                
                // NoiseUVとScrollの切替
                scroll = lerp(scroll, noiseUV, _EnableNoise);

                fixed c1r = tex2D(_CausticsTex, uvTotal + scroll + frac(fixed2(_CausticsDiffraction, _CausticsDiffraction)));
                fixed c1g = tex2D(_CausticsTex, uvTotal + scroll + frac(fixed2(_CausticsDiffraction, -_CausticsDiffraction)));
                fixed c1b = tex2D(_CausticsTex, uvTotal + scroll + frac(fixed2(-_CausticsDiffraction, -_CausticsDiffraction)));
                fixed4 c1 = fixed4(c1r, c1g, c1b, 1);

                fixed c2r = tex2D(_CausticsTex, uvTotal - scroll - frac(fixed2(_CausticsDiffraction, _CausticsDiffraction)));
                fixed c2g = tex2D(_CausticsTex, uvTotal - scroll - frac(fixed2(_CausticsDiffraction, -_CausticsDiffraction)));
                fixed c2b = tex2D(_CausticsTex, uvTotal - scroll - frac(fixed2(-_CausticsDiffraction, -_CausticsDiffraction)));
                fixed4 c2 = fixed4(c2r, c2g, c2b, 1);

                // causticsの追加
                c1 = lerp(c1, c2, _BlendCaustics * 0.5);
                col = saturate(c1.rgb * _CausticsColor * _ColorMul);

                return float4(col, alpha);
            }
            ENDCG
        }
    }
}
