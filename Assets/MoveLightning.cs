using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

[ExecuteAlways]
public class MoveLightning : MonoBehaviour
{
    bool canMove = false;

    // Start is called before the first frame update
    void Start()
    {
        StartCoroutine(ChangePos());
    }

    void Update()
    {
        if (canMove)
        {
            canMove = false;
            StartCoroutine(ChangePos());
        }
    }

    IEnumerator ChangePos()
    {
        transform.position = new Vector3(Random.Range(-9, 9), 7, Random.Range(-9, 9));
        yield return new WaitForSeconds(3.8f);
        canMove = true;
    }
}
