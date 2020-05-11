#pragma once

struct Vec2
{
	Vec2()
	{
	}

	Vec2(float x_, float y_)
		: x(x_)
		, y(y_)
	{
	}

	float x;
	float y;
};

struct Vec3
{
	float x;
	float y;
	float z;
};

uint32_t const MAX_QUERY_FRAME_NUM = 5;
uint32_t const COMPRESSION_MODE_NUM = 2;
uint32_t const BLIT_MODE_NUM = 4;

class CApp
{
public:
	CApp();
	~CApp();

	bool Init(HWND windowHandle);
	void Release();
	void Render();
	void OnKeyDown(WPARAM wParam);
	void OnLButtonDown(int mouseX, int mouseY);
	void OnLButtonUp(int mouseX, int mouseY);
	void OnMouseMove(int mouseX, int mouseY);
	void OnMouseWheel(int zDelta);
	void OnResize();

	ID3D11Device* GetDevice() { return m_device; }
	ID3D11DeviceContext* GetCtx() { return m_ctx; }


private:
	unsigned m_backbufferWidth = 1280;
	unsigned m_backbufferHeight = 720;

	ID3D11Device* m_device = nullptr;
	ID3D11DeviceContext* m_ctx = nullptr;
	IDXGISwapChain* m_swapChain = nullptr;
	ID3D11RenderTargetView* m_backBufferView = nullptr;
	ID3D11SamplerState* m_pointSampler = nullptr;
	ID3D11Buffer* m_constantBuffer = nullptr;

	ID3D11Query* m_disjointQueries[MAX_QUERY_FRAME_NUM];
	ID3D11Query* m_timeBeginQueries[MAX_QUERY_FRAME_NUM];
	ID3D11Query* m_timeEndQueries[MAX_QUERY_FRAME_NUM];
	float m_timeAcc = 0.0f;
	unsigned m_timeAccSampleNum = 0;
	float m_compressionTime = 0.0f;

	// Shaders
	ID3D11VertexShader* m_blitVS = nullptr;
	ID3D11PixelShader* m_blitPS = nullptr;
	ID3D11ComputeShader* m_compressCS[COMPRESSION_MODE_NUM] = { nullptr };

	// Resources
	ID3D11Buffer* m_ib = nullptr;
	ID3D11Texture2D* m_sourceTextureRes = nullptr;
	ID3D11ShaderResourceView* m_sourceTextureView = nullptr;
	ID3D11Texture2D* m_compressedTextureRes = nullptr;
	ID3D11ShaderResourceView* m_compressedTextureView = nullptr;
	ID3D11Texture2D* m_compressTargetRes = nullptr;
	ID3D11UnorderedAccessView* m_compressTargetUAV = nullptr;
	ID3D11Texture2D* m_tmpTargetRes = nullptr;
	ID3D11RenderTargetView* m_tmpTargetView = nullptr;
	ID3D11Texture2D* m_tmpStagingRes = nullptr;

	HWND m_windowHandle = 0;
	Vec2 m_texelBias = Vec2(0.0f, 0.0f);
	float m_texelScale = 1.0f;
	float m_imageZoom = 0.0f;
	float m_imageExposure = 0.0f;
	bool m_dragEnabled = false;
	Vec2 m_dragStart = Vec2(0.0f, 0.0f);
	bool m_updateRMSE = true;
	bool m_updateTitle = true;
	uint32_t m_imageID = 0;
	uint32_t m_imageWidth = 0;
	uint32_t m_imageHeight = 0;
	uint64_t m_frameID = 0;

	uint32_t m_compressionMode = 0;
	uint32_t m_blitMode = 1;

	// Compression error
	float m_rgbRMSLE = 0.0f;
	float m_lumRMSLE = 0.0f;

	void CreateImage();
	void DestoryImage();
	void CreateShaders();
	void DestroyShaders();
	void CreateTargets();
	void DestroyTargets();
	void CreateQueries();
	void CreateConstantBuffer();
	void UpdateRMSE();
	void UpdateTitle();
	void CopyTexture(Vec3* image, ID3D11ShaderResourceView* srcView);
};

extern CApp gApp;