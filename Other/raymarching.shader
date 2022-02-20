Shader "raymarching"
{
    Properties
    {
        _Diffuse("Diffuse", Color) = (1,1,1,1)
        _Ambient("Ambient", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "black" {}
        _Size("Texture Size", float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass
        {
            Tags{"LightMode" = "ForwardBase"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Diffuse;
            float4 _Ambient;
            float _Size;


            // vertexShader
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float sdCross(float3 p, float c) {
                p = abs(p);
                float dxy = max(p.x, p.y);
                float dyz = max(p.y, p.z);
                float dxz = max(p.x, p.z);
                return min(dxy, min(dyz, dxz)) - c;
            }

            float3 mod(float3 x, float3 y) 
            {
                return x - y * floor(x / y);
            }

            float sdBox(float3 p, float3 b) {
                p = abs(p) - b;
                return length(max(p, 0.0)) + min(max(p.x, max(p.y, p.z)), 0.0);
            }

            // mengerSponge
            #define ITERATIONS 4
            float deMengerSponge(float3 p, float scale, float width) {
                float d = sdBox(p, float3(1.0, 1.0, 1.0));
                float s = 1.0;

                for (int i = 0; i < ITERATIONS; i++) {
                    float3 a = mod(p * s, 2.) - 1.0;
                    s *= scale;
                    float3 r = 1.0 - scale * abs(a);
                    float c = sdCross(r, width) / s;
                    d = max(d, c);
                }
                return d;
            }

            float DE(float3 p) {
                return deMengerSponge(p, 3.0, 1.0);
            }

            float3x3 camera(float3 ro, float3 ta, float3 up)
            {
                float3 cw = normalize(ta - ro);
                float3 cu = normalize(cross(cw, up));
                float3 cv = normalize(cross(cu, cw));
                return float3x3(cu, cv, cw);
            }

            float ambientOcclusion(float3 pos, float3 nor) {
                float ao = 0.0;
                float amp = 0.7;
                float step = 0.01;
                for (int i = 1; i < 3; i++) {
                    float3 p = pos + step * float(i) * nor;
                    float d = DE(p);
                    ao += amp * ((step * float(i) - d) / (step * float(i)));
                    amp *= 0.5;
                }
                return 1.0 - ao;
            }

            float3 shadeSurface(float3 pos, float3 nor) {
                float dotNL = max(0.3, dot(nor, normalize(float3(0.5, 0.8, 1.0))));
                float3 dif = _Diffuse.rgb * dotNL;
                float ao = ambientOcclusion(pos, nor);
                float3 amb = _Ambient.rgb * float3(ao, ao, ao);
                return dif + amb;
            }

            // raymarching
            bool raymarch(float3 ro, float3 rd, out float t) {
                float3 p = ro;
                t = 0.0;
                for (int i = 0; i < 99; i++) {
                    float d = DE(p);
                    p += d * rd;
                    t += d;

                    if (d < 0.0002) {
                        return true;
                    }
                }
                return false;
            }

            float3 calcNormal(float3 p) {
                float d = 0.001;
                return normalize(float3(
                    DE(p + float3(d, 0.0, 0.0)) - DE(p - float3(d, 0.0, 0.0)),
                    DE(p + float3(0.0, d, 0.0)) - DE(p - float3(0.0, d, 0.0)),
                    DE(p + float3(0.0, 0.0, d)) - DE(p - float3(0.0, 0.0, d))
                ));
            }

            float3 background(float2 st) {
                return lerp(float3(0.5, 0.5, 0.5), float3(0.1, 0.1, 0.1), length(st) * 0.4);
            }


            // fragmentShader
            fixed4 frag(v2f i) : SV_Target
            {
                float4 col = 1;

                float2 st = 2.0f * i.uv * _Size - 1.0;
                float3 ro = float3(0.0, smoothstep(-1.0, 1.0, sin(_Time.y * 0.5)) * 2.0 - 1.0, 0.0);
                float3 ro2 = float3(1.3, 1.3, 1.3);
                
                float3 ta = float3(0.35, 0.35, 0.35);
                float3 z = normalize(ta - ro);
                float3 up = float3(1.0, 0.5, 0.0);
                float3 x = normalize(cross(z, up));
                float3 y = normalize(cross(x, z));
                float3 rd = normalize(x * st.x + y * st.y + z * 1.5);

                float3 c;
                float t;
                if (raymarch(ro, rd, t)) {
                    float3 pos = ro + t * rd;
                    float3 nor = calcNormal(pos);
                    c = shadeSurface(pos, nor);
                }
                else {
                    c = background(2.0 * st);
                }

                col = float4(pow(c, float3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2)), 1.0);
                
                return col;
            }        
        ENDCG
        }
    }
}
