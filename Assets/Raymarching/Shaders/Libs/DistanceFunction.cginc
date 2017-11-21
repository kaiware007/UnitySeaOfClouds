#ifndef distancefunction_h
#define distancefunction_h

// Distance Function
float pseudo_knightyan(float3 pos)
{
	const float3 CSize = float3(0.63248, 0.78632, 0.775);
	float DEfactor = 1.0;
	for (int i = 0; i < 6; i++)
	{
		pos = 2.0 * clamp(pos, -CSize, CSize) - pos;
		float k = max(0.70968 / dot(pos, pos), 1.0);
		pos *= k;
		DEfactor *= k * 1.1;
	}
	float rxy = length(pos.xy);
	return max(rxy - 0.92784, abs(rxy * pos.z) / length(pos)) / DEfactor;
}

float pseudo_kleinian(float3 p)
{
	const float3 CSize = float3(0.92436, 0.90756, 0.92436);
	const float Size = 1.0;
	const float3 C = float3(0.0, 0.0, 0.0);
	float DEfactor = 1.;
	const float3 Offset = float3(0.0, 0.0, 0.0);
	float3 ap = p + 1.;
	for (int i = 0; i < 10; i++) {
		ap = p;
		p = 2.*clamp(p, -CSize, CSize) - p;
		float r2 = dot(p, p);
		float k = max(Size / r2, 1.);
		p *= k;
		DEfactor *= k;
		p += C;
	}
	float r = abs(0.5*abs(p.z - Offset.z) / DEfactor);
	return r;
}

float tglad_formula(float3 z0)
{
	z0 = mod(z0, 2.);

	float mr = 0.25, mxr = 1.0;
	float4 scale = float4(-3.12, -3.12, -3.12, 3.12), p0 = float4(0.0, 1.59, -1.0, 0.0);
	float4 z = float4(z0, 1.0);
	for (int n = 0; n < 3; n++) {
		z.xyz = clamp(z.xyz, -0.94, 0.94)*2.0 - z.xyz;
		z *= scale / clamp(dot(z.xyz, z.xyz), mr, mxr)*1.;
		z += p0;
	}
	float dS = (length(max(abs(z.xyz) - float3(1.2, 49.0, 1.4), 0.0)) - 0.06) / z.w;
	return dS;
}

#ifndef PI
#define PI 3.14159265359
#endif //PI
float kaleidoscopic_IFS(float3 z)
{
	const int FRACT_ITER = 20;
	float FRACT_SCALE = 1.8;
	float FRACT_OFFSET = 1.0;

	float c = 2.0;
	z.y = mod(z.y, c) - c / 2.0;
	z = rotateZ(z, PI / 2.0);
	float r;
	int n1 = 0;
	for (int n = 0; n < FRACT_ITER; n++) {
		float rotate = PI*0.5;
		z = rotateX(z, rotate);
		z = rotateY(z, rotate);
		z = rotateZ(z, rotate);

		z.xy = abs(z.xy);
		if (z.x + z.y < 0.0) z.xy = -z.yx; // fold 1
		if (z.x + z.z < 0.0) z.xz = -z.zx; // fold 2
		if (z.y + z.z < 0.0) z.zy = -z.yz; // fold 3
		z = z*FRACT_SCALE - FRACT_OFFSET*(FRACT_SCALE - 1.0);
	}
	return (length(z)) * pow(FRACT_SCALE, -float(FRACT_ITER));
}

float hartverdrahtet(float3 f)
{
	float3 cs = float3(.808, .808, 1.167);
	float fs = 1.;
	float3 fc = float3(0, 0, 0);
	float fu = 10.;
	float fd = .763;

	// scene selection
	int i = mod(_Time.x / 2.0, 9.0);
	if (i == 0) cs.y = .58;
	if (i == 1) cs.xy = float2(0.5, 0.5);
	if (i == 2) cs.xy = float2(0.5, 0.5);
	if (i == 3) fu = 1.01, cs.x = .9;
	if (i == 4) fu = 1.01, cs.x = .9;
	if (i == 6) cs = float3(.5, .5, 1.04);
	if (i == 5) fu = .9;
	if (i == 7) fd = .7, fs = 1.34, cs.xy = float2(0.5, 0.5);
	if (i == 8) fc.z = -.38;

	//cs += sin(time)*0.2;

	float v = 1.;
	for (int loop = 0; loop < 12; loop++) {
		f = 2.*clamp(f, -cs, cs) - f;
		float c = max(fs / dot(f, f), 1.);
		f *= c;
		v *= c;
		f += fc;
	}
	float z = length(f.xy) - fu;
	return fd*max(z, abs(length(f.xy)*f.z) / sqrt(dot(f, f))) / abs(v);
}

// カイワレ距離関数
float DistanceFuncKaiware(float3 pos, float3 kpos, float3 scale, float3 axis, float angle)
{
	// 座標
	float3 p = pos - kpos;

	// 回転
	p = rotate(p, angle, axis);

	// スケール
	p = p / scale;

	// 頭部
	float d1 = roundBox(p, float3(1, 0.8, 1), 0.1);

	// くちばし
	float d2_0 = roundBox(p - float3(0, -0.2, 0.7), float3(0.8, 0.25, 0.4), 0.1);
	//float d2_0 = box(p - float3(0, -0.2, 0.7), float3(0.8, 0.25, 0.4));
	float d2_1 = box(p - float3(0, -0.0, 0.7), float3(1.1, 0.35, 1.1));	// 上半分
	float d2_2 = box(p - float3(0, -0.4, 0.7), float3(1.1, 0.35, 1.1));	// 下半分
	float d2_3 = roundBox(p - float3(0, -0.2, 0.7), float3(0.75, 0.1, 0.35), 0.1);	// 溝

	float d2_top = max(d2_0, d2_1);
	float d2_bottom = max(d2_0, d2_2);
	float d2 = min(min(d2_top, d2_bottom), d2_3);

	// 葉っぱの茎
	float d3_0 = Capsule(p, float3(0, 0.5, 0), float3(0, 1, 0), 0.05);
	// 葉っぱ
	float d3_1 = ellipsoid(p - float3(0.2, 1, 0), float3(0.2, 0.025, 0.1));
	float d3_2 = ellipsoid(p - float3(-0.2, 1, 0), float3(0.2, 0.025, 0.1));
	float d3 = min(d3_0, min(d3_1, d3_2));

	// 目
	float d4_0 = Capsule(p, float3(0.2, 0.25, 0.6), float3(0.4, 0.2, 0.6), 0.025);
	float d4_1 = Capsule(p, float3(-0.2, 0.25, 0.6), float3(-0.4, 0.2, 0.6), 0.025);
	float d4 = min(d4_0, d4_1);

	// 合成
	float sum = max(min(min(d1, d2), d3), -d4);

	sum *= scale;

	return sum;
}
#endif	// distancefunction_h 
