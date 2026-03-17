using System;
using UnityEngine;

public class DrawingTest : MonoBehaviour
{

    public Mesh mesh;
    public Material material;
    public string splatFilename = "nike.splat";
    public ComputeShader computeShader;
    public ComputeShader sortingShader;
    public float particleScale = 0.05f;

    ComputeBuffer meshTriangles;
    ComputeBuffer meshPositions;
    ComputeBuffer spherePositions;
    ComputeBuffer pointColors;
    ComputeBuffer pointScales;
    ComputeBuffer pointRotations;
    ComputeBuffer pointDepths;
    ComputeBuffer pointPositions;
    ComputeBuffer sortedIndices;

    float[] pointDepthsArray;

    int numPoints = 100;
    public Bounds bounds;
    public float radius = 2;

    int kernelIndex = 0;
    int sortingKernelIndex = 0;
    uint threadGroupSize = 64;
    int threadGroups;
    int sortingThreadGroups;

    Vector3[] splatPositions;
    Splat splat;
    int[] indexArray;
    int[] tempIndexArray;
    int counter = 9999;
    // Start is called once before the first execution of Update after the MonoBehaviour is created

    void Start()
    {


        splat = SplatReader.ReadSplatFile(splatFilename);
        //splat = new Splat(4);
        //splat.positions[0] = new Vector3(0, 0, 0);
        //splat.rotations[0] = Quaternion.Euler(45, 45, 45);
        //splat.scales[0] = new Vector3(0.1f, 0.8f, 0.1f);
        //splat.colors[0] = new Color(255, 255, 255, 255);

        //splat.positions[1] = new Vector3(0.5f, 0, 0);
        //splat.rotations[1] = Quaternion.Euler(0, 0, 0);
        //splat.scales[1] = new Vector3(0.8f, 0.1f, 0.1f);
        //splat.colors[1] = new Color(255, 255, 255, 255);

        //splat.positions[2] = new Vector3(-0.5f, 0, 0);
        //splat.rotations[2] = Quaternion.Euler(0, 0, 0);
        //splat.scales[2] = new Vector3(0.1f, 0.1f, 0.8f);
        //splat.colors[2] = new Color(255, 255, 255, 255);

        //splat.positions[3] = new Vector3(-0.7f, -0.5f, 0.5f);
        //splat.rotations[3] = Quaternion.Euler(45, 45, 45);
        //splat.scales[3] = new Vector3(0.1f, 0.8f, 0.1f);
        //splat.colors[3] = new Color(255, 255, 255, 255);

        splatPositions = new Vector3[splat.positions.Length];
        indexArray = new int[splat.positions.Length];
        tempIndexArray = new int[splat.positions.Length];
        for (int i = 0; i < indexArray.Length; i++)
        {
            indexArray[i] = i;
        }
        sortedIndices = new ComputeBuffer(indexArray.Length, sizeof(int));
        Debug.Log(splat.positions[0]);
        Debug.Log(splat.scales[0]);
        Debug.Log(splat.rotations[0]);
        Debug.Log(splat.colors[0]);
        numPoints = splat.positions.Length;
        kernelIndex = computeShader.FindKernel("CSMain");
        sortingKernelIndex = sortingShader.FindKernel("CSMain");

        /*Vector3[] spherePositionsArray = new Vector3[numPoints];
        for (int i = 0; i < numPoints; i++)
        {
            spherePositionsArray[i] = new Vector3(Random.Range(-1.0f, 1.0f), Random.Range(-1.0f, 1.0f), Random.Range(-1.0f, 1.0f)) * radius;
        }*/
        threadGroups = (int)((numPoints + (threadGroupSize - 1)) / threadGroupSize);
        sortingThreadGroups = (int)((numPoints/2 + (threadGroupSize - 1)) / threadGroupSize);

        int[] triangles = mesh.triangles;
        meshTriangles = new ComputeBuffer(triangles.Length, sizeof(uint));
        meshTriangles.SetData(triangles);
        Vector3[] positions = mesh.vertices;
        meshPositions = new ComputeBuffer(positions.Length, 3 * sizeof(float));
        meshPositions.SetData(positions);
        pointColors = new ComputeBuffer(splat.colors.Length, 4 * sizeof(float));
        pointColors.SetData(splat.colors);
        //spherePositions = new ComputeBuffer(spherePositionsArray.Length, 3 * sizeof(float));
        //spherePositions.SetData(spherePositionsArray);
        //material.SetBuffer("SphereLocations", )
        pointRotations = new ComputeBuffer(splat.rotations.Length, 4  * sizeof(float));
        pointRotations.SetData(splat.rotations);
        pointScales = new ComputeBuffer(splat.scales.Length, 3 * sizeof(float));
        pointScales.SetData(splat.scales);
        pointDepths = new ComputeBuffer(splat.positions.Length, sizeof(float));
        pointDepthsArray = new float[splat.positions.Length];
        pointPositions = new ComputeBuffer(splat.positions.Length, 3 * sizeof(float));
        pointPositions.SetData(splat.positions);

        material.SetBuffer("SphereLocations", pointPositions);
        material.SetBuffer("Triangles", meshTriangles);
        material.SetBuffer("Positions", meshPositions);
        material.SetBuffer("Rotations", pointRotations);
        material.SetBuffer("Colors", pointColors);
        material.SetBuffer("SortedIndexMap", sortedIndices);
        //material.SetBuffer("ProjectedScales", projectedScales);
        material.SetBuffer("Scales", pointScales);
        computeShader.SetBuffer(kernelIndex, "CenterPositions", pointPositions);
        computeShader.SetBuffer(kernelIndex, "Depths", pointDepths);

        sortingShader.SetBuffer(sortingKernelIndex, "Array", pointDepths);
        sortingShader.SetBuffer(sortingKernelIndex, "SortedIndices", sortedIndices);
        material.SetBuffer("Depths", pointDepths);
        sortedIndices.SetData(tempIndexArray);
    }

    // Update is called once per frame
    void Update()
    {
        material.SetFloat("_Scale", particleScale) ;
        /*if (counter > 200)
        {*/
        computeShader.SetMatrix("VPMatrix", Camera.main.projectionMatrix * Camera.main.worldToCameraMatrix);
        computeShader.Dispatch(kernelIndex, threadGroups, 1, 1);
        pointDepths.GetData(pointDepthsArray);
        Array.Copy(indexArray, tempIndexArray, indexArray.Length);
        sortedIndices.SetData(tempIndexArray);
        counter = 0;
        /*}*/
        /*for (int i = 0; i < 5000; i++)
        {
            sortingShader.SetInt("shiftSorting", i % 2);
            sortingShader.Dispatch(sortingKernelIndex, sortingThreadGroups, 1, 1);
        }*/
        //counter++;
        Array.Sort(pointDepthsArray, tempIndexArray);
        Array.Reverse(tempIndexArray);
        sortedIndices.SetData(tempIndexArray);
        //pointDepths.SetData(pointDepthsArray);
        //computeShader.SetFloat("Time", Time.time);
        //computeShader.SetBuffer(kernelIndex, "SphereLocations", spherePositions);
        Graphics.DrawProcedural(material, bounds, MeshTopology.Triangles, meshTriangles.count, numPoints);
    }

    private void OnDestroy()
    {
        meshTriangles?.Dispose();
        meshPositions?.Dispose();
        spherePositions?.Dispose();
        pointColors?.Dispose();
        pointScales?.Dispose();
        pointRotations?.Dispose();
        pointDepths?.Dispose();
        pointPositions?.Dispose();
        sortedIndices?.Dispose();
    }
}
