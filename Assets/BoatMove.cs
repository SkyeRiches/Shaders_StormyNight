using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

[ExecuteAlways]
public class BoatMove : MonoBehaviour
{
    [SerializeField] Transform target1;
    [SerializeField] Transform target2;
    private Transform currentTarget;
    [SerializeField] float speed;

    // variables for creating illusion of buoyancy (using illusion of it as you cant access stuff done in vertex shader from outside)
    [SerializeField] private float amplitude = 4f;
    [SerializeField] private float freq = 2f;

    // Start is called before the first frame update
    void Start()
    {
        currentTarget = target1;
    }

    // Update is called once per frame
    void Update()
    {
        Vector3 pos = transform.position;
        pos.y += Mathf.Sin(Time.time * freq) * amplitude;
          
        transform.position = pos;

        Vector3 targetPos = new Vector3(currentTarget.position.x, transform.position.y, currentTarget.position.z);

        transform.position = Vector3.Lerp(transform.position, targetPos, Time.deltaTime * speed);
        if (Vector3.Magnitude(transform.position - currentTarget.position) < 1)
        {
            if (currentTarget == target1)
            {
                currentTarget = target2;
            }
            else
            {
                currentTarget = target1;
            }
        }

        transform.position = new Vector3(transform.position.x, Mathf.Clamp(transform.position.y, 0.8f, 1f), transform.position.z);
    }
}
