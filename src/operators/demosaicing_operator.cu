///@file demosaicing_operator.cu
///@brief demosaicing operator
///@author Joana Grah <joana.grah@icg.tugraz.at>
///@date 09.07.2018


#include "utils.h"
#include "tensor/d_tensor.h"
#include "demosaicing_operator.h"

template<typename T, optox::BayerPattern P>
__global__ void demosaicingForwardKernel(
    typename optox::DTensor<T, 4>::Ref output,
    const typename optox::DTensor<T, 4>::ConstRef input)
{
    const int x = 2 * (threadIdx.x + blockIdx.x * blockDim.x);
    const int y = 2 * (threadIdx.y + blockIdx.y * blockDim.y);
    const int s = threadIdx.z + blockIdx.z * blockDim.z;
    
    if (x < input.size_[2] && y < input.size_[1] && s < input.size_[0])
    {
        switch (P)
        {
            case optox::BayerPattern::BGGR:
            {
                output(s, y, x, 0) = input(s, y, y, 2);
                output(s, y, x+1, 0) = input(s, y, x+1, 1);
                output(s, y+1, x, 0) = input(s, y+1, x, 1);
                output(s, y+1, x+1, 0) = input(s, y+1, y+1, 0);
                break;
            }
            case optox::BayerPattern::RGGB:
            {
                output(s, x, y, 0) = input(s, y, x, 0);
                output(s, y, x+1, 0) = input(s, y, x+1, 1);
                output(s, y+1, x, 0) = input(s, y+1, x, 1);
                output(s, y+1, x+1, 0) = input(s, y+1, x+1, 2);
                break;
            }
            case optox::BayerPattern::GBRG:
            {
                output(s, x, y, 0) = input(s, y, x, 1);
                output(s, y, x+1, 0) = input(s, y, x+1, 2);
                output(s, y+1, x, 0) = input(s, y+1, x, 0);
                output(s, y+1, x+1, 0) = input(s, y+1, x+1, 1);
                break;
            }
            case optox::BayerPattern::GRBG:
            {
                output(s, x, y, 0) = input(s, y, x, 1);
                output(s, y, x+1, 0) = input(s, y, x+1, 0);
                output(s, y+1, x, 0) = input(s, y+1, x, 2);
                output(s, y+1, x+1, 0) = input(s, y+1, x+1, 1);
                break;
            }
        }
    }
}

template<typename T>
void optox::DemosaicingOperator<T>::computeForward(optox::OperatorOutputVector &&outputs,
    const optox::OperatorInputVector &inputs)
{
    auto input = this->template getInput<T, 4>(0, inputs);
    auto output = this->template getOutput<T, 4>(0, outputs);

    if (input->size()[3] != 3)
        THROW_OPTOXEXCEPTION("DemosaicingOperator: input to forward must be RGB image!");

    if (output->size()[3] != 1)
        THROW_OPTOXEXCEPTION("DemosaicingOperator: output of forward must have 1 channel!");

    dim3 dim_block = dim3(32, 32, 1);
    dim3 dim_grid(divUp(input->size()[2] / 2 + 1, dim_block.x),
                  divUp(input->size()[1] / 2 + 1, dim_block.y),
                  divUp(input->size()[0], dim_block.z));

    switch (this->pattern_)
    {
        case optox::BayerPattern::BGGR:
            demosaicingForwardKernel<T, optox::BayerPattern::BGGR> <<<dim_grid, dim_block, 0, this->stream_>>>(*output, *input);
            break;
        case optox::BayerPattern::RGGB:
            demosaicingForwardKernel<T, optox::BayerPattern::RGGB> <<<dim_grid, dim_block, 0, this->stream_>>>(*output, *input);
            break;
        case optox::BayerPattern::GBRG:
            demosaicingForwardKernel<T, optox::BayerPattern::GBRG> <<<dim_grid, dim_block, 0, this->stream_>>>(*output, *input);
            break;
        case optox::BayerPattern::GRBG:
            demosaicingForwardKernel<T, optox::BayerPattern::GRBG> <<<dim_grid, dim_block, 0, this->stream_>>>(*output, *input);
            break;
    }
    OPTOX_CUDA_CHECK;
}

template<typename T, optox::BayerPattern P>
__global__ void demosaicingAdjointKernel(
    typename optox::DTensor<T, 4>::Ref output,
    const typename optox::DTensor<T, 4>::ConstRef input)
{
    const int x = 2 * (threadIdx.x + blockIdx.x * blockDim.x);
    const int y = 2 * (threadIdx.y + blockIdx.y * blockDim.y);
    const int s = threadIdx.z + blockIdx.z * blockDim.z;
    
    if (x < input.size_[2] && y < input.size_[1] && s < input.size_[0])
    {
        switch (P)
        {
            case optox::BayerPattern::BGGR:
            {
		        output(s, y, x, 2) = input(s, y, x, 0);
                output(s, y, x+1, 1) = input(s, y, x+1, 0);
                output(s, y+1, x, 1) = input(s, y+1, x, 0);
                output(s, y+1, x+1, 0) = input(s, y+1, x+1, 0);
                break;
            }
            case optox::BayerPattern::RGGB:
            {
                output(s, y, x, 0) = input(s, y, x, 0);
                output(s, y, x+1, 1) = input(s, y, x+1, 0);
                output(s, y+1, x, 1) = input(s, y+1, x, 0);
                output(s, y+1, x+1, 2) = input(s, y+1, x+1, 0);
                break;
            }
            case optox::BayerPattern::GBRG:
            {	
                output(s, y, x, 1) = input(s, y, x, 0);
                output(s, y, x+1, 2) = input(s, y, x+1, 0);
                output(s, y+1, x, 0) = input(s, y+1, x, 0);
                output(s, y+1, x+1, 1) = input(s, y+1, x+1, 0);
                break;
            }
            case optox::BayerPattern::GRBG:
            {
                output(s, y, x, 1) = input(s, y, x, 0);
                output(s, y, x+1, 0) = input(s, y, x+1, 0);
                output(s, y+1, x, 2) = input(s, y+1, x, 0);
                output(s, y+1, x+1, 1) = input(s, y+1, x+1, 0);
                break;
            }
        }
    }
}

template<typename T>
void optox::DemosaicingOperator<T>::computeAdjoint(optox::OperatorOutputVector &&outputs,
    const optox::OperatorInputVector &inputs)
{
    auto input = this->template getInput<T, 4>(0, inputs);
    auto output = this->template getOutput<T, 4>(0, outputs);

    if (input->size()[3] != 1)
        THROW_OPTOXEXCEPTION("DemosaicingOperator: input to adjoint must have 1 channel!");

    if (output->size()[3] != 3)
        THROW_OPTOXEXCEPTION("DemosaicingOperator: output of adjoint must be RGB image!");

    output->fill(0);

    dim3 dim_block = dim3(32, 32, 1);
    dim3 dim_grid(divUp(input->size()[2] / 2 + 1, dim_block.x),
                  divUp(input->size()[1] / 2 + 1, dim_block.y),
                  divUp(input->size()[0], dim_block.z));

    switch (this->pattern_)
    {
        case optox::BayerPattern::BGGR:
            demosaicingAdjointKernel<T, optox::BayerPattern::BGGR> <<<dim_grid, dim_block, 0, this->stream_>>>(*output, *input);
            break;
        case optox::BayerPattern::RGGB:
            demosaicingAdjointKernel<T, optox::BayerPattern::RGGB> <<<dim_grid, dim_block, 0, this->stream_>>>(*output, *input);
            break;
        case optox::BayerPattern::GBRG:
            demosaicingAdjointKernel<T, optox::BayerPattern::GBRG> <<<dim_grid, dim_block, 0, this->stream_>>>(*output, *input);
            break;
        case optox::BayerPattern::GRBG:
            demosaicingAdjointKernel<T, optox::BayerPattern::GRBG> <<<dim_grid, dim_block, 0, this->stream_>>>(*output, *input);
            break;
    }
    OPTOX_CUDA_CHECK;
}

#define REGISTER_OP(T) \
    template class optox::DemosaicingOperator<T>;

OPTOX_CALL_REAL_NUMBER_TYPES(REGISTER_OP);
#undef REGISTER_OP
#undef REGISTER_OP_T