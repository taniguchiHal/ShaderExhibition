Shader "Rainer"
{
    Properties
    {
        _MainTex("Texture",2D) = "black"{}
        _Size("Texture Size", float) = 1
        _Intensity("Rain Intensity",Range(0, 13)) = 8
        _RainerSpeed("Rainer Speed", Range(0.01, 1)) = 0.05
    }

    SubShader
    {
        Tags { "RenderType"="Opaque"}
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
                float2 uv : TEXCOORD0;
                float4 grabUv : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Size;
            int _Intensity;

            float _RainerSpeed;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.grabUv = UNITY_PROJ_COORD(ComputeGrabScreenPos(o.vertex));
                return o;
            }

            // 下記のshaderを参考にunityに移植
            // https://www.shadertoy.com/view/ldfyzl
            float hash12(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 19.19);
                return frac((p3.x + p3.y) * p3.z);
            }

            float hash22(float2 p) 
            {
                float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
                p3 += dot(p3, p3.yzx + 19.19);
                return frac((p3.xx + p3.yz) * p3.zy);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float4 col = 0;

                float2 aspect = float2(1, 1);
                float2 uv = i.uv * _Size * aspect;
                float2 gv = frac(uv) - 0.5;
                float2 p0 = floor(uv);

                float2 circles = float(0.);

                for (int i = -3; i < 3; ++i) {
                    for (int j = -3; j < 3; ++j) {
                        float2 pi = p0 + float2(j,i);

                        #if DOUBLE_HASH
                        float2 hsh = hash22(pi);
                        #else
                        float2 hsh = pi;
                        #endif
                        float2 p = pi + hash22(hsh);

                        float2 t = frac(_RainerSpeed * _Time.y + hash12(hsh));
                        float2 v = p - uv;

                        float d = length(v) - t * (float(2) + 1.);

                        float h = 1e-3;
                        float d1 = d - h;
                        float d2 = d + h;
                        float p1 = sin(d1 * 31.) * smoothstep(-0.6,-0.3,d1) * smoothstep(0., -0.3, d1);
                        float p2 = sin(d2 * 31.) * smoothstep(-0.6,-0.3,d2) * smoothstep(0., -0.3, d2);

                        circles += ((p2-p1) / (2. * h) * (1.-t) * (1.-t));
                    }
                }

                circles /=  float((_Intensity * 2 + 1) * (_Intensity * 2 + 1));


                float3 n = float3(circles, sqrt(1. - dot(circles, circles)));
                
                float intensity = lerp(0.01, 0.15,
                    smoothstep(0.1, 0.6,
                        abs(frac(0.05 * _Time.y + 0.5) * 2.0 - 1.0)));

                float3 tex = tex2D(_MainTex, (uv / _Size) - n.xy * intensity).rgb 
                    + 5. * pow(clamp(dot(n, normalize(float3(1., 0.7, 0.5))), 0., 1.), 6.);

                col = float4(tex,1);
                return col ;
            }
            ENDCG
        }
    }
}
