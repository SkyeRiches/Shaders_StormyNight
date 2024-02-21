using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SendRippleData : MonoBehaviour
{
    [SerializeField] RenderTexture rendTex;
    [SerializeField] Transform target;

    void Awake()
    {
        Shader.SetGlobalTexture("_GlobalEffectRT", rendTex);
        Shader.SetGlobalFloat("_OrthographicCamSize", GetComponent<Camera>().orthographicSize);
    }

    // Update is called once per frame
    void Update()
    {
        transform.position = new Vector3(target.position.x, transform.position.y, target.position.z);
        Shader.SetGlobalVector("_Position", transform.position);
    }
}
