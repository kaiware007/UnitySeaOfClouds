using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DepthWriter : CustomImageEffect {

    public RenderTexture depthTexture;

    private Camera cam;
    
    protected override void Awake()
    {
        base.Awake();

        // Depth書き込み用RenderTexture作成(DirectX9の場合、DepthはR32floatらしい)
        depthTexture = new RenderTexture(Screen.width, Screen.height, 32, RenderTextureFormat.Depth);
        depthTexture.wrapMode = TextureWrapMode.Clamp;
        depthTexture.filterMode = FilterMode.Bilinear;
        depthTexture.antiAliasing = 1;
        depthTexture.dimension = UnityEngine.Rendering.TextureDimension.Tex2D;
        depthTexture.depth = 24;
        depthTexture.useMipMap = false;
        depthTexture.autoGenerateMips = false;
        depthTexture.anisoLevel = 0;
        depthTexture.hideFlags = HideFlags.HideAndDontSave;
        depthTexture.Create();

        if (cam == null)
        {
            cam = GetComponent<Camera>();
            cam.depthTextureMode = DepthTextureMode.Depth;
        }

       cam.targetTexture = depthTexture;
       
    }

    public override string ShaderName
    {
        get { return "Custom/CustomDepth"; }
    }

    protected override void UpdateMaterial()
    {
        Shader.SetGlobalTexture("_CustomCameraDepthTexture", depthTexture );
    }

}
