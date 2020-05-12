GPURealTimeBC6H
=======

Real-time BC6H compressor which runs on a GPU. Includes a small testbed application. This compressor is used in a few released AA/AAA games.

Compressor has two presets: 
* "Fast" - compresses a standard 256x256x6 cubemap in 0.02ms on NV P4000 (GPU perf in between NV GTX 1060 and NV GTX 1070). Compression quality is comparable to fast presets of offline compressors.
* "Quality" - compresses a standard 256x256x6 cubemap in 0.528ms on on NV P4000. Compression quality is comparable to normal presets of offline compressors.

Algorithms
===
Algorithms are based on:
* "Real-Time DXT Compression" by J.M.P. van Waveren, 2006
* "High Quality DXT Compression using CUDA" by Ignacio Castaño, 2007

With some modifications for handling HDR range, new encoding modes and format, and optimizing for a perceptual error (optimizing for a log luminance error instead of a plain RGB error).

Quality
===
Quality compared using RMSLE (lower is better).

|          | GPU Real-Time BC6H "Fast" | GPU Real-Time BC6H "Quality"  | Intel "Very fast" | Intel "Fast" | Intel "Basic" | Intel "Slow" | Intel "Very slow" | DirectXTex 
| -------  | ------------------------- | ----------------------------- | ----------------- | ------------ | ------------- | ------------ | ----------------- | ----------
| Atrium   | 0.0074                    | 0.0066                        | 0.0080            | 0.0069       | 0.0067        | 0.0067       | 0.0067            | 0.0079     
| Backyard | 0.0073                    | 0.0070                        | 0.0072            | 0.0067       | 0.0065        | 0.0065       | 0.0065            | 0.0075     
| Desk     | 0.0447                    | 0.0328                        | 0.0470            | 0.0307       | 0.0298        | 0.0294       | 0.0293            | 0.0413     
| Memorial | 0.0158                    | 0.0126                        | 0.0192            | 0.0135       | 0.0133        | 0.0132       | 0.0131            | 0.0243      
| Yucca    | 0.0168                    | 0.0123                        | 0.0145            | 0.0108       | 0.0105        | 0.0103       | 0.0103            | 0.0124     

License
===
This source code is public domain. You can do anything you want with it. It would be cool if you add attribution or just let me know that you used it for some project, but it's not required.