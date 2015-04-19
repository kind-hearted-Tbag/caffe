#include <algorithm>
#include <vector>

#include "caffe/layer.hpp"
#include "caffe/vision_layers.hpp"

#ifdef USE_GREENTEA
#include "caffe/greentea/greentea.hpp"
#include "caffe/greentea/greentea_math_functions.hpp"
#endif

namespace caffe {

template<typename Dtype>
__global__ void ReLUForward(const int n, const Dtype* in, Dtype* out,
                            Dtype negative_slope) {
  CUDA_KERNEL_LOOP(index, n)
  {
    out[index] = in[index] > 0 ? in[index] : in[index] * negative_slope;
  }
}

template<typename Dtype>
void ReLULayer<Dtype>::Forward_gpu(const vector<Blob<Dtype>*>& bottom,
                                   const vector<Blob<Dtype>*>& top) {
  const Dtype* bottom_data = bottom[0]->gpu_data();
  Dtype* top_data = top[0]->mutable_gpu_data();
  const int count = bottom[0]->count();
  Dtype negative_slope = this->layer_param_.relu_param().negative_slope();
  if (this->device_context_.backend() == BACKEND_CUDA) {
    // NOLINT_NEXT_LINE(whitespace/operators)
    ReLUForward<Dtype><<<CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS>>>(
        count, bottom_data, top_data, negative_slope);
    CUDA_POST_KERNEL_CHECK
    ;
  } else {
#ifdef USE_GREENTEA
    std::cout << "RELU GREENTEA BEGIN" << std::endl;
    viennacl::ocl::context &ctx = viennacl::ocl::get_context(
        this->device_context_.id());
    viennacl::ocl::program &program = Caffe::Get().GetDeviceProgram(
        this->device_context_.id());
    viennacl::ocl::kernel &oclk_relu_forward = program.get_kernel(
        CL_KERNEL_SELECT("relu_forward"));
    viennacl::ocl::enqueue(
        oclk_relu_forward(count, WrapHandle((cl_mem) bottom_data, ctx),
                          WrapHandle((cl_mem) top_data, ctx), negative_slope),
        ctx.get_queue());
    ctx.get_queue().finish();
    std::cout << "RELU GREENTEA END" << std::endl;

#endif
  }
  // << " count: " << count << " bottom_data: "
  //     << (unsigned long)bottom_data
  //     << " top_data: " << (unsigned long)top_data
  //     << " blocks: " << CAFFE_GET_BLOCKS(count)
  //     << " threads: " << CAFFE_CUDA_NUM_THREADS;
}

template<typename Dtype>
__global__ void ReLUBackward(const int n, const Dtype* in_diff,
                             const Dtype* in_data, Dtype* out_diff,
                             Dtype negative_slope) {
  CUDA_KERNEL_LOOP(index, n)
  {
    out_diff[index] = in_diff[index]
        * ((in_data[index] > 0) + (in_data[index] <= 0) * negative_slope);
  }
}

template<typename Dtype>
void ReLULayer<Dtype>::Backward_gpu(const vector<Blob<Dtype>*>& top,
                                    const vector<bool>& propagate_down,
                                    const vector<Blob<Dtype>*>& bottom) {
  if (propagate_down[0]) {
    const Dtype* bottom_data = bottom[0]->gpu_data();
    const Dtype* top_diff = top[0]->gpu_diff();
    Dtype* bottom_diff = bottom[0]->mutable_gpu_diff();
    const int count = bottom[0]->count();
    Dtype negative_slope = this->layer_param_.relu_param().negative_slope();
    // NOLINT_NEXT_LINE(whitespace/operators)
    ReLUBackward<Dtype><<<CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS>>>(
        count, top_diff, bottom_data, bottom_diff, negative_slope);
    CUDA_POST_KERNEL_CHECK
    ;
  }
}

INSTANTIATE_LAYER_GPU_FUNCS(ReLULayer);

}  // namespace caffe
