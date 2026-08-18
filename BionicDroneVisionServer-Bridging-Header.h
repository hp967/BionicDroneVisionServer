//
//  BionicDroneVisionServer-Bridging-Header.h
//  桥接头文件：暴露 llama.cpp C API 给 Swift
//

#ifndef Bridging_Header_h
#define Bridging_Header_h

// llama.cpp 核心 API
#include "llama.h"

// 多模态/视觉 API (llama.cpp >= b3500 使用 libmtmd，旧版用 llava/clip)
// 注意：根据实际 llama.cpp 版本，可能需要调整为 #include "mtmd.h" 或 #include "llava.h"
#include "clip.h"

#endif /* Bridging_Header_h */
