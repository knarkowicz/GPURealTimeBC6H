Texture2D       SrcTexture      : register( t0 );
SamplerState    PointSampler    : register( s0 );

struct PSInput
{
    float4 m_pos : SV_POSITION;
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

    float x = vertexID >> 1;
    float y = vertexID & 1;

    output.m_pos = float4( 2.0f * x - 1.0f, 2.0f * y - 1.0f, 0.0f, 1.0f );

    return output;
}

int Quantize( float x )
{
    return ( f32tof16( x ) << 10 ) / ( 0x7bff + 1 );
}

int3 Quantize( float3 x )
{
    return ( f32tof16( x ) << 10 ) / ( 0x7bff + 1 );
}

float Luminance( float3 color )
{
    //return dot( color, float3( 1.0f, 1.0f, 1.0f ) );
    return dot( color, float3( 0.299f, 0.587f, 0.114f ) );
}

int ComputeIndex( int texelLum, int endPoint0Lum, int endPoint1Lum )
{
    float r = ( texelLum - endPoint0Lum ) / float( endPoint1Lum - endPoint0Lum );
    return (int) clamp( r * 14.933333f + 0.033333f + 0.5f, 0.0f, 15.0f );
}

uint4 PSMain( PSInput i ) : SV_Target
{
    // gather texels for current 4x4 block
    // 0 1 2 3
    // 4 5 6 7
    // 8 9 10 11
    // 12 13 14 15
    float2 uv       = i.m_pos.xy * TextureSizeRcp * 4.0f - TextureSizeRcp;
    float2 block0UV = uv;
    float2 block1UV = uv + float2( 2.0f * TextureSizeRcp.x, 0.0f );
    float2 block2UV = uv + float2( 0.0f, 2.0f * TextureSizeRcp.y );
    float2 block3UV = uv + float2( 2.0f * TextureSizeRcp.x, 2.0f * TextureSizeRcp.y );
    float4 block0X  = SrcTexture.GatherRed( PointSampler,   block0UV );
    float4 block0Y  = SrcTexture.GatherGreen( PointSampler, block0UV );
    float4 block0Z  = SrcTexture.GatherBlue( PointSampler,  block0UV );
    float4 block1X  = SrcTexture.GatherRed( PointSampler,   block1UV );
    float4 block1Y  = SrcTexture.GatherGreen( PointSampler, block1UV );
    float4 block1Z  = SrcTexture.GatherBlue( PointSampler,  block1UV );
    float4 block2X = SrcTexture.GatherRed( PointSampler,    block2UV );
    float4 block2Y = SrcTexture.GatherGreen( PointSampler,  block2UV );
    float4 block2Z = SrcTexture.GatherBlue( PointSampler,   block2UV );
    float4 block3X = SrcTexture.GatherRed( PointSampler,    block3UV );
    float4 block3Y = SrcTexture.GatherGreen( PointSampler,  block3UV );
    float4 block3Z = SrcTexture.GatherBlue( PointSampler,   block3UV );

    float3 texels[ 16 ];
    texels[ 0 ]     = float3( block0X.w, block0Y.w, block0Z.w );
    texels[ 1 ]     = float3( block0X.z, block0Y.z, block0Z.z );
    texels[ 2 ]     = float3( block1X.w, block1Y.w, block1Z.w );
    texels[ 3 ]     = float3( block1X.z, block1Y.z, block1Z.z );
    texels[ 4 ]     = float3( block0X.x, block0Y.x, block0Z.x );
    texels[ 5 ]     = float3( block0X.y, block0Y.y, block0Z.y );
    texels[ 6 ]     = float3( block1X.x, block1Y.x, block1Z.x );
    texels[ 7 ]     = float3( block1X.y, block1Y.y, block1Z.y );
    texels[ 8 ]     = float3( block2X.w, block2Y.w, block2Z.w );
    texels[ 9 ]     = float3( block2X.z, block2Y.z, block2Z.z );
    texels[ 10 ]    = float3( block3X.w, block3Y.w, block3Z.w );
    texels[ 11 ]    = float3( block3X.z, block3Y.z, block3Z.z );
    texels[ 12 ]    = float3( block2X.x, block2Y.x, block2Z.x );
    texels[ 13 ]    = float3( block2X.y, block2Y.y, block2Z.y );
    texels[ 14 ]    = float3( block3X.x, block3Y.x, block3Z.x );
    texels[ 15 ]    = float3( block3X.y, block3Y.y, block3Z.y );


    // compute endpoints by picking texel with lowest and highest luminance
    float3 blockMin     = texels[ 0 ];
    float3 blockMax     = texels[ 0 ];
    float blockMinLum   = Luminance( blockMin );
    float blockMaxLum   = Luminance( blockMax );
    for ( uint i = 1; i < 16; ++i )
    {
        float texelLum  = Luminance( texels[ i ] );

        blockMin = texelLum < blockMinLum ? texels[ i ] : blockMin;
        blockMax = texelLum > blockMaxLum ? texels[ i ] : blockMax;

        blockMinLum = min( blockMinLum, texelLum );
        blockMaxLum = max( blockMaxLum, texelLum );
    }

    int endPoint0Lum    = Quantize( blockMinLum );
    int endPoint1Lum    = Quantize( blockMaxLum );
    int3 endpoint0      = Quantize( blockMin );
    int3 endpoint1      = Quantize( blockMax );

    uint indices[ 16 ] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };


    // check if endpoint swap is required
    int texelLum = Quantize( Luminance( texels[ 0 ] ) );
    indices[ 0 ] = ComputeIndex( texelLum, endPoint0Lum, endPoint1Lum );
    if ( indices[ 0 ] > 7 )
    {
        uint tmp = endPoint0Lum;
        endPoint0Lum = endPoint1Lum;
        endPoint1Lum = tmp;

        uint3 tmp2 = endpoint0;
        endpoint0 = endpoint1;
        endpoint1 = tmp2;

        indices[ 0 ] = 15 - indices[ 0 ];
    }


    // compute indices
    for ( uint j = 1; j < 16; ++j )
    {
        int texelLum = Quantize( Luminance( texels[ j ] ) );
        indices[ j ] = ComputeIndex( texelLum, endPoint0Lum, endPoint1Lum );
    }


    // encode block for mode 11
    uint4 block = uint4( 0, 0, 0, 0 );
    block.x |= 0x03;
    // endpoints
    block.x |= endpoint0.x << 5;
    block.x |= endpoint0.y << 15;
    block.x |= endpoint0.z << 25;
    block.y |= endpoint0.z >> 7;
    block.y |= endpoint1.x << 3;
    block.y |= endpoint1.y << 13;
    block.y |= endpoint1.z << 23;
    block.z |= endpoint1.z >> 9;
    // indices
    block.z |= indices[ 0 ] << 1;
    block.z |= indices[ 1 ] << 4;
    block.z |= indices[ 2 ] << 8;
    block.z |= indices[ 3 ] << 12;
    block.z |= indices[ 4 ] << 16;
    block.z |= indices[ 5 ] << 20;
    block.z |= indices[ 6 ] << 24;
    block.z |= indices[ 7 ] << 28;
    block.w |= indices[ 8 ] << 0;
    block.w |= indices[ 9 ] << 4;
    block.w |= indices[ 10 ] << 8;
    block.w |= indices[ 11 ] << 12;
    block.w |= indices[ 12 ] << 16;
    block.w |= indices[ 13 ] << 20;
    block.w |= indices[ 14 ] << 24;
    block.w |= indices[ 15 ] << 28;

    return block;
}