Shader "Custom/SphereShaderCircles"
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
            StructuredBuffer<float4> Colors;
            StructuredBuffer<int> SortedIndexMap;
            //StructuredBuffer<float4> Colors;

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float _Scale = 0.05f;
            CBUFFER_END
            
            v2f vert (Attributes IN)
            {
                v2f o = (v2f)0;
                int mappedInstanceId = SortedIndexMap[IN.instance_id];
                float3 globalPosition = SphereLocations[mappedInstanceId];
                int positionIndex = Triangles[IN.vertex_id];
                globalPosition.y *= -1;
                float4 viewGlobalPosition = mul(UNITY_MATRIX_V, float4(globalPosition, 1));
                float4 projectedGlobalPosition = mul(UNITY_MATRIX_P, viewGlobalPosition);
                o.color = Colors[mappedInstanceId] / 255.0f;

                float4 localPosition = float4(Positions[positionIndex] * _Scale, 0);
                float4 finalPosition = projectedGlobalPosition + mul(UNITY_MATRIX_P, localPosition);
                o.position = finalPosition;


                float2 uvs[6] = {
                    float2(-1,1),
                    float2(1,-1),
                    float2(-1,-1),
                    
                    float2(1,-1),
                    float2(-1,1),
                    float2(1,1),
                };

                o.uv = uvs[IN.vertex_id];
                return o;
            }

            FS_OUT frag (v2f i)
            {
                FS_OUT o = (FS_OUT)0;
                float gauss = exp(-mul(i.uv, i.uv)/2*8);

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
