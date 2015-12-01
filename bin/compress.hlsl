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

static const float HALF_MAX = 65504.0f;
static const uint PATTERN_NUM = 32;

float ErrorMetric( float3 a, float3 b )
{
    float3 err = log2( a + 1.0f ) - log2( b + 1.0f );
    err = err * err;
    return err.x + err.y + err.z;
}

uint PatternFixupID( uint i )
{
    uint ret = 15;
    ret += ( ( 3441033216 >> i ) & 0x1 ) * ( 2 - 15 );
    ret += ( ( 845414400  >> i ) & 0x1 ) * ( 8 - 15 );
    return ret;
}

uint Pattern( uint p, uint i )
{
    uint enc = 0;
    enc = p == 0 ? 52428 : enc;
    enc = p == 1 ? 34952 : enc;
    enc = p == 2 ? 61166 : enc;
    enc = p == 3 ? 60616 : enc;
    enc = p == 4 ? 51328 : enc;
    enc = p == 5 ? 65260 : enc;
    enc = p == 6 ? 65224 : enc;
    enc = p == 7 ? 60544 : enc;
    enc = p == 8 ? 51200 : enc;
    enc = p == 9 ? 65516 : enc;
    enc = p == 10 ? 65152 : enc;
    enc = p == 11 ? 59392 : enc;
    enc = p == 12 ? 65512 : enc;
    enc = p == 13 ? 65280 : enc;
    enc = p == 14 ? 65520 : enc;
    enc = p == 15 ? 61440 : enc;
    enc = p == 16 ? 63248 : enc;
    enc = p == 17 ? 142 : enc;
    enc = p == 18 ? 28928 : enc;
    enc = p == 19 ? 2254 : enc;
    enc = p == 20 ? 140 : enc;
    enc = p == 21 ? 29456 : enc;
    enc = p == 22 ? 12544 : enc;
    enc = p == 23 ? 36046 : enc;
    enc = p == 24 ? 2188 : enc;
    enc = p == 25 ? 12560 : enc;
    enc = p == 26 ? 26214 : enc;
    enc = p == 27 ? 13932 : enc;
    enc = p == 28 ? 6120 : enc;
    enc = p == 29 ? 4080 : enc;
    enc = p == 30 ? 29070 : enc;
    enc = p == 31 ? 14748 : enc;

    uint ret = ( enc >> i ) & 0x1;
    return ret;
}

float Quantize( float x, uint prec )
{
    return ( f32tof16( x ) << prec ) / ( 0x7bff + 1.0f );
}

float3 Quantize( float3 x, uint prec )
{
    return ( f32tof16( x ) << prec ) / ( 0x7bff + 1.0f );
}

float3 Unquantize( int3 x, int prec )
{
    int3 unq = ( ( x << 16 ) + 0x8000 ) >> prec;
    return unq;
}

int3 FinishUnquantize( int3 comp )
{
    comp = ( comp * 31 ) >> 6;
    return comp;
}

void Swap( inout float3 a, inout float3 b )
{
    float3 tmp = a;
    a = b;
    b = tmp;
}

void Swap( inout float a, inout float b )
{
    float tmp = a;
    a = b;
    b = tmp;
}

uint ComputeIndex3( float texelPos, float endPoint0Pos, float endPoint1Pos )
{
    float r = ( texelPos - endPoint0Pos ) / ( endPoint1Pos - endPoint0Pos );
    return (uint) clamp( r * 6.98182f + 0.00909f + 0.5f, 0.0f, 7.0f );
}

uint ComputeIndex4( float texelPos, float endPoint0Pos, float endPoint1Pos )
{
    float r = ( texelPos - endPoint0Pos ) / ( endPoint1Pos - endPoint0Pos );
    return (uint) clamp( r * 14.93333f + 0.03333f + 0.5f, 0.0f, 15.0f );
}

void SignExtend( inout int3 v, uint mask, uint signFlag )
{
    if ( v.x < 0 ) v.x = ( v.x & mask ) | signFlag;
    if ( v.y < 0 ) v.y = ( v.y & mask ) | signFlag;
    if ( v.z < 0 ) v.z = ( v.z & mask ) | signFlag;
}

void EncodeP1( inout uint4 block, inout float blockRMSE, float3 texels[ 16 ] )
{
    // compute endpoints (min/max RGB bbox)
    float3 blockMin = texels[ 0 ];
    float3 blockMax = texels[ 0 ];
    [unroll]
    for ( uint i = 1; i < 16; ++i )
    {
        blockMin = min( blockMin, texels[ i ] );
        blockMax = max( blockMax, texels[ i ] );
    }


    // refine endpoints in log2 RGB space
    float3 refinedBlockMin = blockMax;
    float3 refinedBlockMax = blockMin;
    [unroll]
    for ( i = 0; i < 16; ++i )
    {
        refinedBlockMin = min( refinedBlockMin, texels[ i ] == blockMin ? refinedBlockMin : texels[ i ] );
        refinedBlockMax = max( refinedBlockMax, texels[ i ] == blockMax ? refinedBlockMax : texels[ i ] );
    }

    float3 logBlockMax          = log2( blockMax + 1.0f );
    float3 logBlockMin          = log2( blockMin + 1.0f );
    float3 logRefinedBlockMax   = log2( refinedBlockMax + 1.0f );
    float3 logRefinedBlockMin   = log2( refinedBlockMin + 1.0f );
    float3 logBlockMaxExt       = ( logBlockMax - logBlockMin ) * ( 1.0f / 32.0f );
    logBlockMin += min( logRefinedBlockMin - logBlockMin, logBlockMaxExt );
    logBlockMax -= min( logBlockMax - logRefinedBlockMax, logBlockMaxExt );
    blockMin = exp2( logBlockMin ) - 1.0f;
    blockMax = exp2( logBlockMax ) - 1.0f;
    
    float3 blockDir = blockMax - blockMin;
    blockDir = blockDir / ( blockDir.x + blockDir.y + blockDir.z );

    float3 endpoint0    = Quantize( blockMin, 10 );
    float3 endpoint1    = Quantize( blockMax, 10 );
    float endPoint0Pos  = f32tof16( dot( blockMin, blockDir ) );
    float endPoint1Pos  = f32tof16( dot( blockMax, blockDir ) );

    uint indices[ 16 ] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };


    // check if endpoint swap is required
    float texelPos = f32tof16( dot( texels[ 0 ], blockDir ) );
    indices[ 0 ] = ComputeIndex4( texelPos, endPoint0Pos, endPoint1Pos );
    [flatten]
    if ( indices[ 0 ] > 7 )
    {
        Swap( endPoint0Pos, endPoint1Pos );
        Swap( endpoint0, endpoint1 );
    }

    // compute indices
    [unroll]
    for ( i = 0; i < 16; ++i )
    {
        float texelPos = f32tof16( dot( texels[ i ], blockDir ) );
        indices[ i ] = ComputeIndex4( texelPos, endPoint0Pos, endPoint1Pos );
    }

    // compute RMSE
    float rmse = 0.0f;
    for ( i = 0; i < 16; ++i )
    {
        int3 endpoint0Unq = Unquantize( endpoint0, 10 );
        int3 endpoint1Unq = Unquantize( endpoint1, 10 );

        uint index = indices[ i ];
        float weight = floor( ( index * 64.0f ) / 15.0f + 0.5f );
        float3 texelUnc = texelUnc = f16tof32( FinishUnquantize( floor( endpoint0Unq * ( 64.0f - weight ) + endpoint1Unq * weight + 32.0f ) / 64.0f ) );

        rmse += ErrorMetric( texels[ i ], texelUnc );
    }


    // encode block for mode 11
    blockRMSE = rmse;
    block.x = 0x03;

    // endpoints
    block.x |= (uint) endpoint0.x << 5;
    block.x |= (uint) endpoint0.y << 15;
    block.x |= (uint) endpoint0.z << 25;
    block.y |= (uint) endpoint0.z >> 7;
    block.y |= (uint) endpoint1.x << 3;
    block.y |= (uint) endpoint1.y << 13;
    block.y |= (uint) endpoint1.z << 23;
    block.z |= (uint) endpoint1.z >> 9;

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
}

void EncodeP2Pattern( inout uint4 block, inout float blockRMSE, int pattern, float3 texels[ 16 ] )
{
    float3 p0BlockMin = float3( HALF_MAX, HALF_MAX, HALF_MAX );
    float3 p0BlockMax = float3( 0.0f, 0.0f, 0.0f );
    float3 p1BlockMin = float3( HALF_MAX, HALF_MAX, HALF_MAX );
    float3 p1BlockMax = float3( 0.0f, 0.0f, 0.0f );
    
    for ( uint i = 0; i < 16; ++i )
    {
        uint paletteID = Pattern( pattern, i );
        if ( paletteID == 0 )
        {
            p0BlockMin = min( p0BlockMin, texels[ i ] );
            p0BlockMax = max( p0BlockMax, texels[ i ] );
        }
        else
        {
            p1BlockMin = min( p1BlockMin, texels[ i ] );
            p1BlockMax = max( p1BlockMax, texels[ i ] );
        }
    }
    
    float3 p0BlockDir = p0BlockMax - p0BlockMin;
    float3 p1BlockDir = p1BlockMax - p1BlockMin;
    p0BlockDir = p0BlockDir / ( p0BlockDir.x + p0BlockDir.y + p0BlockDir.z );
    p1BlockDir = p1BlockDir / ( p1BlockDir.x + p1BlockDir.y + p1BlockDir.z );


    float p0Endpoint0Pos = f32tof16( dot( p0BlockMin, p0BlockDir ) );
    float p0Endpoint1Pos = f32tof16( dot( p0BlockMax, p0BlockDir ) );
    float p1Endpoint0Pos = f32tof16( dot( p1BlockMin, p1BlockDir ) );
    float p1Endpoint1Pos = f32tof16( dot( p1BlockMax, p1BlockDir ) );

    uint indices[ 16 ] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    uint fixupID = PatternFixupID( pattern );
    float p0TexelPos = f32tof16( dot( texels[ 0 ], p0BlockDir ) );
    float p1TexelPos = f32tof16( dot( texels[ fixupID ], p1BlockDir ) );
    int p0Weight = ComputeIndex3( p0TexelPos, p0Endpoint0Pos, p0Endpoint1Pos );
    int p1Weight = ComputeIndex3( p1TexelPos, p1Endpoint0Pos, p1Endpoint1Pos );
    if ( p0Weight > 3 )
    {
        Swap( p0Endpoint0Pos, p0Endpoint1Pos );
        Swap( p0BlockMin, p0BlockMax );
    }
    if ( p1Weight > 3 )
    {
        Swap( p1Endpoint0Pos, p1Endpoint1Pos );
        Swap( p1BlockMin, p1BlockMax );
    }

    for ( i = 0; i < 16; ++i )
    {
        float p0TexelPos = f32tof16( dot( texels[ i ], p0BlockDir ) );
        float p1TexelPos = f32tof16( dot( texels[ i ], p1BlockDir ) );
        int p0Weight = ComputeIndex3( p0TexelPos, p0Endpoint0Pos, p0Endpoint1Pos );
        int p1Weight = ComputeIndex3( p1TexelPos, p1Endpoint0Pos, p1Endpoint1Pos );

        uint paletteID = Pattern( pattern, i );
        indices[ i ] = paletteID == 0 ? p0Weight : p1Weight;
    }


    int3 endpoint0 = Quantize( p0BlockMin, 6 );
    int3 endpoint1 = Quantize( p0BlockMax, 6 );
    int3 endpoint2 = Quantize( p1BlockMin, 6 );
    int3 endpoint3 = Quantize( p1BlockMax, 6 );

    int3 endpoint760 = Quantize( p0BlockMin, 7 );
    int3 endpoint761 = Quantize( p0BlockMax, 7 );
    int3 endpoint762 = Quantize( p1BlockMin, 7 );
    int3 endpoint763 = Quantize( p1BlockMax, 7 );

    int3 endpoint950 = Quantize( p0BlockMin, 9 );
    int3 endpoint951 = Quantize( p0BlockMax, 9 );
    int3 endpoint952 = Quantize( p1BlockMin, 9 );
    int3 endpoint953 = Quantize( p1BlockMax, 9 );

    endpoint761 = endpoint761 - endpoint760;
    endpoint762 = endpoint762 - endpoint760;
    endpoint763 = endpoint763 - endpoint760;

    endpoint951 = endpoint951 - endpoint950;
    endpoint952 = endpoint952 - endpoint950;
    endpoint953 = endpoint953 - endpoint950;

    int maxVal76 = 0x1F;
    endpoint761 = clamp( endpoint761, -maxVal76, maxVal76 );
    endpoint762 = clamp( endpoint762, -maxVal76, maxVal76 );
    endpoint763 = clamp( endpoint763, -maxVal76, maxVal76 );

    int maxVal95 = 0xF;
    endpoint951 = clamp( endpoint951, -maxVal95, maxVal95 );
    endpoint952 = clamp( endpoint952, -maxVal95, maxVal95 );
    endpoint953 = clamp( endpoint953, -maxVal95, maxVal95 );

    float rmse66 = 0.0f;
    float rmse76 = 0.0f;
    float rmse95 = 0.0f;
    for ( i = 0; i < 16; ++i )
    {
        uint paletteID = Pattern( pattern, i );

        int3 endpoint660Unq = Unquantize( paletteID == 0 ? endpoint0 : endpoint2, 6 );
        int3 endpoint661Unq = Unquantize( paletteID == 0 ? endpoint1 : endpoint3, 6 );
        int3 endpoint760Unq = Unquantize( paletteID == 0 ? endpoint760 : endpoint760 + endpoint762, 7 );
        int3 endpoint761Unq = Unquantize( paletteID == 0 ? endpoint760 + endpoint761 : endpoint760 + endpoint763, 7 );
        int3 endpoint950Unq = Unquantize( paletteID == 0 ? endpoint950 : endpoint950 + endpoint952, 9 );
        int3 endpoint951Unq = Unquantize( paletteID == 0 ? endpoint950 + endpoint951 : endpoint950 + endpoint953, 9 );

        uint index = indices[ i ];
        float weight = floor( ( index * 64.0f ) / 7.0f + 0.5f );
        float3 texelUnc66 = f16tof32( FinishUnquantize( floor( endpoint660Unq * ( 64.0f - weight ) + endpoint661Unq * weight + 32.0f ) / 64.0f ) );
        float3 texelUnc76 = f16tof32( FinishUnquantize( floor( endpoint760Unq * ( 64.0f - weight ) + endpoint761Unq * weight + 32.0f ) / 64.0f ) );
        float3 texelUnc95 = f16tof32( FinishUnquantize( floor( endpoint950Unq * ( 64.0f - weight ) + endpoint951Unq * weight + 32.0f ) / 64.0f ) );

        rmse66 += ErrorMetric( texels[ i ], texelUnc66 );
        rmse76 += ErrorMetric( texels[ i ], texelUnc76 );
        rmse95 += ErrorMetric( texels[ i ], texelUnc95 );
    }

    SignExtend( endpoint761, 0x1F, 0x20 );
    SignExtend( endpoint762, 0x1F, 0x20 );
    SignExtend( endpoint763, 0x1F, 0x20 );

    SignExtend( endpoint951, 0xF, 0x10 );
    SignExtend( endpoint952, 0xF, 0x10 );
    SignExtend( endpoint953, 0xF, 0x10 );

    // encode block
    float p2RMSE = min( min( rmse66, rmse95 ), rmse76 );
    p2RMSE = min( rmse76, rmse95 );
    //p2RMSE = rmse66;
    if ( p2RMSE < blockRMSE )
    {
        blockRMSE   = p2RMSE;
        block       = uint4( 0, 0, 0, 0 );

        if ( p2RMSE == rmse66 )
        {
            // 6.6
            block.x = 0x1E;
            block.x |= (uint) endpoint0.x << 5;
            block.x |= ( (uint) endpoint3.y & 0x10 ) << 7;
            block.x |= ( (uint) endpoint3.z & 0x3  ) << 12;
            block.x |= ( (uint) endpoint2.z & 0x10 ) << 10;
            block.x |= (uint) endpoint0.y << 15;
            block.x |= ( (uint) endpoint2.y & 0x20 ) << 16;
            block.x |= ( (uint) endpoint2.z & 0x20 ) << 17;
            block.x |= ( (uint) endpoint3.z & 0x4  ) << 21;
            block.x |= ( (uint) endpoint2.y & 0x10 ) << 20;
            block.x |= (uint) endpoint0.z << 25;
            block.x |= ( (uint) endpoint3.y & 0x20 ) << 26;
            block.y |= ( (uint) endpoint3.z & 0x8  ) >> 3;
            block.y |= ( (uint) endpoint3.z & 0x20 ) >> 4;
            block.y |= ( (uint) endpoint3.z & 0x10 ) >> 2;
            block.y |= (uint) endpoint1.x << 3;
            block.y |= ( (uint) endpoint2.y & 0xF ) << 9;
            block.y |= (uint) endpoint1.y << 13;
            block.y |= ( (uint) endpoint3.y & 0xF ) << 19;
            block.y |= (uint) endpoint1.z << 23;
            block.y |= ( (uint) endpoint2.z & 0x7 ) << 29;
            block.z |= ( (uint) endpoint2.z & 0x8 ) >> 3;
            block.z |= (uint) endpoint2.x << 1;
            block.z |= (uint) endpoint3.x << 7;
        }
        else if ( p2RMSE == rmse76 )
        {
            // 7.6
            block.x = 0x1;
            block.x |= ( (uint) endpoint762.y & 0x20 ) >> 3;
            block.x |= ( (uint) endpoint763.y & 0x10 ) >> 1;
            block.x |= ( (uint) endpoint763.y & 0x20 ) >> 1;
            block.x |= (uint) endpoint760.x << 5;
            block.x |= ( (uint) endpoint763.z & 0x01 ) << 12;
            block.x |= ( (uint) endpoint763.z & 0x02 ) << 12;
            block.x |= ( (uint) endpoint762.z & 0x10 ) << 10;
            block.x |= (uint) endpoint760.y << 15;
            block.x |= ( (uint) endpoint762.z & 0x20 ) << 17;
            block.x |= ( (uint) endpoint763.z & 0x04 ) << 21;
            block.x |= ( (uint) endpoint762.y & 0x10 ) << 20;
            block.x |= (uint) endpoint760.z << 25;
            block.y |= ( (uint) endpoint763.z & 0x08 ) >> 3;
            block.y |= ( (uint) endpoint763.z & 0x20 ) >> 4;
            block.y |= ( (uint) endpoint763.z & 0x10 ) >> 2;
            block.y |= (uint) endpoint761.x << 3;
            block.y |= ( (uint) endpoint762.y & 0x0F ) << 9;
            block.y |= (uint) endpoint761.y << 13;
            block.y |= ( (uint) endpoint763.y & 0x0F ) << 19;
            block.y |= (uint) endpoint761.z << 23;
            block.y |= ( (uint) endpoint762.z & 0x07 ) << 29;
            block.z |= ( (uint) endpoint762.z & 0x08 ) >> 3;
            block.z |= (uint) endpoint762.x << 1;
            block.z |= (uint) endpoint763.x << 7;
        }
        else if ( p2RMSE == rmse95 )
        {
            // 9.5
            block.x = 0xE;
            block.x |= (uint) endpoint950.x << 5;
            block.x |= ( (uint) endpoint952.z & 0x10 ) << 10;
            block.x |= (uint) endpoint950.y << 15;
            block.x |= ( (uint) endpoint952.y & 0x10 ) << 20;
            block.x |= (uint) endpoint950.z << 25;
            block.y |= (uint) endpoint950.z >> 7;
            block.y |= ( (uint) endpoint953.z & 0x10 ) >> 2;
            block.y |= (uint) endpoint951.x << 3;
            block.y |= ( (uint) endpoint953.y & 0x10 ) << 4;
            block.y |= ( (uint) endpoint952.y & 0x0F ) << 9;
            block.y |= (uint) endpoint951.y << 13;
            block.y |= ( (uint) endpoint953.z & 0x01 ) << 18;
            block.y |= ( (uint) endpoint953.y & 0x0F ) << 19;
            block.y |= (uint) endpoint951.z << 23;
            block.y |= ( (uint) endpoint953.z & 0x02 ) << 27;
            block.y |= (uint) endpoint952.z << 29;
            block.z |= ( (uint) endpoint952.z & 0x08 ) >> 3;
            block.z |= (uint) endpoint952.x << 1;
            block.z |= ( (uint) endpoint953.z & 0x04 ) << 4;
            block.z |= (uint) endpoint953.x << 7;
            block.z |= ( (uint) endpoint953.z & 0x08 ) << 9;
        }

        block.z |= pattern << 13;
        uint fixupID = PatternFixupID( pattern );
        if ( fixupID == 15 )
        {
            block.z |= indices[ 0 ] << 18;
            block.z |= indices[ 1 ] << 20;
            block.z |= indices[ 2 ] << 23;
            block.z |= indices[ 3 ] << 26;
            block.z |= indices[ 4 ] << 29;
            block.w |= indices[ 5 ] << 0;
            block.w |= indices[ 6 ] << 3;
            block.w |= indices[ 7 ] << 6;
            block.w |= indices[ 8 ] << 9;
            block.w |= indices[ 9 ] << 12;
            block.w |= indices[ 10 ] << 15;
            block.w |= indices[ 11 ] << 18;
            block.w |= indices[ 12 ] << 21;
            block.w |= indices[ 13 ] << 24;
            block.w |= indices[ 14 ] << 27;
            block.w |= indices[ 15 ] << 30;
        }
        else if ( fixupID == 2 )
        {
            block.z |= indices[ 0 ] << 18;
            block.z |= indices[ 1 ] << 20;
            block.z |= indices[ 2 ] << 23;
            block.z |= indices[ 3 ] << 25;
            block.z |= indices[ 4 ] << 28;
            block.z |= indices[ 5 ] << 31;
            block.w |= indices[ 5 ] >> 1;
            block.w |= indices[ 6 ] << 2;
            block.w |= indices[ 7 ] << 5;
            block.w |= indices[ 8 ] << 8;
            block.w |= indices[ 9 ] << 11;
            block.w |= indices[ 10 ] << 14;
            block.w |= indices[ 11 ] << 17;
            block.w |= indices[ 12 ] << 20;
            block.w |= indices[ 13 ] << 23;
            block.w |= indices[ 14 ] << 26;
            block.w |= indices[ 15 ] << 29;
        }
        else if ( fixupID == 8 )
        {
            block.z |= indices[ 0 ] << 18;
            block.z |= indices[ 1 ] << 20;
            block.z |= indices[ 2 ] << 23;
            block.z |= indices[ 3 ] << 26;
            block.z |= indices[ 4 ] << 29;
            block.w |= indices[ 5 ] << 0;
            block.w |= indices[ 6 ] << 3;
            block.w |= indices[ 7 ] << 6;
            block.w |= indices[ 8 ] << 9;
            block.w |= indices[ 9 ] << 11;
            block.w |= indices[ 10 ] << 14;
            block.w |= indices[ 11 ] << 17;
            block.w |= indices[ 12 ] << 20;
            block.w |= indices[ 13 ] << 23;
            block.w |= indices[ 14 ] << 26;
            block.w |= indices[ 15 ] << 29;
        }
    }
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

    uint4 block     = uint4( 0, 0, 0, 0 );
    float blockRMSE = 0.0f;

    EncodeP1( block, blockRMSE, texels );
#ifdef QUALITY
    for ( uint i = 0; i < 32; ++i )
    {
        EncodeP2Pattern( block, blockRMSE, i, texels );
    }
#endif

    return block;
}