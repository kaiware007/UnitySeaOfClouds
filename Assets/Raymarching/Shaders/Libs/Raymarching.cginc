#ifndef raymarching_h
#define raymarching_h

// Raymarchingの定義（後半）

// レイがヒットしたとみなす距離
#ifndef RAY_HIT_DISTANCE
#define RAY_HIT_DISTANCE 0.000001
#endif

// CUSTOM_DISTANCE_FUNCTIONが他で未定義の場合に__DefaultDistanceFuncが定義される
#if !defined(CUSTOM_DISTANCE_FUNCTION)
#define CUSTOM_DISTANCE_FUNCTION(p) __DefaultDistanceFunc(p)
// デフォルトの距離関数
// CUSTOM_DISTANCE_FUNCTIONが未定義の場合に呼ばれる
float __DefaultDistanceFunc(float3 pos)
{
	return box(repeat(pos, float3(5,5,5)), float3(1,1,1));
}
#endif //CUSTOM_DISTANCE_FUNCTION

#if !defined(CUSTOM_TRANSFORM)
#define CUSTOM_TRANSFORM(p, r, s) InitTransform(p, r, s)
#endif //CUSTOM_TRANSFORM

#if !defined(CUSTOM_GBUFFER_OUTPUT)
#define CUSTOM_GBUFFER_OUTPUT(diff, spec, norm, emit , dep) InitGBuffer(diff, spec, norm, emit, dep)
#endif // CUSTOM_GBUFFER_OUTPUT


// 法線取得
float3 GetNormal(float3 pos)
{
	const float delta = 0.001;
	return normalize(float3(
		CUSTOM_DISTANCE_FUNCTION(pos + float3(delta, 0, 0)) - CUSTOM_DISTANCE_FUNCTION(pos + float3(-delta, 0, 0)),
		CUSTOM_DISTANCE_FUNCTION(pos + float3(0, delta, 0)) - CUSTOM_DISTANCE_FUNCTION(pos + float3(0, -delta, 0)),
		CUSTOM_DISTANCE_FUNCTION(pos + float3(0, 0, delta)) - CUSTOM_DISTANCE_FUNCTION(pos + float3(0, 0, -delta))
		)) * 0.5 + 0.5;
}

raymarchOut raymarch(float2 screenPos, transform tr, const int trial_num)
{
	raymarchOut o;

	float3 rayDir = GetRayDir(screenPos);
	float3 camPos = GetCameraPosition();
	float maxDistance = GetCameraMaxDistance();

	o.length = 0;
	o.pos = camPos + _ProjectionParams.y * rayDir;

	for (o.count = 0; o.count < trial_num; ++o.count) {
		o.distance = CUSTOM_DISTANCE_FUNCTION(Localize(o.pos, tr));
		o.length += o.distance;
		o.pos += rayDir * o.distance;
		if (o.distance < RAY_HIT_DISTANCE || o.length > maxDistance)
			break;
	}

	return o;
}

v2f raymarch_vert(appdata v)
{
	v2f o;
	o.vertex = UnityObjectToClipPos(v.vertex);
	// ラスタライズしてフラグメントシェーダで各ピクセルの座標として使う
	o.screenPos = o.vertex;
	return o;
}

gbuffer raymarch_frag(v2f i)
{
	i.screenPos.xy /= i.screenPos.w;

	raymarchOut rayOut;
	transform tr;
	tr = CUSTOM_TRANSFORM(0, 0, 1);

	rayOut = raymarch(i.screenPos.xy, tr, 100);
	clip(-rayOut.distance + RAY_HIT_DISTANCE);

	float depth = GetDepth(rayOut.pos);
	float3 normal = GetNormal(Localize(rayOut.pos, tr));

	gbuffer gbOut;
	gbOut = CUSTOM_GBUFFER_OUTPUT(0.5, 0.5, normal, 0.5, depth);

	return gbOut;

}
#endif // raymarching_h