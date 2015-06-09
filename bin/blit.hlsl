Texture2D       SrcTextureA     : register( t0 );
SamplerState    PointSampler    : register( s0 );

struct VSInput
{
    float2 m_pos    : POSITION;
    float2 m_uv     : TEXCOORD0;
};

struct PSInput
{
    float4 m_pos    : SV_POSITION;
    float2 m_uv     : TEXCOORD0;
};

cbuffer MainCB : register( b0 )
{
    float2  ScreenSizeRcp;
    float2  TextureSizeRcp;
    float2  TexelBias;
    float   TexelScale;
    float   Exposure;
};

PSInput VSMain( uint vertexID : SV_VertexID )
{
    PSInput output;

    float x = ( vertexID >> 1 );
    float y = 1.0 - ( vertexID & 1 );

    output.m_pos    = float4( 2.0 * x - 1.0, -2.0 * y + 1.0, 0.0, 1.0 );
    output.m_uv     = float2( x, y );

    return output;
}

float3 PSMain( PSInput i ) : SV_Target
{
    float2 uv = ( i.m_pos * TexelScale + TexelBias ) * TextureSizeRcp;

    float3 img = SrcTextureA.SampleLevel( PointSampler, uv, 0.0f ) * Exposure;
    return img;
}