using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[System.Serializable]
public struct RayTracingMaterial
{
    public Color color;
    public Color emissionColor;
    [Range(0f,100f)] public float emissionIntensity;
    [Range(0f,1)] public float smoothness;
    public static int SizeInBytes()
    {
        return sizeof(float) * 4 + sizeof(float) * 4 + sizeof(float) + sizeof(float);
    }
}
