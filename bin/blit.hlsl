Texture2D TextureA : register(t0);
Texture2D TextureB : register(t1);
SamplerState PointSampler : register(s0);

struct PSInput
{
	float4 m_pos : SV_POSITION;
};

cbuffer MainCB : register(b0)
{
	float2 ScreenSizeRcp;
	uint2 TextureSizeInBlocks;
	float2 TextureSizeRcp;
	float2 TexelBias;
	float TexelScale;
	float Exposure;
	uint BlitMode;
};

float Luminance(float3 x)
{
	float3 luminanceWeights = float3(0.299f, 0.587f, 0.114f);
	return dot(x, luminanceWeights);
}

PSInput VSMain(uint vertexID : SV_VertexID)
{
	PSInput output;

	float x = vertexID >> 1;
	float y = vertexID & 1;

	output.m_pos = float4(2.0f * x - 1.0f, 2.0f * y - 1.0f, 0.0f, 1.0f);

	return output;
}

float3 PSMain(PSInput i) : SV_Target
{
	float2 uv = (i.m_pos * TexelScale + TexelBias) * TextureSizeRcp;

	float3 a = TextureA.SampleLevel(PointSampler, uv, 0.0f) * Exposure;
	float3 b = TextureB.SampleLevel(PointSampler, uv, 0.0f) * Exposure;
	float3 delta = log(a + 1.0f) - log(b + 1.0f);
	float3 deltaSq = delta * delta * 16.0f;

	if (BlitMode == 0)
	{
		return a;
	}

	if (BlitMode == 1)
	{
		return b;
	}

	if (BlitMode == 2)
	{
		return deltaSq;
	}

	return Luminance(deltaSq);
}
