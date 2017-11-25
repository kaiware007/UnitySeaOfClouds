using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DepthTest : CustomImageEffect {

    public RenderTexture depthTexture;
    //public RenderTexture _color = null;
    //public RenderTexture _zBuffer = null;
    //public RenderTexture _cameraZ = null;

    private Camera cam;
    
    protected override void Awake()
    {
        base.Awake();

        //if (depthTexture == null)
        {
            //depthTexture = new RenderTexture(Screen.width, Screen.height, 32, RenderTextureFormat.ARGB32);
            depthTexture = new RenderTexture(Screen.width, Screen.height, 32, RenderTextureFormat.Depth);
            //depthTexture = new RenderTexture(2048, 2048, 32);
            depthTexture.wrapMode = TextureWrapMode.Clamp;
            depthTexture.filterMode = FilterMode.Bilinear;
            depthTexture.antiAliasing = 1;
            depthTexture.dimension = UnityEngine.Rendering.TextureDimension.Tex2D;
            depthTexture.depth = 24;
            depthTexture.useMipMap = false;
            depthTexture.autoGenerateMips = false;
            depthTexture.anisoLevel = 0;
            //depthTexture = new RenderTexture(Screen.width, Screen.height, 24, RenderTextureFormat.Depth);
            depthTexture.hideFlags = HideFlags.HideAndDontSave;
            depthTexture.Create();
        }

        //_color = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGB32);
        //_zBuffer = new RenderTexture(Screen.width, Screen.height, 32, RenderTextureFormat.Depth);

        //_cameraZ = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.RFloat);
        //_cameraZ.enableRandomWrite = true;
        //_cameraZ.Create();

        if (cam == null)
        {
            cam = GetComponent<Camera>();
            cam.depthTextureMode = DepthTextureMode.Depth;
        }

        //cam.SetTargetBuffers(_color.colorBuffer, _zBuffer.depthBuffer);

       cam.targetTexture = depthTexture;
       
    }

    //void OnDisable()
    //{
    //    //GameObject.DestroyImmediate(depthTexture);
    //    depthTexture = null;
    //}

    public override string ShaderName
    {
        get { return "Custom/CustomDepth"; }
    }

    protected override void UpdateMaterial()
    {
        //Material.SetFloat("_Size", m_Size);

        Shader.SetGlobalTexture("_CustomCameraDepthTexture", depthTexture );
    }

}
