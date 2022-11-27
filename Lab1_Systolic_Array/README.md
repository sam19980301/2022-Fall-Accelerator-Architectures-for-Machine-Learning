Lab1: Systolic Array Implementation Report
===

###### tags: `AAML`

## Pseduo code of output stationary MM with 3-level for loop
```
for (int m=0; m<M; m++){
    for (int n=0; n<N; n++){
        for (int k=0; k<K; k++){
            C[m,n] += A[m,k] * B[k,n]
        }
    }
}
```

## Implementation of Systolic Array
The systolic array in this lab applies output-stationary dataflow. Given two matrices *A*, *B* in shape (*M, K*), (*K, N*) respectively, the systolic array, arranged in 2d-order, allocates one processing element (PE) for each element of the output matrix (*M* by *N* in total), each of which is responsible for the complete calculation of corresponding inner products. The result of each element depends on only one PE and its input signal, as shown below. PE performs one MAC operation for each cycle and accumulates the partial sum in its register file (RF). To further exploit the data locality of matrix-multiplication (MM) operation, the input/weight value from the left/top side will go through a specific row/column in sequential order with one-cycle-lag along the PE array's column/row. This way, the design minimizes the overall data movement and requires less global buffer (memory) access.

![](https://i.imgur.com/ucNUfVf.png)

![](https://i.imgur.com/ZIlgVij.png)

Systolic arrays should be in the size of (*K, N*) in the ideal case to fit the two input matrices. While if *K* and *N* is too large, the hardware overhead would proportionally increase. Also, *K* and *N* may vary between inputs, which requires a more flexible design to handle such a situation. TPU applies tiling here to divide given matrices into several small pieces (4x4 each) so that they can be regularly fit into a fix-sized systolic array.

Lastly, this design implements a finite state machine to control the signals of 3 memory (in tiling order). As the figure shows, there are four states for TPU, STATE_IDLE, STATE_CALC, STATE_WRITE, and STATE_OUTPUT. In STATE_IDLE, TPU remains idle until *in_valid* is pulled up; In STATE_CALC, TPU calculates the result of elements within a 4x4 tile. In STATE_WRITE, TPU writes the result back to memory. If there are still other unfinished tiles, TPU goes back to STATE_CALC to continue the calculation of the next tile. Otherwise, TPU enters STATE_OUTPUT to pull up the *busy* signal.

![](https://i.imgur.com/CI03YgR.png)

In total, TPU requires *K*+7 cycles to perform the whole calculation for each tile: 1 cycle for input initialization, *K* cycles for inner products, and 3+3 cycles for going through all rows/columns of the systolic array.

There is still room for improvement, e.g., overlapping inner product calculation cycles with writing cycles and skipping the last few padding output rows. While assuming the matrix size is large enough, the difference may be negligible.

## Difference between weight-stationary and output-stationary dataflow
The weight-stationary dataflow stores the weight values inside RF for each PE. PEs do the MAC (*d = ab + c*) operations with only one variable (*a*) changed and another (*b*) unchanged and also send the summation result (*c*) to adjacent PEs every cycle. In comparison, the output-stationary dataflow keeps the summation (*c*) inside RF, with both variables (*a, b*) changed for each cycle.
From the PPA aspect, weight-stationary dataflow minimizes the data movement of weight value, so it achieves better performance with less power consumption and circuit area for tasks such as convolution operation. On the other hand, output-stationary dataflow minimizes the data movement of the partial sum from MAC. Hence, it achieves better performance with less power consumption and circuit area for the MM task (*C = A @ B*, with shape (*M, N*),(*M, K*),(*K, N*) respectively), especially when the reduction axis *K* is large.