Shader "Custom/NewUnlitUniversalRenderPipelineShader"
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
                int mappedInstanceId = SortedIndexMap[IN.instance_id];
                float3 globalPosition = SphereLocations[mappedInstanceId];
                globalPosition.y *= -1;
                float3 scale = Scales[mappedInstanceId];
                // scale.y *= -1;
                // scale.z *= -1;
                // float temps = scale.y;
                // scale.y = scale.z;
                // scale.z = temps;
                //float4 rotationQuat = Rotations[mappedInstanceId];
                // float tempr = rotationQuat.z;
                // rotationQuat.z = rotationQuat.x;
                // rotationQuat.x = tempr;
                float4 q_raw = Rotations[mappedInstanceId];
                float4 rotationQuat = float4(q_raw.w, q_raw.x, q_raw.y, q_raw.z);
                rotationQuat.z *= -1;
                rotationQuat.w *= -1;
                // float tempr = rotationQuat.y;
                // rotationQuat.y = rotationQuat.w;
                // rotationQuat.w = tempr;
                //rotationQuat.w *= -1;
                v2f o = (v2f)0;
                float aspectRatio = _ScreenParams.y / _ScreenParams.x;
                int positionIndex = Triangles[IN.vertex_id];
                float4 localPosition = float4(Positions[positionIndex] * _Scale, 1);
                localPosition.x *= aspectRatio;
                float3 position = localPosition + globalPosition;
                float4 viewSpacePosition = mul(UNITY_MATRIX_V, float4(globalPosition, 1));
                float4 centerViewPosition = mul(UNITY_MATRIX_VP, float4(globalPosition, 1));
                float maxScale = max(max(scale.x, scale.y), scale.z) * 2;
                o.color = Colors[mappedInstanceId] / 255.0f;
                //o.color = float4(Depths[IN.instance_id], Depths[IN.instance_id], Depths[IN.instance_id], 1.0);
                
                //o.depth = Depths[IN.instance_id];
                //float3x3 faceCameraRotation = NormalRotationMatrix(float3(0, 1, 0), forward);

                //float3 viewDir = normalize(position - _WorldSpaceCameraPos);
                //float3 forward = viewDir;
                //float3 right = normalize(cross(forward, float3(0, 1, 0)));
                //float3 up = cross(right, forward);
                //float3x3 faceCameraRotation = float3x3(right, up, forward);
                
                //float3 rotatedPosition = mul(localPosition, faceCameraRotation);

                // this is needed in order for splats that are visible in view but clipped "quite a lot" to work
                // float4x4 matrixP = UNITY_MATRIX_P;
                // float tanFovX = rcp(matrixP._m00 * aspectRatio);
                // float tanFovY = rcp(matrixP._m11);
                // float limX = 1.3f * tanFovX;
                // float limY = 1.3f * tanFovY;
                // float3 viewPos = finalViewPosition;
                // float z_inv = rcp(viewPos.z);
                // float z_inv2 = z_inv * z_inv;
                // viewPos.x = clamp(viewPos.x * viewPos, -limX, limX) * viewPos.z;
                // viewPos.y = clamp(viewPos.y * viewPos, -limY, limY) * viewPos.z;
                // float focalx = _ScreenParams.x * matrixP._m00 / 2;
                // float focaly = _ScreenParams.y * matrixP._m00 / 2;

                // float3x3 J = float3x3(
                //     focalx * z_inv2, 0, -(focalx * viewPos.x) * z_inv2,
                //     0, focaly * z_inv2, -(focaly * viewPos.y) * z_inv2,
                //     0, 0, 0
                // );

                // float3 temp = scale[0];
                // scale[0] = scale[1];
                // scale[1] = temp;
                float z_inv = rcp(viewSpacePosition.z);
                float fx = UNITY_MATRIX_P[0][0];
                float fy = UNITY_MATRIX_P[1][1] * aspectRatio;
                float3x3 J = float3x3(
                   fx,     0,       -fx * viewSpacePosition.x/_ScreenParams.x,
                   0,     fy,       -fy * viewSpacePosition.y/_ScreenParams.y,
                   0,     0,       0
                );
                // float3 tempJ = J[1];
                // J[1] = J[2];
                // J[2] = tempJ;
                // float3x3 J = float3x3(
                //    1,     0,       0,
                //    0,     1,       0,
                //    0,     0,       0
                // );
                //rotationQuat.z *= -1;
                float3x3 R_inv = (float3x3)quaternion_to_matrix(rotationQuat);
                
                float3x3 S_inv2 = float3x3(
                    scale.x*scale.x,   0,  0, 
                    0,  scale.y*scale.y,   0,  
                    0,  0,  scale.z*scale.z );
                float3x3 S_inv = float3x3(
                    scale.x,   0,  0, 
                    0,  scale.y,   0,  
                    0,  0,  scale.z ) * 6;
                //S_inv2 *= (1/(maxScale*maxScale));
                float3x3 cov = mul(R_inv, mul(S_inv2, transpose(R_inv)));
                float3x3 SR = mul(R_inv, mul(S_inv, transpose(R_inv)));
                float3x3 view = (float3x3)UNITY_MATRIX_V;
                float3 temp = view[0];
                view[0] = -view[1];
                view[1] = temp;
                //float3x3 view = float3x3(1,0,0,0,1,0,0,0,1);
                float3x3 viewCov = mul(J, mul(view, mul(cov, mul(transpose(view), transpose(J)))));
                float3x3 projectedScale = mul(J, mul(view, mul(SR, mul(transpose(view), transpose(J)))));
                float2x2 scale2D = float2x2(
                    projectedScale[0][0], projectedScale[0][1],
                    projectedScale[1][0], projectedScale[1][1]);
                // projectedScale[0][0] += 0.00001f;
                // projectedScale[1][1] += 0.00001f;
                //scale2D = clamp(scale2D, 0, 3);
                float2x2 projectedCov = float2x2(
                    viewCov[0][0], viewCov[0][1],
                    viewCov[1][0], viewCov[1][1]);
                projectedCov[0][0] += 0.00001f;
                projectedCov[1][1] += 0.00001f;
                float det = projectedCov[0][0] * projectedCov[1][1] - projectedCov[0][1] * projectedCov[1][0];
                float2x2 cov_inv = float2x2(
                    projectedCov[1][1], -projectedCov[0][1],
                    -projectedCov[1][0], projectedCov[0][0]) / det;


                float minu = -1 * scale2D[0][0];
                float maxu =  1 * scale2D[0][0];
                float minv = -1 * scale2D[1][1];
                float maxv =  1 * scale2D[1][1];
                float2 uvs[6] = {
                    float2(minu,maxv),
                    float2(maxu,minv),
                    float2(minu,minv),
                    
                    float2(maxu,minv),
                    float2(minu,maxv),
                    float2(maxu,maxv),
                };

                o.uv = uvs[IN.vertex_id];

                float2 debug_uvs[6] = {
                    float2(-1,1),
                    float2(1,-1),
                    float2(-1,-1),
                    
                    float2(1,-1),
                    float2(-1,1),
                    float2(1,1),
                };

                o.uv = uvs[IN.vertex_id];
                o.debug_uv = debug_uvs[IN.vertex_id];

                o.cov = cov_inv;
                float4 finalViewPosition = centerViewPosition + localPosition * float4(scale2D[1][1], scale2D[0][0], 1, 1);
                o.position = finalViewPosition;

                //o.position.xy = centerViewPosition.xy + mul(cov_inv, localPosition.xy);
                return o;
            }

            FS_OUT frag (v2f i)
            {
                FS_OUT o = (FS_OUT)0;
                //i.cov = 0.5 * (i.cov + transpose(i.cov));
                float gauss = exp(-mul(mul(i.uv, i.cov), i.uv)/2);
                //float gauss = exp(-mul(i.uv, i.uv)/2);
                //float gauss = exp(-mul(mul(i.uv, i.cov), i.uv));
                //float4 color = float4(1, 1, 1, gauss);

                float4 color = float4(i.color.xyz, gauss * i.color.w);
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
