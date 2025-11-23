---
title: A Hierarchical 3D Gaussian Representation for Real Time Rendering of Very Large Datasets
subtitle: 用于实时渲染超大型数据集的分层 3D 高斯表示
date: 2025-11-02T11:06:21+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: "#论文解读与复现"
toc: true
lastmod: 2025-11-02T11:06:21+08:00
math: true
lightgallery: false
summary: "用于实时渲染超大型数据集的分层 3D 高斯表示"
categories:
  - 论文
---

{{<link "https://repo-sam.inria.fr/fungraph/hierarchical-3d-gaussians/" "Paper_Project" "" true>}}

## 环境搭建

{{< admonition type=success title="环境" >}}

- OS：Ubuntu 22.04.5 LTS
- GPU：NVIDIA GeForce RTX 4070 12GB
- Memory：64GB
- CPU: AMD Ryzen 7 7900X

(建议使用ubuntu-22.04)
{{< /admonition >}}

### 安装 `GCC/G++`

直接使用apt安装
`sudo apt install -y gcc-10 g++-11`

版本验证
`gcc-11 -v`
`g++-11 -v`

符号链接

```bash
sudo ln -s /usr/bin/gcc-11 /usr/bin/gcc
sudo ln -s /usr/bin/g++-11 /usr/bin/g++
gcc -v
g++ -v
```

### 下载`CUDA Toolkit`

> 这里使用12.1

{{<link "https://developer.nvidia.com/cuda-toolkit-archive" "cuda-toolkit-archive" "" true>}}

可以在上面的归档页面中选择版本以及适合的操作系统和发行版

```bash {title="下载"}
sudo apt install wget -y
wget https://developer.download.nvidia.com/compute/cuda/12.1.0/local_installers/cuda_12.1.0_530.30.02_linux.run

sudo sh cuda_12.1.0_530.30.02_linux.run
```

稍后会弹出一个窗口，输入accept，后面再选择Install即可

设置`PATH`和`LD_LIBRARY_PATH`

```bash {title="设置PATH和LD_LIBRARY_PATH"}
# 如果用的是bash，需要输出到：.bashrc
echo 'export PATH=/usr/local/cuda-12.1/bin:$PATH' >> ~/.zshrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.1/lib64:$LD_LIBRARY_PATH' >> ~/.zshrc
source ~/.zshrc
```

检查nvcc版本：`nvcc --version`，输出大致如下

```text
Copyright (c) 2005-2023 NVIDIA Corporation
Built on Tue_Feb__7_19:32:13_PST_2023
Cuda compilation tools, release 12.1, V12.1.66
Build cuda_12.1.r12.1/compiler.32415258_0
```

### 编译`colmap`

[显卡计算能力](https://developer.nvidia.cn/cuda-gpus)

```bash {title="下载依赖"}
sudo apt update
sudo apt install -y \
    git \
    cmake \
    ninja-build \
    build-essential \
    libboost-program-options-dev \
    libboost-graph-dev \
    libboost-system-dev \
    libeigen3-dev \
    libfreeimage-dev \
    libmetis-dev \
    libgoogle-glog-dev \
    libgtest-dev \
    libgmock-dev \
    libsqlite3-dev \
    libglew-dev \
    qtbase5-dev \
    libqt5opengl5-dev \
    libcgal-dev \
    libceres-dev \
    libcurl4-openssl-dev \
    libmkl-full-dev
```

编译`colmap`, 由于需要cuda支持, 所以增加参数: `-DCMAKE_CUDA_ARCHITECTURES=native -DCMAKE_CUDA_ARCHITECTURES=89`,
`DCMAKE_CUDA_ARCHITECTURES`需要根据自己的显卡来设置

```bash {hl_lines=["4"]}
git clone https://github.com/colmap/colmap.git
cd colmap
mkdir build &&  cd build
cmake .. -GNinja -DBLA_VENDOR=Intel10_64lp -DCMAKE_CUDA_ARCHITECTURES=native -DCMAKE_CUDA_ARCHITECTURES=89
ninja
sudo ninja install
```

最后检查是否成功

```bash
which colmap

colmap -h
```

### 配置项目环境

> 需要使用conda, 请提前配置好conda, 我这里使用的是[miniforge](https://github.com/conda-forge/miniforge)

#### 配置虚拟环境

```bash
cd ~
git clone https://github.com/graphdeco-inria/hierarchical-3d-gaussians.git --recursive
cd hierarchical-3d-gaussians
conda create -n hierarchical_3d_gaussians python=3.12 -y
conda activate hierarchical_3d_gaussians
pip install torch==2.3.0 torchvision==0.18.0 torchaudio==2.3.0 --index-url https://download.pytorch.org/whl/cu121
pip install -r requirements.txt
```

#### 下载权重

```bash
wget -P submodules/Depth-Anything-v2/checkpoints https://huggingface.co/depth-anything/Depth-Anything-V2-Large/resolve/main/depth_anything_v2_vitl.pth
wget -P submodules/DPT/weights/ https://github.com/intel-isl/DPT/releases/download/1_0/dpt_large-midas-2f21e586.pt
```

#### 编译层次结构生成器与合并器

```bash
cd submodules/gaussianhierarchy
cmake . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j --config Release
cd ../..
```

#### 编译实时查看器

我实验时发现不能一次下载所有的, AI提示分步下载

```bash
sudo apt install -y cmake libglew-dev libassimp-dev libboost-all-dev libgtk-3-dev libopencv-dev libglfw3-dev

sudo apt install -y libavdevice-dev libavcodec-dev libeigen3-dev libxxf86vm-dev libembree-dev
```

#### 克隆层次查看器并构建

> 速度可能会很慢, 耐心等待

```bash
cd SIBR_viewers
git clone https://github.com/graphdeco-inria/hierarchy-viewer.git src/projects/hierarchyviewer
cmake . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_IBR_HIERARCHYVIEWER=ON -DBUILD_IBR_ULR=OFF -DBUILD_IBR_DATASET_TOOLS=OFF -DBUILD_IBR_GAUSSIANVIEWER=OFF
cmake --build build -j --target install --config Release
```

### 运行

到这里环境就已经配置完成了, 接下来按照官方文档一步一步执行就可以了

初步运行结果(待更新)

- 官方小数据，大约1500张图片，421MB：训练需要176min
- 自己数据集，500张图片,3.5GB: 训练需要134min
