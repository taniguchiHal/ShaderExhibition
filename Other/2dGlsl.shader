Shader "2dGlsl"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Size("Texture Size", float) = 1
        _DrawLine("Draw Line", Range(4, 20)) = 6
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

            float4 _Color;
            float _Size;
            float _DrawLine;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }


            
            fixed4 frag(v2f i) : SV_Target
            {
                float4 col = 1;

                float2 st = 2.0f * i.uv * _Size - 1.0;
                float l = 0.01 / abs(sin(_Time.y * 0.8) - length(st));

                // gradiation
                float2 v = float2(0.0, 1.0);
                float t = dot(st, v) / (length(st) * length(v));

                float u = abs(sin((atan2(st.y, st.x) - length(st) + _Time.y * 2.) * _DrawLine) * 1.0) + 0.3;
                float t2 = 0.02 / abs(u - length(st));
                t2 = saturate(t2);

                col = float4(float3(t2 * _Color.r, t2 * _Color.g, t2 * _Color.b), 1.0);
                

                return col;
            }
        ENDCG
        }  
    }
}