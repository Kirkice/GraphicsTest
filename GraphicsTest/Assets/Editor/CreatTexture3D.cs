using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.Linq;
using System.Text;

public class CreatTexture3D : EditorWindow
{
    [MenuItem("Tools/CreatTexture3D")]
    public static void OpenSdfGeneratorWindow()
    {
        EditorWindow.GetWindow(typeof(CreatTexture3D));
    }

    public Shader Shader;
    private Texture2D[] Texture3DArray;
    private void OnGUI()
    {
        Shader = EditorGUILayout.ObjectField("Shader:", Shader, typeof(Shader), true) as Shader;
    }

    private void CreateTextureArray(bool Blur,int sliceCount)
    {
        Texture2D texture2D = new Texture2D(sliceCount, sliceCount, TextureFormat.R8, false);
        Texture3DArray = new Texture2D[sliceCount];
    }

    private void Update()
    {
        
    }
}
