using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class VolumetricIntegration : MonoBehaviour
{
    private Shader shader;
    private Material _material;
    public Texture noise;
    public RenderTexture rt;
    void OnEnable()
    {
        shader = Shader.Find("Unlit/VolumetricIntegration");
        if (shader != null)
        {
            _material = new Material(shader);
        }
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (_material)
        {
            _material.SetTexture("_NoiseTex",noise);
            Graphics.Blit(src,rt,_material);
            Graphics.Blit(src,dest);
        }
    }
}
