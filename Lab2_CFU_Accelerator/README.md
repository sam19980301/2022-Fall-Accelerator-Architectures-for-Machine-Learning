Lab2: CFU Accelerator Implementation Report
===

###### tags: `AAML`

### CFU Instruction Specification
To accelerate the computation of matrix multiplication, CFU should at least support instructions that store buffer A & B, load buffer C, and peform matrix multiplication. Hence, the instruction encoding rule is designed as follow.

| opcode | funct7 | instruction | description              |
| ------ | ------ | ----------- | ------------------------ |
| 0      | 0      | Load A      | output = A[input_0]      |
|        | 1      | Load B      | output = B[input_0]      |
|        | 2      | Load C      | output = C[input_0]      |
|        | 3      | Store A     | A[input_0] = input_1     |
|        | 4      | Store B     | B[input_0] = input_1     |
|        | 5      | Store C     | C[input_0] = input_1     |
| 1      | *      | Mat Mult    | C[M,N] = A[M,K] @ B[K,N] |
* M = input_0, {K, N} = input_1

### CFU Architecture & Implementation
The CFU module, implemented as a 4-state FSM as follow, is a controller of 3 global buffers and a TPU module. CFU starts at *STATE_IDLE* after reset. If receiving a load instruction, CFU transforms to *STATE_LOAD* for one cycle, waiting for loading data from the global buffer. If receiving a store instruction, CFU directly stores the value in the buffer. If receiving a matrix multiplication instruction, CFU transforms to *STATE_CALC*, calling TPU and waiting for its completeness. After finishing the given instruction, CFU enters the *STATE_OUTPUT* to handshake with the CPU. Finally, it goes back to *STATE_IDLE*, waiting for the next instruction.

![](https://i.imgur.com/xJ1vXQP.png)

The TPU sub-module is mainly built upon the previous Lab1 4x4 systolic array implementation. The only modification is that now TPU performs signed MAC operation for each cycle with one of its operands containing fixed offset. Such a design fits the operation frequently called from the convolution layer.

The size of global buffer A/B/C is set to 256/16384/256 (entries) respectively to fit the whole data required for MM operations like ```A[4, 256] @ B[256, 256]```. Such a design is specifically optimized for the MM operations encountered in the *pdti8 model* without using too much block RAM resource. Also, the clock frequency is set to 50MHz rather than the default 75MHz to avoid synthesis errors arising from the long critical path.


### Programming Model & Convolution Optimization
The lab focuses on optimizing the convolution layer of the *pdti8 model* (Person Detection int8 model) provided by CFU-playground from both hardware and software aspects.

From the software side, since all the operations are 1x1 convolution ones, the convolution layer could be reduced to a fully connected layer that performs simple matrix multiplication without im2col transformation. Also, inspired by [model-specific optimizations](https://cfu-playground.readthedocs.io/en/latest/step-by-step.html) mentioned in the CFU-playground website, replacing those fixed-value parameters with constant could further improve the performance.

From the hardware side, matrix multiplication is performed by CFU to accelerate the computation speed. It requires the CPU to store the input value/filter value to CFU global buffers. Then TPU should be called to do matrix multiplication, followed by CPU loading the result back from CFU global buffer.


### Experimental Result
The experimental result shows a speedup of around 2.77x on the *pdti8 model* compared to the original official implementation.

- Original
    ```
     Counter |  Total | Starts | Average |     Raw
    ---------+--------+--------+---------+--------------
        0    |     0  |     0  |   n/a   |            0
        1    |     0  |     0  |   n/a   |            0
        2    |     0  |     0  |   n/a   |            0
        3    |     0  |     0  |   n/a   |            0
        4    |     0  |     0  |   n/a   |            0
        5    |     0  |     0  |   n/a   |            0
        6    |     0  |     0  |   n/a   |            0
        7    |     0  |     0  |   n/a   |            0
       213M (    212825469 )  cycles total
    ```
    
- Optimized
    ```
    Counter |  Total | Starts | Average |     Raw
    ---------+--------+--------+---------+--------------
        0    |    18M |    14  |  1282k  |     17948628    --> Whole conv op
        1    |   743k |   163  |  4556   |       742677    --> Buffer A related op
        2    |  1388k |    14  |    99k  |      1387781    --> Buffer B related op
        3    |  1369k | 124418 |    11   |      1369346    --> Buffer C related op
        4    |   567k |   163  |  3481   |       567429    --> MM op
        5    |     0  |     0  |   n/a   |            0
        6    |     0  |     0  |   n/a   |            0
        7    |     0  |     0  |   n/a   |            0
        77M (     76741892 )  cycles total
    ```

### Others
> What you’ve learned? (Please talk about the things that you don’t know before finishing this Lab and also talk about the difficult part of the lab based on your background)

The teaching I've learned before in other courses mainly focuses on RTL design & simulation. This assignment requires students to utilize existing toolchains further to deploy our design into the FPGA board. It gives students a deeper understanding of the whole design flow through this lab.