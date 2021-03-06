// Copyright (c) 2016-2017 Intel Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


#include "include/include_all.cl"

///////////////////////// Input Index /////////////////////////
inline uint FUNC(get_input_index)(uint b, uint f, uint y, uint x)
{
#if   INPUT0_SIMPLE
    return GET_DATA_INDEX(INPUT0, b, f, y, x);
#elif defined INPUT0_LAYOUT_BS_F_BSV8__AF8  || \
      defined INPUT0_LAYOUT_BS_F_BSV16__AF8
    return GET_DATA_BS_FYX_BSV8_INDEX(INPUT0, b, f, y, x, SUB_GROUP_SIZE);
#else
#error - not supported
#endif
}

///////////////////////// Output Index /////////////////////////

inline uint FUNC(get_output_index)(uint b, uint f, uint y, uint x)
{
#if   OUTPUT_SIMPLE
    return GET_DATA_INDEX(OUTPUT, b, f, y, x);
#elif defined OUTPUT_LAYOUT_BS_F_BSV8__AF8  || \
      defined OUTPUT_LAYOUT_BS_F_BSV16__AF8
    return GET_DATA_BS_FYX_BSV8_INDEX(OUTPUT, b, f, y, x, SUB_GROUP_SIZE);
#else
#error - not supported
#endif
}

KERNEL (reorder_data_fast_b1)(
    const __global INPUT0_TYPE* input, 
    __global OUTPUT_TYPE* output
#ifdef MEAN_SUBTRACT_IN_BUFFER
    , __global MEAN_SUBTRACT_TYPE* mean_subtract
#endif
    )
{
    uint data_idx = get_global_id(0);
    if(data_idx >= ELEMENTS_COUNT)
        return;
 
 #if defined OUTPUT_LAYOUT_BFYX
    uint tmp_data_idx = data_idx / INPUT0_BATCH_NUM;
    const uint b = data_idx - tmp_data_idx * INPUT0_BATCH_NUM;
    data_idx = tmp_data_idx;

    tmp_data_idx = data_idx / INPUT0_FEATURE_NUM;
    const uint f = data_idx - tmp_data_idx * INPUT0_FEATURE_NUM;
    data_idx = tmp_data_idx;

    tmp_data_idx = data_idx / INPUT0_SIZE_X;
    const uint x = data_idx - tmp_data_idx * INPUT0_SIZE_X;
    data_idx = tmp_data_idx;

    tmp_data_idx  = data_idx / INPUT0_SIZE_Y;
    const uint y = data_idx - tmp_data_idx * INPUT0_SIZE_Y;
#elif defined OUTPUT_LAYOUT_YXFB
    uint tmp_data_idx = data_idx / INPUT0_SIZE_X;
    const uint x = data_idx - tmp_data_idx * INPUT0_SIZE_X;
    data_idx = tmp_data_idx;

    tmp_data_idx = data_idx / INPUT0_SIZE_Y;
    const uint y = data_idx - tmp_data_idx * INPUT0_SIZE_Y;
    data_idx = tmp_data_idx;

    tmp_data_idx = data_idx / INPUT0_FEATURE_NUM;
    const uint f = data_idx - tmp_data_idx * INPUT0_FEATURE_NUM;
    data_idx = tmp_data_idx;

    tmp_data_idx  = data_idx / INPUT0_BATCH_NUM;
    const uint b = data_idx - tmp_data_idx * INPUT0_BATCH_NUM;
#else // BYXF?
    uint tmp_data_idx = data_idx / INPUT0_BATCH_NUM;
    const uint b = data_idx - tmp_data_idx * INPUT0_BATCH_NUM;
    data_idx = tmp_data_idx;

    tmp_data_idx = data_idx / INPUT0_SIZE_Y;
    const uint y = data_idx - tmp_data_idx * INPUT0_SIZE_Y;
    data_idx = tmp_data_idx;

    tmp_data_idx = data_idx / INPUT0_SIZE_X;
    const uint x = data_idx - tmp_data_idx * INPUT0_SIZE_X;
    data_idx = tmp_data_idx;

    tmp_data_idx  = data_idx / INPUT0_FEATURE_NUM;
    const uint f = data_idx - tmp_data_idx * INPUT0_FEATURE_NUM;
#endif

    uint4 ov = FUNC_CALL(reshape_dims)(b,f,y,x, INPUT0_SIZE_Y, INPUT0_SIZE_X, OUTPUT_SIZE_Y, OUTPUT_SIZE_X, INPUT0_DIMS, OUTPUT_DIMS);
    const uint input_idx  = FUNC_CALL(get_input_index)(b, f, y, x);
    const uint output_idx = FUNC_CALL(get_output_index)(ov[0],ov[1],ov[2],ov[3]);
    CALC_TYPE res = TO_CALC_TYPE(input[input_idx]);
    
#if   defined MEAN_SUBTRACT_INSIDE_PARAMS
    res -= TO_CALC_TYPE(VALUE_TO_SUBTRACT[f % VALUE_TO_SUBTRACT_SIZE]);
#elif defined MEAN_SUBTRACT_IN_BUFFER
    uint4 msv = FUNC_CALL(reshape_dims)(b,f,y,x, INPUT0_SIZE_Y, INPUT0_SIZE_X, MEAN_SUBTRACT_SIZE_Y, MEAN_SUBTRACT_SIZE_X, INPUT0_DIMS, MEAN_SUBTRACT_DIMS);
    res -= TO_CALC_TYPE(mean_subtract[GET_DATA_INDEX_SAFE(MEAN_SUBTRACT, msv[0], msv[1], msv[2], msv[3])]);
#endif

    output[output_idx] = ACTIVATION(TO_OUTPUT_TYPE(res), NL_M ,NL_N);
}

#undef GET_DATA_INDEX_SAFFFE