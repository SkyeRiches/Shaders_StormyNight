using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateAroundPivot : MonoBehaviour
{
    [SerializeField] Transform pivot;
    [SerializeField] float speed;

    // Update is called once per frame
    void Update()
    {
        transform.RotateAround(pivot.position, Vector3.up, Time.deltaTime * speed);
    }
}
