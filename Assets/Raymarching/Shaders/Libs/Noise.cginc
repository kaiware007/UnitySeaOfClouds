#ifndef noise_h 
#define noise_h 

float hash(float h) {
	return frac(sin(h) * 43758.5453123);
}
float hash(float2 n)
{
	return frac(sin(dot(n, float2(1.0, 113.0)))*43758.5453123);
}
float hash(float3 p)  // replace this by something better
{
	p = frac(p*0.3183099 + .1);
	p *= 17.0;
	return frac(p.x*p.y*p.z*(p.x + p.y + p.z));
}
float2 hash2(float n) {
	return frac(sin(float2(n, n + 1.0))*float2(2.1459123, 3.3490423));
}
float2 hash2(float2 n) {
	return frac(sin(float2(n.x*n.y, n.x + n.y))*float2(2.1459123, 3.3490423));
}
float3 hash3(float n) {
	return frac(sin(float3(n, n + 1.0, n + 2.0))*float3(3.5453123, 4.1459123, 1.3490423));
}
float3 hash3(float2 n) {
	return frac(sin(float3(n.x, n.y, n.x + 2.0)) * float3(3.5453123, 4.1459123, 1.3490423));
}
float3 hash3(float3 n) {
	return frac(sin(float3(n.x, n.y, n.z)) * float3(3.5453123, 4.1459123, 1.3490423));
}

float nrand(float2 co)
{
	return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
}

float3 nrand3(float2 co)
{
	float3 a = frac(cos(co.x*8.3e-3 + co.y)*float3(1.3e5, 4.7e5, 2.9e5));
	float3 b = frac(sin(co.x*0.3e-3 + co.y)*float3(8.1e5, 1.0e5, 0.1e5));
	float3 c = lerp(a, b, 0.5);
	return c;
}

float noise(float3 x) {
	float3 p = floor(x);
	float3 f = frac(x);
	f = f * f * (3.0 - 2.0 * f);

	float n = p.x + p.y * 157.0 + 113.0 * p.z;
	return lerp(
		lerp(lerp(hash(n + 0.0), hash(n + 1.0), f.x),
			lerp(hash(n + 157.0), hash(n + 158.0), f.x), f.y),
		lerp(lerp(hash(n + 113.0), hash(n + 114.0), f.x),
			lerp(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
}

float fbm(float3 p) {
	float f = 0.0;
	f = 0.5000 * noise(p);
	p *= 2.01;
	f += 0.2500 * noise(p);
	p *= 2.02;
	f += 0.1250 * noise(p);

	return f;
}
#endif	//noise_h 