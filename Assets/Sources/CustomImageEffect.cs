using System.Collections;
using System.Collections.Generic;
using UnityEngine;

//[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public abstract class CustomImageEffect : MonoBehaviour {

    #region Fields

    private Material m_Material;

    #endregion

    #region Properties

    public abstract string ShaderName { get; }

    protected Material Material { get { return m_Material; } }

    #endregion

    #region Messages

    protected virtual void Awake()
    {
        Shader shader = Shader.Find(ShaderName);
        m_Material = new Material(shader);
    }

    protected virtual void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        UpdateMaterial();

        Graphics.Blit(source, destination, m_Material);
    }

    #endregion

    #region Methods

    protected abstract void UpdateMaterial();

    #endregion
}
