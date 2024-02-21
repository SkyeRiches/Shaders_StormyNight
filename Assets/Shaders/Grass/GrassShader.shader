// Grass shader made using Daniel iletts grass shader tutorial https://www.youtube.com/watch?v=MeyW_aYE82s
// lighting was created with the help of Minions art and how they managed to get lighting working with urp

Shader "Skye/GrassShader"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _TipColor("Tip Color", Color) = (1,1,1,1)
        _BladeTexture("Blade Texture", 2D) = "white" {}

        _BladeWidthMin("Blade Width (Min)", Range(0, 0.1)) = 0.02
        _BladeWidthMax("Blade Width (Max)", Range(0, 0.1)) = 0.05
        _BladeHeightMin("Blade Height (Min)", Range(0, 2)) = 0.1
        _BladeHeightMax("Blade Height (Max)", Range(0, 2)) = 0.2

        _BladeSegments("Blade Segments", Range(1,10)) = 3
        _BladeBendDistance("Blade Forward Amount", Float) = 0.38
        _BladeBendCurve("Blade Curvature Amount", Range(1, 4)) = 2

        _BendDelta("Bend Variation", Range(0, 1)) = 0.2

        _GrassMap("Grass Visibility Map", 2D) = "white" {}
        _GrassThreshold("Grass Visibility Threshold", Range(-0.1, 1)) = 0.5
        _GrassFalloff("Greass Visibility Fade-In Falloff", Range(0, 0.5)) = 0.05

        _WindMap("Wind Offset Map", 2D) = "bump" {}
        _WindVelocity("Wind Velocity", Vector) = (1,0,0,0)
        _WindFrequency("Wind Pulse Frequency", Range(0, 1)) = 0.01

        
		_Tess("Tessellation", Range(1, 32)) = 20
		_MaxTessDistance("Max Tess Distance", Range(1, 50)) = 20

        _LightWeight("Light Color Weight", Range(0,1)) = 0.1
        _AmbientStrength("Ambient light strength", Range (0, 1)) = 0.1
    }
    SubShader
    {
       Tags
       {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
       } 
       LOD 100
       Cull Off

       HLSLINCLUDE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
 
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl" 

            #define UNITY_PI 3.14159265359f
            #define UNITY_TWO_PI 6.28318530718f
            #define BLADE_SEGMENTS 4

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;
            float4 _TipColor;
            sampler2D _BladeTexture;

            float _BladeWidthMin;
            float _BladeWidthMax;
            float _BladeHeightMin;
            float _BladeHeightMax;

            float _BladeBendDistance;
            float _BladeBendCurve;

            float _BendDelta;

            sampler2D _GrassMap;
            float4 _GrassMap_ST;
            float _GrassThreshold;
            float _GrassFalloff;

            sampler2D _WindMap;
            float4 _WindMap_ST;
            float4 _WindVelocity;
            float _WindFrequency;

            float4 _ShadowColor;

            float _Tess;
            float _MaxTessDistance;

            float _LightWeight;
            float _AmbientStrength;
        CBUFFER_END

        struct VertexInput
        {
            float4 vertex  : POSITION;
            float3 normal  : NORMAL;
            float4 tangent : TANGENT;
            float2 uv      : TEXCOORD0;
        };

        struct VertexOutput
        {
            float4 vertex  : SV_POSITION;
            float3 normal  : NORMAL;
            float4 tangent : TANGENT;
            float2 uv      : TEXCOORD0;
        };

        struct GeometryData
        {
            float4 pos      : POSITION;
            float2 uv       : TEXCOORD0;
            float3 worldPos : TEXCOORD1;
        };

        struct TesselationFactors
        {
            float edge[3] : SV_TessFactor;
            float inside  : SV_InsideTessFactor;
        };

        VertexOutput vert(VertexInput v)
        {
            VertexOutput o;

            o.vertex = TransformObjectToHClip(v.vertex.xyz);
            o.normal = v.normal;
            o.tangent = v.tangent;
            o.uv = TRANSFORM_TEX(v.uv, _GrassMap);
            return o;
        }

        VertexOutput geomVert (VertexInput v)
        {
            VertexOutput o;
            o.vertex = float4(TransformObjectToWorld(v.vertex), 1.0f);
            o.normal = TransformObjectToWorldNormal(v.normal);
            o.tangent = v.tangent;
            o.uv = TRANSFORM_TEX(v.uv, _GrassMap);
            return o;
        }

        VertexOutput tessVert(VertexInput v)
        {
            VertexOutput o;
            o.vertex = v.vertex;
            o.normal = v.normal;
            o.tangent = v.tangent;
            o.uv = v.uv;
            return o;
        }

        // Following functions from Roystan's code:
		// (https://github.com/IronWarrior/UnityGrassGeometryShader)

		// Simple noise function, sourced from http://answers.unity.com/answers/624136/view.html
		// Extended discussion on this function can be found at the following link:
		// https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
		// Returns a number in the 0...1 range.
		float rand(float3 co)
		{
			return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
		}

		// Construct a rotation matrix that rotates around the provided axis, sourced from:
		// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
		float3x3 angleAxis3x3(float angle, float3 axis)
		{
			float c, s;
			sincos(angle, s, c);

			float t = 1 - c;
			float x = axis.x;
			float y = axis.y;
			float z = axis.z;

			return float3x3
			(
				t * x * x + c, t * x * y - s * z, t * x * z + s * y,
				t * x * y + s * z, t * y * y + c, t * y * z - s * x,
				t * x * z - s * y, t * y * z + s * x, t * z * z + c
			);
		}

        //------------------- TESSELATION -----------------------
// tesselation based on daniel iletts tessellation, with some additions made based on research from minions art's tesselation

        TesselationFactors UnityCalcTriEdgeTessFactors (float3 triVertexFactors)
        {
            TesselationFactors tess;
            tess.edge[0] = 0.5 * (triVertexFactors.y + triVertexFactors.z);
            tess.edge[1] = 0.5 * (triVertexFactors.x + triVertexFactors.z);
            tess.edge[2] = 0.5 * (triVertexFactors.x + triVertexFactors.y);
            tess.inside = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0f;
            return tess;
        }

        // fade tessellation at a distance
        float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
        {
			float3 worldPosition = mul(unity_ObjectToWorld, vertex).xyz;
			float dist = distance(worldPosition, _WorldSpaceCameraPos);
			float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0);
 
			return f * tess;
        }
        
        // calculate tessellation based on distance from camera
        TesselationFactors DistanceBasedTess(float4 v0, float4 v1, float4 v2, float minDist, float maxDist, float tess)
        {
			float3 f;
			f.x = CalcDistanceTessFactor(v0, minDist, maxDist, tess);
			f.y = CalcDistanceTessFactor(v1, minDist, maxDist, tess);
			f.z = CalcDistanceTessFactor(v2, minDist, maxDist, tess);
 
			return UnityCalcTriEdgeTessFactors(f);
        }

        TesselationFactors patchConstantFunc(InputPatch<VertexInput, 3> patch)
        {
            float minDist = 2.0;
            float maxDist = _MaxTessDistance + minDist;
            TesselationFactors f;
 
            // distance based tesselation
            return DistanceBasedTess(patch[0].vertex, patch[1].vertex, patch[2].vertex, minDist, maxDist, _Tess);
        }

        [domain("tri")]
        [outputcontrolpoints(3)]
        [outputtopology("triangle_cw")]
        [partitioning("integer")]
        [patchconstantfunc("patchConstantFunc")]
        VertexInput hull(InputPatch<VertexInput, 3> patch, uint id : SV_OutputControlPointID)
        {
            return patch[id];
        }

        [domain("tri")]
        VertexOutput domain(TesselationFactors factors, OutputPatch<VertexInput, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
        {
            VertexInput i;

            #define INTERPOLATE(fieldname) i.fieldname = \
                patch[0].fieldname * barycentricCoordinates.x + \
                patch[1].fieldname * barycentricCoordinates.y + \
                patch[2].fieldname * barycentricCoordinates.z;

            INTERPOLATE(vertex)
            INTERPOLATE(normal)
            INTERPOLATE(tangent)
            INTERPOLATE(uv)

            return tessVert(i);
        }

        //--------------------------------- END TESSELATION -----------------------------
        // calculate shadow position for clip space
        float4 GetShadowPositionHClip(float3 input, float3 normal)
        {
            float3 positionWS = TransformObjectToWorld(input.xyz);
            float3 normalWS = TransformObjectToWorldNormal(normal);
 
            float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, 0));
 
 
            #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #endif
            return positionCS;
        }
        
        // This function applies a transformation (during the geometry shader),
        // converting to clip space in the process.
        GeometryData TransformGeomToClip(float3 pos, float3 offset, float3x3 transformationMatrix, float2 uv)
        {
            GeometryData o;

            o.pos = TransformObjectToHClip(pos + mul(transformationMatrix, offset));
            o.uv = uv;
            o.worldPos = TransformObjectToWorld(pos + mul(transformationMatrix, offset));

            return o;
        }

        [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
        void geom(point VertexOutput input[1], inout TriangleStream<GeometryData> triStream)
        {
            //read grass visibility texture
            float grassVisibility = tex2Dlod(_GrassMap, float4(input[0].uv, 0, 0)).r;

            if (grassVisibility >= _GrassThreshold)
            {
                float3 pos = input[0].vertex.xyz;
                float3 normal = input[0].normal;
                float4 tangent = input[0].tangent;
                float3 bitangent = cross(normal, tangent.xyz) * tangent.w;

                float3x3 tangentToLocal = float3x3
                (
                    tangent.x, bitangent.x, normal.x,
                    tangent.y, bitangent.y, normal.y,
                    tangent.z, bitangent.z, normal.z
                );

                float3x3 transformationMatrix = float3x3
                (
                    1, 0, 0,
                    0, 1, 0,
                    0, 0, 1
                );

                // randomly rotate around y
                float3x3 randRotMatrix = angleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1.0f));

                // rotate around bottom of grass by random amount
                float3x3 randBendMatrix = angleAxis3x3((rand(pos.zzx) - 0.5f) * _BendDelta * UNITY_PI, float3(-1.0f, 0, 0));

                //wind
                float2 windUV = pos.xz * _WindMap_ST.xy + _WindMap_ST.zw + normalize(_WindVelocity.xzy) * _WindFrequency * _Time.y;
                float2 windSample = (tex2Dlod(_WindMap, float4(windUV, 0, 0)).xy * 2-1) * length(_WindVelocity);

                float3 windAxis = normalize(float3(windSample.x, windSample.y, 0));
                float3x3 windMatrix = angleAxis3x3(UNITY_PI * windSample, windAxis);

                // transform grass blades to the correct tangent space
                float3x3 baseTransformationMatrix = mul(tangentToLocal, randRotMatrix);
                float3x3 tipTransformationMatrix = mul(mul(mul(tangentToLocal, windMatrix), randBendMatrix), randRotMatrix);

                float falloff = smoothstep(_GrassThreshold, _GrassThreshold + _GrassFalloff, grassVisibility);

                // randomly pick width, height and bend so that not all grass blades are same
                float width = lerp(_BladeWidthMin, _BladeWidthMax, rand(pos.xzy) * falloff);
                float height = lerp(_BladeHeightMin, _BladeHeightMax, rand(pos.zyx) * falloff);
                float forward = rand(pos.yyz) * _BladeBendDistance;

                // create blade segments by adding two verts at once
                for (int i = 0; i < BLADE_SEGMENTS; ++i)
                {
                    float t = i/(float)BLADE_SEGMENTS;
                    float3 offset = float3(width * (1-t), pow(t, _BladeBendCurve) * forward, height * t);
                    float3x3 transformationMatrix = (i==0) ? baseTransformationMatrix : tipTransformationMatrix;

                    triStream.Append(TransformGeomToClip(pos, float3(offset.x, offset.y, offset.z), transformationMatrix, float2(0, t)));
                    triStream.Append(TransformGeomToClip(pos, float3(-offset.x, offset.y, offset.z), transformationMatrix, float2(1, t)));
                }
                // add the final vertex at the tip of the grass blade
                triStream.Append(TransformGeomToClip(pos, float3(0, forward, height), tipTransformationMatrix, float2(0.5, 1.0)));
                triStream.RestartStrip();
            }
        }

        ENDHLSL
    
        Pass
        {
            Name "GrassPass"
            Tags{ "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma require geometry
            #pragma require tessellation tessHW

            #pragma vertex geomVert
            #pragma hull hull
            #pragma domain domain
            #pragma geometry geom
            #pragma fragment frag

            float4 frag(GeometryData i) : SV_Target
            {
                float4 color = tex2D(_BladeTexture, i.uv);
                
                // get shadow positions
                float4 shadowCoord = TransformWorldToShadowCoord(i.worldPos);

                // get the main lights
                #if _MAIN_LIGHT_SHADOWS_CASCADE || _MAIN_LIGHT_SHADOWS
                    Light mainLight = GetMainLight(shadowCoord);
                #else
                    Light mainLight = GetMainLight();
                #endif
                float shadow = mainLight.shadowAttenuation;

                // extra point lights support
                float3 extraLights;
                int pixelLightCount = GetAdditionalLightsCount();
                for (int j = 0; j < pixelLightCount; ++j) {
                    Light light = GetAdditionalLight(j, i.worldPos, half4(1, 1, 1, 1));
                    float3 attenuatedLightColor = (light.color) * (light.distanceAttenuation * light.shadowAttenuation);
                    extraLights += attenuatedLightColor;
                }
                float4 baseColor = lerp(_BaseColor, _TipColor, saturate(i.uv.y));
 
                // multiply with lighting color
                float4 litColor = (baseColor * float4(mainLight.color,1));
                float4 final = litColor * shadow;
                final += float4(extraLights * _LightWeight,1);

                // multiply with vertex color, and shadows
                
                // add in basecolor when lights turned down
                final += saturate((1 - shadow) * baseColor * 0.2);

                 // add in ambient color
                final += (unity_AmbientSky * _AmbientStrength);
                return final;
            }
            ENDHLSL
        }
    }
}

