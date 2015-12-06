GPURealTimeBC6H
=======

Real-time BC6H compressor, which runs entirelly on GPU (implemented using DX11 and pixel shaders). Features two presets. "Fast" presets compresses a standard 256x256x6 envmap with a full mipmap in 0.07ms on AMD R9 270 (mid-range GPU). "Quality" preset compresses a standard 256x256x6 envmap with a full mipmap in 3.913ms and compression quality is comparable to fast/normal presets of offline compressors.

Performance
===
Intel's BC6H compressor tested on Intel i7 860. GPURealTimeBC6H and DirectXTex tested on AMD R9 270. Measured in MP/s.

| GPURealTimeBC6H "Fast" | GPURealTimeBC6H "Quality"  | Intel "Very fast" | Intel "Fast" | Intel "Basic" | Intel "Slow" | Intel "Very slow" | DirectXTex |
|:----------------------:|:--------------------------:|:-----------------:|:------------:|:-------------:|:------------:|:-----------------:|:----------:|
| 7799.56                | 143.51                     | 63.10             | 4.86         | 2.22          | 0.63         | 0.33              | 0.65       |

Quality
===
Average RMSLE for "desk" image.

| GPURealTimeBC6H "Fast" | GPURealTimeBC6H "Quality"  | Intel "Very fast" | Intel "Fast" | Intel "Basic" | Intel "Slow" | Intel "Very slow" | DirectXTex |
|:----------------------:|:--------------------------:|:-----------------:|:------------:|:-------------:|:------------:|:-----------------:|:----------:|
| 0.0552                 | 0.0333                     | 0.0470            | 0.0307       | 0.0298        | 0.0294       | 0.0293            | 0.0413     |

License
===

This source code is public domain. You can do anything you want with it. It would be cool if you add attribution or just let me know that you used it for some project, but it's not required.
