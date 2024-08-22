// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

Shader "Unlit/RayTracingShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            struct Ray{
                float3 origin;
                float3 direction;
            };

            struct RayTracingMaterial
            {
                float4 color;
                float4 emissionColor;
                float emissionStrength;
                float smoothness;
            };
            
            struct HitInfo{
                bool didHit;
                float distance;
                float3 hitPoint;
                float3 normal;
                RayTracingMaterial material;
            };
            
            struct Sphere
            {
                float3 position;
                float radius;
                RayTracingMaterial rayTracingMaterial;
            };
            
            StructuredBuffer<Sphere> SpheresBuffer;
            int NumSpheres;

            float4x4 LocalToWorld;
            float3 ViewParams; // WIDTH, HEIGHT, NEAR (NOT IN PIXELS)
            float4 _MainTex_TexelSize;
            int safetyRejectionTries;
            int seed;
            int bounces;
            int raysPerPixel;
            float4 skyColor;
            float4 skyBottom;
            float4 sunColor;
            float4 horizonColor;
            float sunStrength;
            float sunFocus;
            int frameNumber;
            
            float rand(inout int seed, float min = 0, float max = 1){
                seed = seed * 747796405 + 2891336453;
				uint result = ((seed >> ((seed >> 28) + 4)) ^ seed) * 277803737;
				result = (result >> 22) ^ result;
				return min + (max - min) * (result / 4294967295.0);
            }

            HitInfo RaySphere(Ray ray, float3 sphereCenter, float sphereRadius){
                HitInfo hitInfo = (HitInfo)0;
                float3 cq = sphereCenter - ray.origin;
                float a = dot(ray.direction, ray.direction); // Should always be 1
                float b = dot(-2 * ray.direction, cq);
                float c = dot(cq, cq) - sphereRadius * sphereRadius;

                float discriminant = b * b - 4 * a * c; // Quadratic formula
                if(discriminant >= 0){ // Means that the square root can be solved, meaning there exists a value
                    float root = sqrt(discriminant);
                    float dst = (-b - root) / (2 * a);
                                        
                    if(dst >= 0){ // Makes no sense that the distance is negative (we would be negating the rays direction which doesn't make sense lead to errors)
                        hitInfo.distance = dst;
                        hitInfo.didHit = true;
                        hitInfo.hitPoint = ray.origin + ray.direction * hitInfo.distance;

                        /* If we know the hit point, we can calculate the vector between the sphere center and the point in the perimeter.
                         We don't use the normalize() function because we already know the magnitude of the vector because it is the radius of the sphere, so we can just divide
                         by the radius in order to normalize the vector */
                        hitInfo.normal = (hitInfo.hitPoint - sphereCenter) / sphereRadius; 
                    }
                }
                return hitInfo;
            }


            /* Devuelve la intersección más cercana de todas las esferas del buffer */
            HitInfo RaySphereCollision(Ray ray)
            {
                HitInfo closestHit = (HitInfo)0;
                closestHit.distance = 1.#INF;
                
                for (int sphere = 0; sphere < NumSpheres; ++sphere)
                {
                    Sphere s = SpheresBuffer[sphere];
                    HitInfo h = RaySphere(ray, s.position, s.radius);
                    if(h.didHit && h.distance < closestHit.distance)
                    {
                        closestHit = h;
                        closestHit.material = s.rayTracingMaterial;
                    }
                }
                return closestHit;
            }

            float3 ComputeRayDirection(Ray ray, float2 uv)
            {
                //-------------USING LOCAL CAMERA COORDS (ASPECT RATIO DOESN'T QUITE WORK IDKW)-------------//
                
                // /* Pasamos coordenadas de textura a NDC que corresponderan a la alineaci�n de la c�mara 
                // como si estuviesemos en espacio local de camara (queremos que el centro de la camara (0,0) sea el 
                // centro de nuestras coordenadas de textura, que es igual que pasarlas a NDC, porque el (0,0) del espacio local de la camara, 
                // es el centro de la pantalla, por tanto es como pasar UVs a NDC) */
                // /* Note: restamos -0.5f para pasar de 0,0 izquierda abajo 1,1 derecha arriba a 0,0 centro y extremos -0.5 y 0.5, manteniendo el tamaño
                // y haciendo que estas coordenadas sean relativas al espacio local de la camara */
                // float3 localSpaceCoords = float3(uv - 0.5f, 1);
                //
                // /* https://blog.demofox.org/2020/05/25/casual-shadertoy-path-tracing-1-basic-camera-diffuse-emissive/ Explains the deformation seen, to solve this: */
                // /* Como las coordenadas NDC van de [-1,1] x,y,z (forma de cuadrado opengl) ([0, 1] Unity) y el viewport en este caso tiene un aspect ratio de 16/9, la imagen se está deformando,
                // por tanto tenemos que escalar las coordenadas para que pasen de ser un cuadrado a tener la relacion de aspecto del viewport (near plane) */
                // localSpaceCoords *= ViewParams;
                //
                // /* Como suponemos que estas coordenadas llamadas NDC son relativas al espacio local de la camara, solo hay que pasarlas a world space,
                // usando la model transform de la camara. */
                // float3 pixelTarget = mul(LocalToWorld, float4(localSpaceCoords,1)).xyz;
                //
                // /* Restamos el punto en world space del origen del rayo y del pixel correspondiente. */
                // return normalize(pixelTarget.xyz - ray.origin);


                
                //-------------NDC TO WORLD SPACE-------------//
                
                float3 ndc = float3(uv * 2.0f - 1.0f, 0); // Z = 0 Porque creo que estoy usando Direct3D11 y NDC.z va de [0, 1] 
                float4 viewSpace = mul(unity_CameraInvProjection, float4(ndc, 1));

                /* https://discussions.unity.com/t/urgent-a-strange-problem-about-using-unity_camerainvprojection/875300/6 */
                /* Negamos la Z en view space para que pase a ser positiva, por alguna razón (API grafica, supongo) la imagen sale flippeada sobre las Z */
                viewSpace.z = -viewSpace.z;
                float4 worldSpace = mul(unity_CameraToWorld, viewSpace);

                /* https://discussions.unity.com/t/what-does-unity_camerainvprojection-actually-is-how-to-transform-point-from-ndc-space-to-view-space/226646 */
                /* Dividimos por la coordenada homogenea porque a la larga es igual que multiplicar las NDC por la w para pasar a clip space, pero como no tenemos la w, lo hacemos así */
                worldSpace /= worldSpace.w;
                return normalize(worldSpace.xyz - ray.origin);
            }

            /* Devuelve un vector unitario dentro de una esfera unitaria */
            float3 RandomUnitVectorInUnitSphere()
            {
                for(int i = 0; i < safetyRejectionTries; ++i)
                {
                    float3 vectorInUnitSphere;
                    vectorInUnitSphere.x = rand(seed, -1, 1);
                    vectorInUnitSphere.y = rand(seed, -1, 1);
                    vectorInUnitSphere.z = rand(seed, -1, 1);

                    float distanceSquared = dot(vectorInUnitSphere, vectorInUnitSphere);
                    if(distanceSquared <= 1) return vectorInUnitSphere / sqrt(distanceSquared); /* Una forma de normalizar por que ya tenemos la distancia al cuadrado */
                }
                return float3(0,0,0);
            }

            /* Generates a random seed based on the number of pixel the thread is processing */
            int GenerateRandomSeed(float2 uv)
            {
                int2 pixelCoord = uv * _ScreenParams.xy;
                int pixelIndex = pixelCoord.y + pixelCoord.x * _ScreenParams.x;
                return pixelIndex + frameNumber * 53478953;
            }
            
            /* Dado una intersección te genera una dirección random dentro del semicirculo formado por la normal de la intersección */
            float3 VectorInHemishpereOfTheNormal(HitInfo hit)
            {
                float3 randomUnitVector = RandomUnitVectorInUnitSphere();
                if(dot(randomUnitVector, hit.normal) <= 0)
                {
                    return -randomUnitVector;
                }
                return randomUnitVector;
            }

            /* Devuelve la iluminación ambiente */
            float3 GetAmbientLight(Ray ray)
            {
                float3 sunDirection = _WorldSpaceLightPos0;

                /* La contribución del sol se calcula sabiendo si el rayo está mirando en la dirección del sol, sun focus define
                como de focalizado está el sol (como de pequeño es) y sun strength cuanta intensidad tiene */
                float sunContribution = pow(max(0, dot(ray.direction, sunDirection)), sunFocus) * sunStrength;

                /* Se define que los rayos que tengan una y superior a 0.09 serán del color del cielo, y con una y de entre 0.01
                tendran el color del horizonte */
                float transitionSky = smoothstep(0.01, 0.09, ray.direction.y);

                /* Se define que los rayos que tengan una -y superior a 0.01 serán de color bottom (-y es como si flipeasemos el vector
                por tanto es como decir que si y es menor a -0.01 entonces el color es bottom, y si es mayor que -0.01 entonces es
                del color del horizonte del horizonte) */
                float transitionBottom = smoothstep(0, 0.01, -ray.direction.y);
                
                float3 skybox;

                /* Visible sun es un booleano que nos dice si el sol está por debajo del horizonte y que por tanto no se muestre */
                int visibleSun;
                if(ray.direction.y > 0)
                {
                    skybox = lerp(horizonColor, skyColor, transitionSky);
                    visibleSun = 1;
                }
                else
                {
                    skybox = lerp(horizonColor, skyBottom, transitionBottom);
                    visibleSun = 0;
                }
                
                return skybox + sunContribution * sunColor * visibleSun;
            }

            

            /* Para trazar un rayo, la idea es hacerlo del revés e ir acumulando la cantidad de luz que al final llegará
            a la cámara (incoming light). Si un rayo intersecta, calcularemos una dirección de rebote random o lambertiana consiguiendo así
            iluminación difusa (el rayo puede rebotar hacia cualquier dirección dentro del semicirculo formado por la normal, si
            usasemos el lambertian como BRDF la probabilidad de cada direccion seria la misma pero la intensidad de la reflexion depende
            del cos() entre la normal y la direccion de la luz, tiene sentido que la intensidad de la luz sea menor cuando el cos() es menor
            debido a que cuando el cos() es mas bajo es como si la luz llegase más esparcida, es decir llega menos luz por punto, y por eso,
            tambien refleja menos luz).

            https://chatgpt.com/c/dd127d82-08fb-4b13-91ad-7b2df501e066

            Y volveremos a hacer una colisión hasta que pasemos el número de rebotes máximo (bounces) o hasta que
            el rayo se pierda por que no ha colisionado. Por cada rebote iremos acumulando los colores, y cuando al final el rayo
            intersecte con una fuente de luz (algo que emite luz) el rayo por fin será visible. */
            float3 TraceRay(Ray ray)
            {
                float3 rayColor = float3(1,1,1);
                float3 incomingLight = float3(0,0,0);

                for (int i = 0; i < bounces; ++i)
                {
                    HitInfo hit = RaySphereCollision(ray);
                    if(hit.didHit)
                    {
                        ray.origin = hit.hitPoint;
                        /* Random diffuser */
                        //ray.direction = VectorInHemishpereOfTheNormal(hit);

                        /* Asignamos direcciones aleatorias más cercanas a la normal (Cosine Weighted Distribution), como en la iluminación global,
                        la intensidad de la reflexión en un punto depende de cuántas veces ese punto es alcanzado por la luz,
                        si hacemos que en direcciones mas cercanas a la normal se reflejen más rayos esto a la larga es como dar más intensidad
                        a los rayos que tienen la misma dirección y sentido que el rayo.*/
                        float3 diffuseDirection = normalize(hit.normal + RandomUnitVectorInUnitSphere());
                        float3 specularDirection = reflect(ray.direction, hit.normal);

                        /* Debido a que sumar la contribución difusa en un modelo local como phong y no global como el ray tracing hace que no se conserve
                        la energia de entrada al reflejarse, interpolaremos entre las 2 direcciones, basandonos en como de lisa es la superfície para no
                        generar más luz de la que incide y solo cambiando como de especular es la reflexión */ 
                        ray.direction = lerp(diffuseDirection, specularDirection, hit.material.smoothness);
                        
                        float3 emittedLight = hit.material.emissionColor * hit.material.emissionStrength;
                        incomingLight += emittedLight * rayColor;
                        rayColor *= hit.material.color;
                    }
                    else
                    {
                        incomingLight += GetAmbientLight(ray) * rayColor;
                        break;
                    }
                }
                return incomingLight;
            }

            /* Debido a que por cada rebote calculamos un vector random en la dirección del semicirculo de la normal del rebote
            puede ser que este vector random no rebote luego con nada, por tanto aparecen pixeles negros al final debido a que
            no han conseguido colisionar con nada, para solucionar este problema de ruido, podemos definir el número de rayos que
            se lanzarán por pixel, para que la probabilidad para que uno de ellos golpee sea más alta, y luego hacer la media de
            todos los rayos. Quitamos mucho del ruido pero sigue habiendo porque ahora las transiciones no son exactas debido a que
            se hace la media de los colores */
            float4 TraceMultipleRaysPerPixel(Ray ray)
            {
                float3 rayColor = 0;
                for (int rays = 0; rays < raysPerPixel; ++rays)
                {
                    rayColor += TraceRay(ray);
                }
                return float4(rayColor / raysPerPixel, 1);
            }

            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                Ray ray;
                ray.origin = _WorldSpaceCameraPos;
                ray.direction = ComputeRayDirection(ray, i.uv);
                seed = GenerateRandomSeed(i.uv);

                return TraceMultipleRaysPerPixel(ray);
            }
            ENDCG
        }
    }
}
