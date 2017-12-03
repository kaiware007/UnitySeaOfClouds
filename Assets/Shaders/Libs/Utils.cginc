#ifndef utils_h 
#define utils_h 

#define PI 3.14159265358979

float3 mod(float3 a, float3 b)
{
	return frac(abs(a / b)) * abs(b);
}

float3 mod(float3 a, float b)
{
	return frac(abs(a / b)) * abs(b);
}

float2 mod(float2 a, float b)
{
	return frac(abs(a / b)) * abs(b);
}

float mod(float a, float b)
{
	return frac(abs(a / b)) * abs(b);
}

float smoothMin(float d1, float d2, float k)
{
    float h = exp(-k * d1) + exp(-k * d2);
    return -log(h) / k;
}

float3 repeat(float3 pos, float3 span)
{
	return mod(pos, span) - span * 0.5;
}

float3 rotateX(float3 pos, float angle)
{
	float c = cos(angle);
	float s = sin(angle);
	return float3(pos.x, c * pos.y + s * pos.z, -s * pos.y + c * pos.z);
}

float3 rotateY(float3 pos, float angle)
{
	float c = cos(angle);
	float s = sin(angle);
	return float3(c * pos.x - s * pos.z, pos.y, s * pos.x + c * pos.z);
}

float rotateZ(float3 pos, float angle)
{
	float c = cos(angle);
	float s = sin(angle);
	return float3(c * pos.x + s * pos.y, -s * pos.x + c * pos.y, pos.z);
}

float3 rotate(float3 p, float angle, float3 axis)
{
    float3 a = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float r = 1.0 - c;
    float3x3 m = float3x3(
        a.x * a.x * r + c,
        a.y * a.x * r + a.z * s,
        a.z * a.x * r - a.y * s,
        a.x * a.y * r - a.z * s,
        a.y * a.y * r + c,
        a.z * a.y * r + a.x * s,
        a.x * a.z * r + a.y * s,
        a.y * a.z * r - a.x * s,
        a.z * a.z * r + c
    );
    return mul(m, p);
}

float3 twistY(float3 p, float power)
{
    float s = sin(power * p.y);
    float c = cos(power * p.y);
    float3x3 m = float3x3(
          c, 0.0,  -s,
        0.0, 1.0, 0.0,
          s, 0.0,   c
    );
    return mul(m, p);
}

float3 twistX(float3 p, float power)
{
    float s = sin(power * p.y);
    float c = cos(power * p.y);
    float3x3 m = float3x3(
        1.0, 0.0, 0.0,
        0.0,   c,   s,
        0.0,  -s,   c
    );
    return mul(m, p);
}

float3 twistZ(float3 p, float power)
{
    float s = sin(power * p.y);
    float c = cos(power * p.y);
    float3x3 m = float3x3(
          c,   s, 0.0,
         -s,   c, 0.0,
        0.0, 0.0, 1.0
    );
    return mul(m, p);
}
#endif