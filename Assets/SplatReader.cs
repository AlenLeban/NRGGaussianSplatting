using System;
using System.IO;
using UnityEngine;

public class Splat
{
    public Vector3[] positions;
    public Vector3[] scales;
    public Color[] colors;
    public Quaternion[] rotations;

    public Splat(int numSplats)
    {
        positions = new Vector3[numSplats];
        scales = new Vector3[numSplats];
        colors = new Color[numSplats];
        rotations = new Quaternion[numSplats];
    }
}
public class SplatReader
{
    public static Splat ReadSplatFile(string streamingAssetFilename)
    {
        
        string combinedPath = Path.Combine(new string[] { Application.streamingAssetsPath, streamingAssetFilename });
        Debug.Log("Combined path: " + combinedPath);
        if (File.Exists(combinedPath))
        {
            long fileSize = new System.IO.FileInfo(combinedPath).Length;
            int numSplats = (int)(fileSize / 32);
            Debug.LogFormat("filesize: {0}", fileSize);
            Debug.LogFormat("Num splats: {0}", fileSize / 32.0f);
            using (var stream = File.Open(combinedPath, FileMode.Open))
            {
                using (var reader = new BinaryReader(stream, System.Text.Encoding.UTF8, false))
                {
                    Splat splat = new Splat(numSplats);
                    for (int i = 0; i < numSplats; i++)
                    {
                        splat.positions[i].x = reader.ReadSingle();
                        splat.positions[i].y = reader.ReadSingle();
                        splat.positions[i].z = reader.ReadSingle();

                        splat.scales[i].x = reader.ReadSingle();
                        splat.scales[i].y = reader.ReadSingle();
                        splat.scales[i].z = reader.ReadSingle();

                        splat.colors[i].r = reader.ReadByte();
                        splat.colors[i].g = reader.ReadByte();
                        splat.colors[i].b = reader.ReadByte();
                        splat.colors[i].a = reader.ReadByte();

                        float quatx = reader.ReadByte();
                        float quaty = reader.ReadByte();
                        float quatz = reader.ReadByte();
                        float quatw = reader.ReadByte();
                        splat.rotations[i].Set(
                            (quatx - 128) / 128.0f, 
                            (quaty - 128) / 128.0f, 
                            (quatz - 128) / 128.0f, 
                            (quatw - 128) / 128.0f
                        );
                    }
                    return splat;
                }
            }
        }
        return null;
    }
}
