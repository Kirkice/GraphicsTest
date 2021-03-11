using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;


[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class SDFShadow : MonoBehaviour
{
    private Shader SDFShadowShader;
    private Material _material;
    public Transform lightDir;

    private Matrix4x4 GetCameraConer(Camera camera)
    {
        Vector3[] frustumCorners = new Vector3[4];
        camera.CalculateFrustumCorners(new Rect(0,0,1,1),camera.farClipPlane,camera.stereoActiveEye,frustumCorners);
        Vector3 bottomLeft = camera.transform.TransformVector(frustumCorners[0]);
        Vector3 topLeft = camera.transform.TransformVector(frustumCorners[1]);
        Vector3 topRight = camera.transform.TransformVector(frustumCorners[2]);
        Vector3 bottomRight = camera.transform.TransformVector(frustumCorners[3]);
        
        Matrix4x4 frustumCornersArray = Matrix4x4.identity;
        frustumCornersArray.SetRow(0,bottomLeft);
        frustumCornersArray.SetRow(1,bottomRight);
        frustumCornersArray.SetRow(2,topLeft);
        frustumCornersArray.SetRow(3,topRight);
        return frustumCornersArray;
    }

    private void OnEnable()
    {
        SDFShadowShader = Shader.Find("Unlit/SDFShadow");
        _material = new Material(SDFShadowShader);
        _material.hideFlags = HideFlags.HideAndDontSave;
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (_material != null)
        {
            _material.SetMatrix("_Corners",GetCameraConer(Camera.main));
            _material.SetVector("_CameraPos",Camera.main.transform.position);
            _material.SetVector("_LightDirection",this.lightDir.forward);
            Graphics.Blit(src,dest,_material,0);
        }
        else
        {
            Graphics.Blit(src,dest);
        }
    }
}
