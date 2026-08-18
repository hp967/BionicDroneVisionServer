# BionicDroneVisionServer

iOS 应用 - 无人机视觉服务器

## 构建方式

### 本地构建（需要 macOS 14+）
1. 用 Xcode 打开项目
2. Product → Archive
3. Export IPA

### GitHub Actions 构建（推荐）
1. 创建 GitHub 私有仓库
2. 推送此项目到仓库
3. Actions 会自动构建 IPA
4. 下载 Artifact

## 文件说明
- `BionicDroneVisionServer/` - Swift 源文件
- `llama.cpp/` - llama.cpp b3622 源码
- `.github/workflows/build.yml` - GitHub Actions 构建流程
