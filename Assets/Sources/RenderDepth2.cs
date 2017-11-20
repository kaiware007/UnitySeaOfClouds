using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class RenderDepth2 : MonoBehaviour {

    public Vector3 threshold;
    [SerializeField, Range(0, 1)] float _intensity = 0.5f;
    [SerializeField, HideInInspector] Shader _shader;

    Material mat;

    private Camera camera;
    
    private void OnEnable()
    {
        camera = GetComponent<Camera>();
        camera.depthTextureMode = DepthTextureMode.Depth;
    }
    
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (mat == null)
        {
            mat = new Material(_shader);
            mat.hideFlags = HideFlags.DontSave;
        }

        Matrix4x4 view = this.camera.cameraToWorldMatrix;

        mat.SetFloat("_XThreshold", threshold.x);
        mat.SetFloat("_YThreshold", threshold.y);
        mat.SetFloat("_ZThreshold", threshold.z);

        mat.SetMatrix("_InverseView", view);
        mat.SetFloat("_Intensity", _intensity);

        Graphics.Blit(source, destination, mat);
    }

    private void OnDrawGizmos()
    {
        const float boarder_size = 100;

        Gizmos.color = Color.red;
        Gizmos.DrawWireCube(new Vector3(threshold.x, 0, 0), new Vector3(0, boarder_size, boarder_size));

        Gizmos.color = Color.green;
        Gizmos.DrawWireCube(new Vector3(0, threshold.y, 0), new Vector3(boarder_size, 0, boarder_size));

        Gizmos.color = Color.blue;
        Gizmos.DrawWireCube(new Vector3(0, 0, threshold.z), new Vector3(boarder_size, boarder_size, 0));

    }
}
