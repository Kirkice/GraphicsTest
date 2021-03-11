using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class PlanerShadow : MonoBehaviour
{
    /// <summary>
    /// 平面阴影部分参数
    /// </summary>
    #region SHADOW PLANEAR
    public Vector4 ShadowPlaneVector = new Vector4(0.0f, 4f, 0.0f, 0.0f);
    [Range(-10, 10)]
    public float shadowOffset = 0.0f;
    private Material _material;
    #endregion
    
    void Start()
    {
        _material = this.GetComponent<Renderer>().sharedMaterial;
        SetPlanerShadowParames();
    }
    
    void Update()
    {
        SetPlanerShadowParames();
    }

    private void SetPlanerShadowParames()
    {
        _material.SetVector("_WorldPos", this.transform.position);
        _material.SetVector("_ShadowPlane", ShadowPlaneVector);
        _material.SetVector("_ShadowFadeParams", new Vector4(0.0f, 1.5f, 0.7f, 0.0f));
        _material.SetFloat("_ShadowInvLen", 0.5f);
        _material.SetFloat("_ShadowFalloff", 1.35f);
        _material.SetFloat("_ShadowOffset", shadowOffset);
    }
}
