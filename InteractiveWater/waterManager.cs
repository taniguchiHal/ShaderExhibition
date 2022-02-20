using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class waterManager : MonoBehaviour
{
    [SerializeField] private CustomRenderTexture _customRenderTexture;
    [SerializeField] private int updateFrame;

    // customRenderTextureは指定した座標だけを更新することが出来るのでそれを使用
    // するための変数 _defaultZone
    private CustomRenderTextureUpdateZone _defaultZone;

    private void Start()
    {
        // customRenderTextureの初期化
        _customRenderTexture.Initialize();

        // 更新する範囲を格納するための構造体
        /* CustomRenderTextureUpdateZone()
         * updateZoneCenter CustomRenderTextureの中心位置
         * updateZoneSize   更新範囲のサイズ
         * rotation         更新範囲のローテーション
         * needSwap         ダブルバッファリングしている場合、次の更新前にバッファを交換するかしないか
         * passIndex        CustomRenderingTextureを更新するために使用されるPass
         */
        _defaultZone = new CustomRenderTextureUpdateZone
        {
            updateZoneCenter = new Vector3(0.5f, 0.5f, 0),
            updateZoneSize = new Vector3(1.0f, 1.0f, 0),
            rotation = 0,
            passIndex = 0,
            needSwap = true
        };
    }

    // Update is called once per frame
    private void Update()
    {

        // 範囲指定した場所の更新
        _customRenderTexture.ClearUpdateZones();
        
        UpdateZones();

        // 一度に更新するフレームを指定
        _customRenderTexture.Update(updateFrame);
        //_customRenderTexture
    }

    private void UpdateZones()
    {
        bool click = Input.GetKey(KeyCode.Space);
        if (!click) return;

        var clickZone = new CustomRenderTextureUpdateZone
        {
            updateZoneCenter = new Vector2(0.5f, 0.5f),
            updateZoneSize = new Vector3(0.05f, 0.05f, 0),
            rotation = 0,
            passIndex = 1,
            needSwap = true
        };

        _customRenderTexture.SetUpdateZones(new CustomRenderTextureUpdateZone[] { _defaultZone, clickZone });
    }

}
