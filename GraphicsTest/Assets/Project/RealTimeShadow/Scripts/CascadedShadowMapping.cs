using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CascadedShadowMapping : MonoBehaviour
{
    //主相机 灯光相机
    public Light MainLight;
    private Camera lightCamera;
    //接受阴影Shader
    public Shader _shaderCaster;
    //偏移矩阵
    private Matrix4x4 biasMatrix4X4 = Matrix4x4.identity;

    //世界转阴影空间矩阵
    private List<Matrix4x4> TransformWorldToShadow = new List<Matrix4x4>(4);
    private GameObject[] mainLightCameraSplits = new GameObject[4];
    private RenderTexture[] depthTextures = new RenderTexture[4];

    private float[] _LightSplitsNear;
    private float[] _LightSplitsFar;
    
    //裁剪角
    struct FrustumCorners
    {
        public Vector3[] nearCorners;
        public Vector3[] farCorners;
    }
    
    //主相机 灯光相机
    FrustumCorners[] mainCamera_Splits_fcs;
    FrustumCorners[] lightCamera_Splits_fcs;
    
    private void Awake()
    {
        biasMatrix4X4.SetRow(0,new Vector4(0.5f, 0, 0, 0.5f));
        biasMatrix4X4.SetRow(1,new Vector4(0,0.5f,0,0.5f));
        biasMatrix4X4.SetRow(2,new Vector4(0,0,0.5f,0.5f));
        biasMatrix4X4.SetRow(3,new Vector4(0,0,0,0.5f));
        InitFrustumCorners();
    }

    private void InitFrustumCorners()
    {
        mainCamera_Splits_fcs = new FrustumCorners[4];
        lightCamera_Splits_fcs = new FrustumCorners[4];

        for (int i = 0; i < 4; i++)
        {
            mainCamera_Splits_fcs[i].nearCorners = new Vector3[4];
            mainCamera_Splits_fcs[i].farCorners = new Vector3[4];
            
            lightCamera_Splits_fcs[i].nearCorners = new Vector3[4];
            lightCamera_Splits_fcs[i].farCorners = new Vector3[4];
        }
    }

    /// <summary>
    /// 计算主相机的裁切角
    /// </summary>
    private void CalcMainCameraSplitsFrustumCorners()
    {
        float near = Camera.main.nearClipPlane;
        float far = Camera.main.farClipPlane;

        float[] nears = { near,                     far * 0.067f + near,                        far * 0.133f + far * 0.067f + near,                         far * 0.267f + far * 0.133f + far * 0.067f + near };
        float[] fars = { far * 0.067f + near,       far * 0.133f + far * 0.067f + near,         far * 0.267f + far * 0.133f + far * 0.067f + near,          far };

        _LightSplitsNear = nears;
        _LightSplitsFar = fars;

        Shader.SetGlobalVector("_gLightSplitsNear", new Vector4(_LightSplitsNear[0], _LightSplitsNear[1], _LightSplitsNear[2], _LightSplitsNear[3]));
        Shader.SetGlobalVector("_gLightSplitsFar", new Vector4(_LightSplitsFar[0], _LightSplitsFar[1], _LightSplitsFar[2], _LightSplitsFar[3]));

        for (int k = 0; k < 4; k++)
        {
            Camera.main.CalculateFrustumCorners(new Rect(0, 0, 1, 1), _LightSplitsNear[k], Camera.MonoOrStereoscopicEye.Mono, mainCamera_Splits_fcs[k].nearCorners);
            for (int i = 0; i < 4; i++)
            {
                mainCamera_Splits_fcs[k].nearCorners[i] = Camera.main.transform.TransformPoint(mainCamera_Splits_fcs[k].nearCorners[i]);
            }

            Camera.main.CalculateFrustumCorners(new Rect(0, 0, 1, 1), _LightSplitsFar[k], Camera.MonoOrStereoscopicEye.Mono, mainCamera_Splits_fcs[k].farCorners);
            for (int i = 0; i < 4; i++)
            {
                mainCamera_Splits_fcs[k].farCorners[i] = Camera.main.transform.TransformPoint(mainCamera_Splits_fcs[k].farCorners[i]);
            }
        }
    }

    /// <summary>
    /// 计算灯光相机的裁切角
    /// </summary>
    private void CalcLightCameraSplitsFrustum()
    {
        if(lightCamera == null)
            return;

        for (int k = 0; k < 4; k++)
        {
            for (int i = 0; i < 4; i++)
            {
                lightCamera_Splits_fcs[k].nearCorners[i] = mainLightCameraSplits[k].transform.InverseTransformPoint(mainCamera_Splits_fcs[k].nearCorners[i]);
                lightCamera_Splits_fcs[k].farCorners[i] = mainLightCameraSplits[k].transform.InverseTransformPoint(mainCamera_Splits_fcs[k].farCorners[i]);
            }
            
            float[] xs = { lightCamera_Splits_fcs[k].nearCorners[0].x, lightCamera_Splits_fcs[k].nearCorners[1].x, lightCamera_Splits_fcs[k].nearCorners[2].x, lightCamera_Splits_fcs[k].nearCorners[3].x,
                lightCamera_Splits_fcs[k].farCorners[0].x, lightCamera_Splits_fcs[k].farCorners[1].x, lightCamera_Splits_fcs[k].farCorners[2].x, lightCamera_Splits_fcs[k].farCorners[3].x };
            
            float[] ys = { lightCamera_Splits_fcs[k].nearCorners[0].y, lightCamera_Splits_fcs[k].nearCorners[1].y, lightCamera_Splits_fcs[k].nearCorners[2].y, lightCamera_Splits_fcs[k].nearCorners[3].y,
                lightCamera_Splits_fcs[k].farCorners[0].y, lightCamera_Splits_fcs[k].farCorners[1].y, lightCamera_Splits_fcs[k].farCorners[2].y, lightCamera_Splits_fcs[k].farCorners[3].y };

            float[] zs = { lightCamera_Splits_fcs[k].nearCorners[0].z, lightCamera_Splits_fcs[k].nearCorners[1].z, lightCamera_Splits_fcs[k].nearCorners[2].z, lightCamera_Splits_fcs[k].nearCorners[3].z,
                lightCamera_Splits_fcs[k].farCorners[0].z, lightCamera_Splits_fcs[k].farCorners[1].z, lightCamera_Splits_fcs[k].farCorners[2].z, lightCamera_Splits_fcs[k].farCorners[3].z };
            
            float minX = Mathf.Min(xs);
            float maxX = Mathf.Max(xs);

            float minY = Mathf.Min(ys);
            float maxY = Mathf.Max(ys);

            float minZ = Mathf.Min(zs);
            float maxZ = Mathf.Max(zs);
            
            lightCamera_Splits_fcs[k].nearCorners[0] = new Vector3(minX, minY, minZ);
            lightCamera_Splits_fcs[k].nearCorners[1] = new Vector3(maxX, minY, minZ);
            lightCamera_Splits_fcs[k].nearCorners[2] = new Vector3(maxX, maxY, minZ);
            lightCamera_Splits_fcs[k].nearCorners[3] = new Vector3(minX, maxY, minZ);

            lightCamera_Splits_fcs[k].farCorners[0] = new Vector3(minX, minY, maxZ);
            lightCamera_Splits_fcs[k].farCorners[1] = new Vector3(maxX, minY, maxZ);
            lightCamera_Splits_fcs[k].farCorners[2] = new Vector3(maxX, maxY, maxZ);
            lightCamera_Splits_fcs[k].farCorners[3] = new Vector3(minX, maxY, maxZ);

            Vector3 pos = lightCamera_Splits_fcs[k].nearCorners[0] + (lightCamera_Splits_fcs[k].nearCorners[2] - lightCamera_Splits_fcs[k].nearCorners[0]) * 0.5f;


            mainLightCameraSplits[k].transform.position = mainLightCameraSplits[k].transform.TransformPoint(pos);
            mainLightCameraSplits[k].transform.rotation = MainLight.transform.rotation;
        }
    }
    
    void ConstructLightCameraSplits(int k)
    {
        lightCamera.transform.position = mainLightCameraSplits[k].transform.position;
        lightCamera.transform.rotation = mainLightCameraSplits[k].transform.rotation;

        lightCamera.nearClipPlane = lightCamera_Splits_fcs[k].nearCorners[0].z;
        lightCamera.farClipPlane = lightCamera_Splits_fcs[k].farCorners[0].z;

        lightCamera.aspect = Vector3.Magnitude(lightCamera_Splits_fcs[k].nearCorners[0] - lightCamera_Splits_fcs[k].nearCorners[1]) / Vector3.Magnitude(lightCamera_Splits_fcs[k].nearCorners[1] - lightCamera_Splits_fcs[k].nearCorners[2]);
        lightCamera.orthographicSize = Vector3.Magnitude(lightCamera_Splits_fcs[k].nearCorners[1] - lightCamera_Splits_fcs[k].nearCorners[2]) * 0.5f;
    }
    
    /// <summary>
    /// 创建RT
    /// </summary>
    private void CreateRenderTexture()
    {
        RenderTextureFormat rtFormat = RenderTextureFormat.Default;
        if (!SystemInfo.SupportsRenderTextureFormat(rtFormat))
            rtFormat = RenderTextureFormat.Default;

        for (int i = 0; i < 4; i++)
        {
            depthTextures[i] = new RenderTexture(1024, 1024, 24, rtFormat);
            Shader.SetGlobalTexture("_gShadowMapTexture" + i, depthTextures[i]);
        }
    }

    /// <summary>
    /// 创建灯光相机
    /// </summary>
    /// <returns></returns>
    public Camera CreateDirLightCamera()
    {
        GameObject goLightCamera = new GameObject("Directional Light Camera");
        Camera LightCamera = goLightCamera.AddComponent<Camera>();

        LightCamera.cullingMask = 1 << LayerMask.NameToLayer("Caster");
        LightCamera.backgroundColor = Color.white;
        LightCamera.clearFlags = CameraClearFlags.SolidColor;
        LightCamera.orthographic = true;
        LightCamera.enabled = false;

        for (int i = 0; i < 4; i++)
        {
            mainLightCameraSplits[i] = new GameObject("dirLightCameraSplits" + i);
        }

        return LightCamera;
    }
    
    private void Update()
    {
        CalcMainCameraSplitsFrustumCorners();
        CalcLightCameraSplitsFrustum();
        
        Shader.SetGlobalFloat("_gShadowBias", 0.005f);
        Shader.SetGlobalFloat("_gShadowStrength", 0.5f);

        if (MainLight)
        {
            if (!lightCamera)
            {
                lightCamera = CreateDirLightCamera();

                CreateRenderTexture();
            }
        
            TransformWorldToShadow.Clear();
            for (int i = 0; i < 4; i++)
            {
                ConstructLightCameraSplits(i);

                lightCamera.targetTexture = depthTextures[i];
                lightCamera.RenderWithShader(_shaderCaster, "");

                Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(lightCamera.projectionMatrix, false);
                TransformWorldToShadow.Add(projectionMatrix * lightCamera.worldToCameraMatrix);
            }

            Shader.SetGlobalMatrixArray("_gWorld2Shadow", TransformWorldToShadow);   
        }
    }
    
    private void OnDestroy()
    {
        lightCamera = null;

        for (int i = 0; i < 4; i++)
        {
            if (depthTextures[i])
            {
                DestroyImmediate(depthTextures[i]);
            }
        }
    }
}
