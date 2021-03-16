using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class RayTracingShadow : MonoBehaviour
{
    private Shader rayTracingShader;
    private Material _material;
    private RenderTexture rt;
    public GameObject mainLight;
    void OnEnable()
    {
        rayTracingShader = Shader.Find("Unlit/RayTracingShadow");
        if (rayTracingShader != null)
        {
            _material = new Material(rayTracingShader);
        }
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (_material)
        {
            rt = RenderTexture.GetTemporary(Screen.width, Screen.height, 1, RenderTextureFormat.Default);
            Graphics.Blit(src,rt,_material);
            _material.SetVector("_LightDir",mainLight.transform.forward);
            Graphics.Blit(rt,dest);
        }
    }
}
