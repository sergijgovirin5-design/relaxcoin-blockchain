# Makefile for R2R GPU Mining Kernels
# Compiles CUDA kernels for NVIDIA GPUs and OpenCL kernels for AMD GPUs

.PHONY: all clean cuda opencl help

# Directories
CUDA_DIR := /usr/local/cuda
OPENCL_INCLUDE := /opt/opencl/include
OPENCL_LIB := /opt/opencl/lib

# Compilers and tools
NVCC := $(CUDA_DIR)/bin/nvcc
GCC := gcc
CLANG := clang++

# Compiler flags
CUDA_FLAGS := -O3 -std=c++14 -Xcompiler -fPIC
CUDA_GENCODE := -gencode arch=compute_86,code=sm_86 \
                -gencode arch=compute_89,code=sm_89 \
                -gencode arch=compute_90,code=sm_90

OPENCL_FLAGS := -O3 -std=c++14 -fPIC

# Output
CUDA_LIB := ./libr2r_cuda_miner.so
OPENCL_LIB := ./libr2r_opencl_miner.so

help:
	@echo "R2R GPU Mining Kernel Compilation"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all       - Build all GPU kernels"
	@echo "  cuda      - Build CUDA kernels for NVIDIA GPUs"
	@echo "  opencl    - Build OpenCL kernels for AMD GPUs"
	@echo "  clean     - Remove compiled binaries"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Supported GPUs:"
	@echo "  NVIDIA: RTX 3060/3070/3080/3090, RTX 4060/4070/4080/4090"
	@echo "  AMD: RX 5700 XT, RX 6700 XT, RX 6800 XT, RX 6900 XT, RX 7900 XTX"

all: cuda opencl
	@echo "Build complete!"
	@echo ""
	@echo "Generated libraries:"
	@echo "  $(CUDA_LIB)"
	@echo "  $(OPENCL_LIB)"

cuda: r2r_cuda_miner.cu
	@echo "Compiling CUDA kernels for NVIDIA GPUs..."
	@if [ -z "$(NVCC)" ] || ! command -v $(NVCC) &> /dev/null; then \
		echo "ERROR: NVIDIA CUDA Toolkit not found!"; \
		echo "Install from: https://developer.nvidia.com/cuda-toolkit"; \
		exit 1; \
	fi
	$(NVCC) $(CUDA_FLAGS) $(CUDA_GENCODE) -shared -o $(CUDA_LIB) r2r_cuda_miner.cu
	@echo "CUDA library built: $(CUDA_LIB)"

opencl: r2r_opencl_miner.cl r2r_opencl_wrapper.cpp
	@echo "Compiling OpenCL kernels for AMD GPUs..."
	@if ! command -v $(CLANG) &> /dev/null; then \
		echo "ERROR: clang not found! Install with: apt-get install clang"; \
		exit 1; \
	fi
	$(CLANG) $(OPENCL_FLAGS) -shared -fPIC \
		-I$(OPENCL_INCLUDE) -L$(OPENCL_LIB) \
		-o $(OPENCL_LIB) r2r_opencl_wrapper.cpp -lOpenCL
	@echo "OpenCL library built: $(OPENCL_LIB)"

clean:
	@echo "Cleaning up..."
	rm -f $(CUDA_LIB) $(OPENCL_LIB) *.o *.a
	@echo "Cleanup complete!"

# Detect OS and GPU drivers
check-deps:
	@echo "Checking dependencies..."
	@echo ""
	@echo "NVIDIA CUDA Toolkit:"
	@if command -v $(NVCC) &> /dev/null; then \
		$(NVCC) --version | head -3; \
	else \
		echo "  NOT INSTALLED - Download from https://developer.nvidia.com/cuda-toolkit"; \
	fi
	@echo ""
	@echo "AMD OpenCL Drivers:"
	@if [ -d "$(OPENCL_INCLUDE)" ]; then \
		echo "  INSTALLED"; \
	else \
		echo "  NOT INSTALLED - Download from https://www.amd.com/en/technologies/opencl"; \
	fi
	@echo ""
	@echo "Python 3.9+:"
	@if command -v python3 &> /dev/null; then \
		python3 --version; \
	else \
		echo "  NOT INSTALLED - Download from https://www.python.org"; \
	fi

install-deps:
	@echo "Installing build dependencies..."
	@if [ "$$(uname)" = "Linux" ]; then \
		sudo apt-get install -y build-essential clang libopencl-dev; \
	elif [ "$$(uname)" = "Darwin" ]; then \
		echo "Please install Command Line Tools for Xcode"; \
	fi
	pip install web3 eth-account pycryptodome numpy

# Development targets
test-cuda:
	@echo "Testing CUDA installation..."
	$(NVCC) --version
	$(NVCC) -x cu --cuda-path=$(CUDA_DIR) -arch=native --run-tests

profile:
	@echo "GPU Profiling (requires NVIDIA Profiler)..."
	nvprof python r2r_gpu_miner.py --config r2r_mining_config.json --duration 1

benchmark:
	@echo "Running performance benchmark..."
	python -c "import pycuda; print('CUDA Available')" && \
	python -c "import pyopencl; print('OpenCL Available')"
