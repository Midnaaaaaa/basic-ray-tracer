using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways, ImageEffectAllowedInSceneView]
public class RayTracedSphere : MonoBehaviour
{
    [SerializeField] private float radius;
    public RayTracingMaterial rayTracingMaterial;
    private Material material;

    void Start()
    {
        material = GetComponent<MeshRenderer>().sharedMaterial;
    }
    
    private void OnValidate()
    {
        if (radius >= 0)
        {
            transform.localScale = new Vector3(radius / 0.5f , radius / 0.5f, radius / 0.5f);
        }
        else radius = 0;
        //material.color = rayTracingMaterial.color;
    }

    public Vector3 GetPosition()
    {
        return transform.position;
    }

    public RayTracingMaterial GetMaterial()
    {
        return rayTracingMaterial;
    }

    public float GetRadius()
    {
        return radius;
    }
}

public struct Sphere
{
    public Vector3 position;
    public float radius;
    public RayTracingMaterial rayTracingMaterial;

    public static int SizeInBytes()
    {
        return sizeof(float) * 3 + sizeof(float) + RayTracingMaterial.SizeInBytes();
    }

}
