using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.UIElements;

[ExecuteAlways, ImageEffectAllowedInSceneView]
public class RayTracer : MonoBehaviour
{
    [SerializeField] bool m_RayTracerEnabled = true;
    [SerializeField] Shader rayTracingShader;
    Material rayTracingMat;
    [SerializeField] Shader frameAveragerShader;
    private Material frameAveragerMat;

    [SerializeField, Range(10, 100)] private int safetyRejectionTries = 100;
    [SerializeField, Range(1,50)] private int bounces = 10;
    [SerializeField, Range(1, 100)] private int raysPerPixel = 1;
    
    [SerializeField] private Color skyColor = Color.white;
    [SerializeField] private Color skyBottom = Color.blue;
    [SerializeField] private Color horizonColor = Color.blue;
    [SerializeField] private Color sunColor = Color.blue;
    [SerializeField] private float sunStrength = 300f;
    [SerializeField] private float sunFocus = 500f;
    
    [SerializeField] private bool textureAccumulation = false;
    
    private RenderTexture resultTexture;
    private int frameNumber = 1; // Used to have different random numbers between frames and denoise the image

    
    //-------------Compute buffers-------------//
    private ComputeBuffer spheresBuffer;


    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (m_RayTracerEnabled)
        {
            InitMaterial();

            if (!textureAccumulation)
            {
                Graphics.Blit(null, destination, rayTracingMat);
            }
            else
            {
                frameAveragerMat = new Material(frameAveragerShader);
                
                if(resultTexture== null)
                {
                    resultTexture = new RenderTexture(source.width, source.height, 0, RenderTextureFormat.ARGBFloat);
                }
                RenderTexture previousFrame = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.ARGBFloat);
                Graphics.Blit(resultTexture, previousFrame);
        
                rayTracingMat.SetInt("frameNumber", frameNumber);
                RenderTexture currentFrame = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.ARGBFloat);
                Graphics.Blit(null, currentFrame, rayTracingMat);
        
                frameAveragerMat.SetTexture("previousFrame", previousFrame);
                frameAveragerMat.SetInt("frameNumber", frameNumber);
                Graphics.Blit(currentFrame, resultTexture, frameAveragerMat);
        
                Graphics.Blit(resultTexture, destination);

                RenderTexture.ReleaseTemporary(currentFrame);
                RenderTexture.ReleaseTemporary(previousFrame);
        
                frameNumber += Application.isPlaying ? 1 : 0;
            }
        }
        else
        {
            Graphics.Blit(source, destination);
        }
        
        OnDisable();
    }

    private void InitMaterial()
    {
        rayTracingMat = new Material(rayTracingShader);
        rayTracingMat.SetMatrix("LocalToWorld", Camera.main.transform.localToWorldMatrix);
                
        float planeHeight = Camera.main.nearClipPlane * Mathf.Tan(Camera.main.fieldOfView * 0.5f) * 2;
        float planeWidth = planeHeight * Camera.main.aspect;
        rayTracingMat.SetVector("ViewParams", new Vector3(planeWidth, planeHeight, Camera.main.nearClipPlane));
                
        rayTracingMat.SetFloat("safetyRejectionTries", safetyRejectionTries);
        rayTracingMat.SetInt("bounces", bounces);
        rayTracingMat.SetInt("raysPerPixel", raysPerPixel);
                
        rayTracingMat.SetVector("skyColor", skyColor);
        rayTracingMat.SetVector("skyBottom", skyBottom);
        rayTracingMat.SetVector("horizonColor", horizonColor);
        rayTracingMat.SetVector("sunColor", sunColor);
        rayTracingMat.SetFloat("sunStrength", sunStrength);
        rayTracingMat.SetFloat("sunFocus", sunFocus);
                
        GetRayTracedSpheres();
    }

    private void GetRayTracedSpheres()
    {
        RayTracedSphere[] sphereObjects = FindObjectsOfType<RayTracedSphere>();
        Sphere[] spheres = new Sphere[sphereObjects.Length];
        for (int i = 0; i < sphereObjects.Length; i++)
        {
            spheres[i] = new Sphere();
            spheres[i].position = sphereObjects[i].GetPosition();
            spheres[i].radius = sphereObjects[i].GetRadius();
            spheres[i].rayTracingMaterial = sphereObjects[i].GetMaterial();
        }
        
        spheresBuffer = new ComputeBuffer(sphereObjects.Length, Sphere.SizeInBytes());
        spheresBuffer.SetData(spheres);
        rayTracingMat.SetBuffer("SpheresBuffer", spheresBuffer);
        rayTracingMat.SetInt("NumSpheres", sphereObjects.Length);
    }

    void OnDisable()
    {
        if (spheresBuffer != null)
        {
            spheresBuffer.Release();
        }
    }
    
}

