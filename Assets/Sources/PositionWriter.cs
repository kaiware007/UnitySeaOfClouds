using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PositionWriter : MonoBehaviour {

    public float radius = 1;
    public float heightBase = 1f;

	// Update is called once per frame
	void Update () {
        Vector2 pos;
        Vector3 pos3d = transform.position;
        pos.x = pos3d.x;
        pos.y = pos3d.z;

        float r = Mathf.Clamp01((heightBase - pos3d.y) / heightBase) * radius;

        PositionTexture.Instance.AddPosition(pos, r);
    }
}
