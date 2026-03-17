Shader "Custom/NewUnlitUniversalRenderPipelineShader2"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent" }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        ZTest LEqual
        Cull Off

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag


            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "UnityCG.cginc"

            struct Attributes
            {
                uint vertex_id : SV_VertexID;
                uint instance_id : SV_InstanceID;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float4 color : COLOR;
                float2 uv: TEXCOORD0;
                float2x2 cov : TEXCOORD1;
                float2 debug_uv: TEXCOORD3;
                float2 center : TEXCOORD4;
                float aspectInv : TEXCOORD5;
                //float depth : SV_Depth;
            };

            struct FS_OUT
            {
                float4 color: SV_Target;
                
                //float depth: SV_Depth;
            };


            StructuredBuffer<float3> SphereLocations;
            StructuredBuffer<int> Triangles;
            StructuredBuffer<float3> Positions;
            StructuredBuffer<float4> Rotations;
            StructuredBuffer<float4> Colors;
            StructuredBuffer<float3> Scales;
            StructuredBuffer<float> Depths;
            StructuredBuffer<int> SortedIndexMap;
            //StructuredBuffer<float4> Colors;

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float _Scale = 0.05f;
            CBUFFER_END

           float4x4 quaternion_to_matrix(float4 quat)
            {
                float4x4 m = float4x4(float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0));

                float x = quat.x, y = quat.y, z = quat.z, w = quat.w;
                float x2 = x + x, y2 = y + y, z2 = z + z;
                float xx = x * x2, xy = x * y2, xz = x * z2;
                float yy = y * y2, yz = y * z2, zz = z * z2;
                float wx = w * x2, wy = w * y2, wz = w * z2;

                m[0][0] = 1.0 - (yy + zz);
                m[0][1] = xy - wz;
                m[0][2] = xz + wy;

                m[1][0] = xy + wz;
                m[1][1] = 1.0 - (xx + zz);
                m[1][2] = yz - wx;

                m[2][0] = xz - wy;
                m[2][1] = yz + wx;
                m[2][2] = 1.0 - (xx + yy);

                m[3][3] = 1.0;

                return m;
            }
            
            v2f vert (Attributes IN)
            {
                v2f o = (v2f)0;
                int mappedInstanceId = SortedIndexMap[IN.instance_id];
                float3 scale = Scales[mappedInstanceId] * 2 * _Scale;
                float4 q_raw = Rotations[mappedInstanceId];
                float4 rotationQuat = float4(q_raw.w, q_raw.x, q_raw.y, q_raw.z);
                rotationQuat.z *= -1;
                rotationQuat.w *= -1;
                float3 globalPosition = SphereLocations[mappedInstanceId];
                int positionIndex = Triangles[IN.vertex_id];
                globalPosition.y *= -1;
                float4 viewGlobalPosition = mul(UNITY_MATRIX_V, float4(globalPosition, 1));
                if (viewGlobalPosition.z > -0.5)
                {
                    scale *= 0;
                }
                float4 projectedGlobalPosition = mul(UNITY_MATRIX_P, viewGlobalPosition);
                o.center = projectedGlobalPosition.xy / projectedGlobalPosition.w;
                o.color = Colors[mappedInstanceId] / 255.0f;
                //o.cov = float2x2(1,0,0,1);
                
                float aspectRatio = _ScreenParams.y / _ScreenParams.x;
                float4 localPosition = float4(Positions[positionIndex] * _Scale, 0);
                localPosition.x *= aspectRatio;
                //localPosition.xyz /= viewGlobalPosition.z;
                o.aspectInv = rcp(aspectRatio);
                


                float3x3 R_inv = (float3x3)quaternion_to_matrix(rotationQuat);
                
                float3x3 S_inv2 = float3x3(
                    scale.x*scale.x,   0,  0, 
                    0,  scale.y*scale.y,   0,  
                    0,  0,  scale.z*scale.z);

                float z_inv = rcp(viewGlobalPosition.z);
                float fx = UNITY_MATRIX_P[0][0];
                float fy = UNITY_MATRIX_P[1][1] * aspectRatio;
                float3x3 J = float3x3(
                   fx * z_inv,     0,       -fx * viewGlobalPosition.x * z_inv * z_inv,
                   0,     fy * z_inv,       -fy * viewGlobalPosition.y * z_inv * z_inv,
                   0,     0,       0
                );
                float3x3 J2 = float3x3(
                   fx,     0,       -fx * viewGlobalPosition.x * z_inv,
                   0,     fy,       -fy * viewGlobalPosition.y * z_inv,
                   0,     0,       0
                );
                float3x3 S_scale = float3x3(
                    scale.x,   0,  0, 
                    0,  scale.y,   0,  
                    0,  0,  scale.z ) * 10;
                //S_inv2 *= (1/(maxScale*maxScale));
                float3x3 cov = mul(R_inv, mul(S_inv2, transpose(R_inv)));
                float3x3 SR = mul(R_inv, mul(S_scale, transpose(R_inv)));
                float3x3 view = (float3x3)UNITY_MATRIX_V;
                // float3 temp = view[0];
                // view[0] = view[1];
                // view[1] = temp;
                //float3x3 view = float3x3(1,0,0,0,1,0,0,0,1);
                float3x3 viewCov = mul(J, mul(view, mul(cov, mul(transpose(view), transpose(J)))));
                float3x3 projectedScale = mul(J2, mul(view, mul(SR, mul(transpose(view), transpose(J2)))));
                float2x2 scale2D = float2x2(
                    projectedScale[0][0], projectedScale[0][1],
                    projectedScale[1][0], projectedScale[1][1]);
                scale2D = clamp(scale2D, 0, 3);

                localPosition.x *= scale2D[0][0];
                localPosition.y *= scale2D[1][1];
                //localPosition.xyz *= max(scale.x, max(scale.y, scale.z)) * 3;
                // projectedScale[0][0] += 0.00001f;
                // projectedScale[1][1] += 0.00001f;
                float2x2 projectedCov = float2x2(
                    viewCov[0][0], viewCov[0][1],
                    viewCov[1][0], viewCov[1][1]);
                projectedCov[0][0] += 0.00001f;
                projectedCov[1][1] += 0.00001f;
                float det = projectedCov[0][0] * projectedCov[1][1] - projectedCov[0][1] * projectedCov[1][0];
                float2x2 cov_inv = float2x2(
                    projectedCov[1][1], -projectedCov[0][1],
                    -projectedCov[1][0], projectedCov[0][0]) / det;

                o.cov = cov_inv;

                //projectedGlobalPosition.xyz /= projectedGlobalPosition.w;
                //projectedGlobalPosition.w = 1;
                float4 finalScreenPosition = projectedGlobalPosition + localPosition;
                o.position = finalScreenPosition;



                float2 debug_uvs[6] = {
                    float2(-1,1),
                    float2(1,-1),
                    float2(-1,-1),
                    
                    float2(1,-1),
                    float2(-1,1),
                    float2(1,1),
                };

                o.uv = float2(finalScreenPosition.x / finalScreenPosition.w, finalScreenPosition.y /  finalScreenPosition.w);
                o.debug_uv = debug_uvs[IN.vertex_id];
                return o;
            }

            FS_OUT frag (v2f i)
            {
                FS_OUT o = (FS_OUT)0;
                //i.cov = 0.5 * (i.cov + transpose(i.cov));
                //float gauss = exp(-mul(mul(i.uv, i.cov), i.uv)/2);
                float2 offset = (i.uv - i.center);
                offset.x *= i.aspectInv;
                float gauss = exp(-mul(offset, mul(i.cov, offset))/2);
                //float gauss = exp(-mul(mul(i.uv, i.cov), i.uv));
                //float4 color = float4(1, 1, 1, gauss);

                float4 color = float4(i.color.xyz, gauss * i.color.w);
                //float4 color = float4(fmod(offset.x, 1), fmod(offset.y, 1), 0, i.color.w);
                //float4 color = float4(fmod(i.center.x, 1), fmod(i.center.y, 1), 0, i.color.w);
                //float4 color = float4(fmod(i.center.x, 1), fmod(i.center.y, 1), 0, i.color.w);
                //float4 color = float4(i.uv.x, i.uv.y, 0, 1);
                //color += clamp(pow(abs(i.debug_uv.x * i.debug_uv.y), 8), 0, 1); // debug
                color.xyz = pow(color.xyz, 2.2f);
                o.color = color;
                return o;
            }
            ENDHLSL
        }
    }
}
