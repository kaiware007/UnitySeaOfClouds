using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PositionTexture : MonoBehaviour {

    struct PositionData
    {
        public Vector2 position;    // 座標
        public float radius;        // 円の半径
    }

#region public
    // テクスチャの解像度
    public int texWidth = 2048;
    public int texHeight = 2048;

    // ワールド空間内のテクスチャの大きさ
    public float worldScale = 100f;

    public RenderTexture positionTexture;
    public RenderTexture positionTextureOld;

    public int maxPositonDataNum = 16;

    // 前のフレームのテクスチャを残す率
    public float fadeoutPower = 0.998f;
    public Material material;

    public bool isDebug = false;

    static public PositionTexture Instance
    {
        get {
            if(_instance == null)
            {
                _instance = GameObject.FindObjectOfType<PositionTexture>();
            }

            return _instance;
        }
    }
#endregion

   
#region private
    ComputeBuffer positionDataBuffer;
    PositionData[] positionDataArray;
    int positionDataIndex = 0;

    static PositionTexture _instance = null;
#endregion

    // 座標データ追加
    public void AddPosition(Vector2 pos, float radius)
    {
        if (positionDataIndex >= maxPositonDataNum)
            return;

        Vector3 myPos = transform.position;
        pos.x = pos.x - myPos.x;
        pos.y = pos.y - myPos.z;

        float scale = worldScale * 1.0f;
        positionDataArray[positionDataIndex].position.x = pos.x / scale * 0.5f + 0.5f;
        positionDataArray[positionDataIndex].position.y = pos.y / scale * 0.5f + 0.5f;
        positionDataArray[positionDataIndex].radius = radius / worldScale;
        positionDataIndex++;
    }

    void Initialize()
    {
        positionDataArray = new PositionData[maxPositonDataNum];
        positionDataBuffer = new ComputeBuffer(maxPositonDataNum, System.Runtime.InteropServices.Marshal.SizeOf(typeof(PositionData)));

        positionTexture = CreateRenderTexture();
        positionTextureOld = CreateRenderTexture();

    }

    RenderTexture CreateRenderTexture()
    {
        RenderTexture tex = new RenderTexture(texWidth, texHeight, 0, RenderTextureFormat.RFloat);
        tex.anisoLevel = 0;
        tex.antiAliasing = 1;
        tex.autoGenerateMips = false;
        tex.filterMode = FilterMode.Bilinear;
        tex.useMipMap = false;
        tex.wrapMode = TextureWrapMode.Clamp;
        tex.hideFlags = HideFlags.HideAndDontSave;
        tex.Create();

        return tex;
    }

    void UpdateTexture()
    {
        
        positionDataBuffer.SetData(positionDataArray);

        material.SetBuffer("_PositionBuffer", positionDataBuffer);
        material.SetInt("_PositionIndex", positionDataIndex);
        material.SetFloat("_FadeoutPower", fadeoutPower);

        // フェード処理用に前フレームのテクスチャをコピー
        Graphics.Blit(positionTexture, positionTextureOld);

        // 円描画
        Graphics.Blit(positionTextureOld, positionTexture, material);

        // GlobalTextureでセット
        Shader.SetGlobalTexture("_PositionTexture", positionTexture);
        Shader.SetGlobalFloat("_PositionTextureScale", worldScale);
        Shader.SetGlobalVector("_PositionTextureOffset", transform.position);

        positionDataIndex = 0;
    }

	// Use this for initialization
	void Start () {
        Initialize();
	}
	
	// Update is called once per frame
	void Update () {
        UpdateTexture();
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.yellow;
        float scale = worldScale * 2f;
        Gizmos.DrawWireCube(transform.position, new Vector3(scale, 0, scale));
    }

    private void OnGUI()
    {
        if(isDebug)
        {
            float width = Screen.width > Screen.height ? Screen.height : Screen.width;
            width *= 0.5f;

            GUI.DrawTexture(new Rect(0, 0, width, width), positionTexture);
        }
    }
}
