// R2R OpenCL Mining Wrapper for AMD GPUs
#include <CL/cl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAX_DEVICES 16
#define MAX_SOURCE_SIZE 65536

typedef struct {
    cl_device_id device_id;
    cl_context context;
    cl_command_queue queue;
    cl_program program;
    cl_kernel kernel;
    cl_mem input_blockhash;
    cl_mem input_miner_addr;
    cl_mem input_target;
    cl_mem output_nonces;
    cl_mem output_count;
} OpenCL_Device;

static OpenCL_Device g_devices[MAX_DEVICES];
static int g_device_count = 0;

// Initialize OpenCL platform and devices
int opencl_init() {
    cl_platform_id platform_id = NULL;
    cl_uint num_devices;
    cl_device_id device_list[MAX_DEVICES];
    cl_int ret;
    
    // Get platform
    ret = clGetPlatformIDs(1, &platform_id, NULL);
    if (ret != CL_SUCCESS) {
        printf("ERROR: Failed to get OpenCL platform\n");
        return -1;
    }
    
    // Get devices
    ret = clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_GPU, 
                         MAX_DEVICES, device_list, &num_devices);
    if (ret != CL_SUCCESS) {
        printf("ERROR: Failed to get GPU devices\n");
        return -1;
    }
    
    printf("Detected %u OpenCL GPU devices\n", num_devices);
    
    // Initialize each device
    for (int i = 0; i < num_devices; i++) {
        OpenCL_Device *dev = &g_devices[i];
        dev->device_id = device_list[i];
        
        // Print device info
        char device_name[256];
        clGetDeviceInfo(dev->device_id, CL_DEVICE_NAME, 256, device_name, NULL);
        printf("GPU %d: %s\n", i, device_name);
        
        // Create context
        dev->context = clCreateContext(NULL, 1, &dev->device_id, NULL, NULL, &ret);
        if (ret != CL_SUCCESS) {
            printf("ERROR: Failed to create context for device %d\n", i);
            return -1;
        }
        
        // Create command queue
        dev->queue = clCreateCommandQueue(dev->context, dev->device_id, 0, &ret);
        if (ret != CL_SUCCESS) {
            printf("ERROR: Failed to create command queue\n");
            return -1;
        }
        
        // Allocate device memory
        dev->input_blockhash = clCreateBuffer(dev->context, CL_MEM_READ_ONLY, 32, NULL, &ret);
        dev->input_miner_addr = clCreateBuffer(dev->context, CL_MEM_READ_ONLY, 20, NULL, &ret);
        dev->input_target = clCreateBuffer(dev->context, CL_MEM_READ_ONLY, 32, NULL, &ret);
        dev->output_nonces = clCreateBuffer(dev->context, CL_MEM_WRITE_ONLY, 4096, NULL, &ret);
        dev->output_count = clCreateBuffer(dev->context, CL_MEM_WRITE_ONLY, 4, NULL, &ret);
        
        if (ret != CL_SUCCESS) {
            printf("ERROR: Failed to allocate device memory\n");
            return -1;
        }
        
        g_device_count++;
    }
    
    return g_device_count;
}

// Build and compile OpenCL kernel
int opencl_build_kernel(const char *kernel_source, const char *kernel_name) {
    cl_int ret;
    size_t source_size = strlen(kernel_source);
    
    for (int i = 0; i < g_device_count; i++) {
        OpenCL_Device *dev = &g_devices[i];
        
        // Create program
        dev->program = clCreateProgramWithSource(dev->context, 1, 
                                               (const char**)&kernel_source,
                                               &source_size, &ret);
        if (ret != CL_SUCCESS) {
            printf("ERROR: Failed to create program for device %d\n", i);
            return -1;
        }
        
        // Build program
        ret = clBuildProgram(dev->program, 1, &dev->device_id, NULL, NULL, NULL);
        if (ret != CL_SUCCESS) {
            char build_log[4096];
            clGetProgramBuildInfo(dev->program, dev->device_id,
                                CL_PROGRAM_BUILD_LOG, 4096, build_log, NULL);
            printf("ERROR: Build failed for device %d:\n%s\n", i, build_log);
            return -1;
        }
        
        // Create kernel
        dev->kernel = clCreateKernel(dev->program, kernel_name, &ret);
        if (ret != CL_SUCCESS) {
            printf("ERROR: Failed to create kernel\n");
            return -1;
        }
    }
    
    return 0;
}

// Set kernel arguments and run mining
int opencl_mine(int device_id,
               const unsigned char *blockhash,
               const unsigned char *miner_addr,
               unsigned int difficulty,
               const unsigned char *target,
               unsigned int start_nonce,
               unsigned int nonce_range,
               unsigned int *output_nonces,
               unsigned int max_nonces) {
    
    if (device_id >= g_device_count) {
        printf("ERROR: Invalid device ID %d\n", device_id);
        return -1;
    }
    
    OpenCL_Device *dev = &g_devices[device_id];
    cl_int ret;
    
    // Copy input data to device
    ret = clEnqueueWriteBuffer(dev->queue, dev->input_blockhash, CL_TRUE, 0, 32, blockhash, 0, NULL, NULL);
    ret |= clEnqueueWriteBuffer(dev->queue, dev->input_miner_addr, CL_TRUE, 0, 20, miner_addr, 0, NULL, NULL);
    ret |= clEnqueueWriteBuffer(dev->queue, dev->input_target, CL_TRUE, 0, 32, target, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("ERROR: Failed to write buffer\n");
        return -1;
    }
    
    // Set kernel arguments
    unsigned int count = 0;
    ret = clSetKernelArg(dev->kernel, 0, sizeof(cl_mem), &dev->input_blockhash);
    ret |= clSetKernelArg(dev->kernel, 1, sizeof(cl_mem), &dev->input_miner_addr);
    ret |= clSetKernelArg(dev->kernel, 2, sizeof(unsigned int), &difficulty);
    ret |= clSetKernelArg(dev->kernel, 3, sizeof(cl_mem), &dev->input_target);
    ret |= clSetKernelArg(dev->kernel, 4, sizeof(unsigned int), &start_nonce);
    ret |= clSetKernelArg(dev->kernel, 5, sizeof(cl_mem), &dev->output_nonces);
    ret |= clSetKernelArg(dev->kernel, 6, sizeof(cl_mem), &dev->output_count);
    
    if (ret != CL_SUCCESS) {
        printf("ERROR: Failed to set kernel arguments\n");
        return -1;
    }
    
    // Get device info for optimal work group size
    size_t max_work_group_size;
    clGetKernelWorkGroupInfo(dev->kernel, dev->device_id,
                           CL_KERNEL_WORK_GROUP_SIZE,
                           sizeof(max_work_group_size), &max_work_group_size, NULL);
    
    // Create work groups (optimize for GPU)
    size_t local_work_size = (max_work_group_size > 256) ? 256 : max_work_group_size;
    size_t global_work_size = ((nonce_range + local_work_size - 1) / local_work_size) * local_work_size;
    
    printf("Device %d: Local: %zu, Global: %zu\n", device_id, local_work_size, global_work_size);
    
    // Execute kernel
    ret = clEnqueueNDRangeKernel(dev->queue, dev->kernel, 1, NULL,
                               &global_work_size, &local_work_size, 0, NULL, NULL);
    if (ret != CL_SUCCESS) {
        printf("ERROR: Failed to enqueue kernel (error: %d)\n", ret);
        return -1;
    }
    
    // Wait for completion
    clFinish(dev->queue);
    
    // Read result count
    clEnqueueReadBuffer(dev->queue, dev->output_count, CL_TRUE, 0, 4, &count, 0, NULL, NULL);
    
    // Read found nonces
    unsigned int num_found = (count < max_nonces) ? count : max_nonces;
    if (num_found > 0) {
        clEnqueueReadBuffer(dev->queue, dev->output_nonces, CL_TRUE, 0, 
                          num_found * 4, output_nonces, 0, NULL, NULL);
    }
    
    return num_found;
}

// Clean up OpenCL resources
void opencl_cleanup() {
    cl_int ret;
    
    for (int i = 0; i < g_device_count; i++) {
        OpenCL_Device *dev = &g_devices[i];
        
        if (dev->kernel) clReleaseKernel(dev->kernel);
        if (dev->program) clReleaseProgram(dev->program);
        if (dev->input_blockhash) clReleaseMemObject(dev->input_blockhash);
        if (dev->input_miner_addr) clReleaseMemObject(dev->input_miner_addr);
        if (dev->input_target) clReleaseMemObject(dev->input_target);
        if (dev->output_nonces) clReleaseMemObject(dev->output_nonces);
        if (dev->output_count) clReleaseMemObject(dev->output_count);
        if (dev->queue) clReleaseCommandQueue(dev->queue);
        if (dev->context) clReleaseContext(dev->context);
    }
    
    g_device_count = 0;
}

// Get device count
int opencl_get_device_count() {
    return g_device_count;
}

// Get device name
const char* opencl_get_device_name(int device_id) {
    static char device_name[256];
    if (device_id < g_device_count) {
        clGetDeviceInfo(g_devices[device_id].device_id, CL_DEVICE_NAME, 256, device_name, NULL);
        return device_name;
    }
    return "Unknown";
}
