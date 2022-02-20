Shader "simulation"
{
    Properties
    {
        _S2("PhaseVelocity^2", Range(0.0, 0.5)) = 0.2
        _Atten("Attenuation", Range(0.0, 1.0)) = 0.999
        _DeltaUV("Delta UV", Float) = 3
    }

    CGINCLUDE
    #include "UnityCustomRenderTexture.cginc"

    half _S2;
    half _Atten;
    float _DeltaUV;

    // UnityCustomRenderTexture.cgincにv2f_customrendertextureがある
    float4 frag(v2f_customrendertexture i) : SV_Target
    {
        // 1px辺りの単位計算->glslで最初にやった奴
        float2 uv = i.globalTexcoord;
        float width = 1.0 / _CustomRenderTextureWidth;
        float height = 1.0 / _CustomRenderTextureHeight;
        float3 duv = float3(width, height, 0) * _DeltaUV;

        // 歪み(頂点を動かす)用のtextureを設定
        // これにshaderお絵描きをしていく
        float2 texColor = tex2D(_SelfTexture2D, uv);

        // 以下波動方程式
        // ラプラシアンフィルタ(輪郭の表現)->波の表現
        // rに現在の波の状態, gに1f前の波の状態を格納


        // R-> 一つ前 G-> 二つ前
        // 移動する加速度
        float k = 2.0 * texColor.r - texColor.g;

        // ラプシアンフィルタ 
        float laplacian =
            tex2D(_SelfTexture2D, uv - duv.zy).r +
            tex2D(_SelfTexture2D, uv + duv.zy).r +
            tex2D(_SelfTexture2D, uv - duv.xz).r +
            tex2D(_SelfTexture2D, uv + duv.xz).r - 4 * texColor.r;

        // 加速度
        // 現在の波の高さに
        float accel = (k + 0.5f * laplacian) * _Atten;

        return float4(accel, texColor.r, 0, 0);
    }

    float4 frag_left_click(v2f_customrendertexture i) : SV_Target
    {
        return float4(-1, 0, 0, 0);
    }

    float4 frag_right_click(v2f_customrendertexture i) : SV_Target
    {
        return float4(1, 0, 0, 0);
    }
    ENDCG


    SubShader
    {
        Cull Off ZWrite Off ZTest Always

		// 基本更新
        Pass
        {
            Name "Update"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            ENDCG
        }

        Pass
        {
            Name "DownObject"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag_left_click
            ENDCG
        }

        Pass
        {
            Name "UpObject"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag_right_click
            ENDCG
        }
    }
}
