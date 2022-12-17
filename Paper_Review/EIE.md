Paper Review: EIE. (ISCA, 2016)
===

###### tags: `AAML`

* EIE: Efficient Inference Engine on Compressed Deep Neural Network
    * Published in ISCA, 2016 by Song Han et al.

<!-- summary, strength, weakness, questions, comment -->

### Paper Summary
Systolic array architecture or numerous sets of SIMD arithmetic elements is the main feature of the current accelerator design. Such hardware achieves significant performance, especially on computation-intensive tasks, since it provides much more computing units than others and efficiently utilizes the given activation/weight data. While on the other hand, the memory bottleneck may hinder the model performance for bandwidth-limited tasks such as fully-connected layers widely used in RNN and LSTM models. To this end, this paper proposes an energy-efficient inference engine (EIE) to tackle this problem, which efficiently performs the sparse matrix-vector multiplication with weight sharing of a compressed network model.

The paper focuses on one main optimization: exploiting all potential sparsity from the hardware side to skip those unnecessary operations. Two components could achieve this: a customized activation queue that filters out those non-zero input values and a sparse matrix read unit that fetches the non-zero weight from SRAM. This way, even a large model layer could fit into the design without DRAM access, saving much power and time. Also, this could save the required MAC operations too. The experiment shows an improvement in the power and timing compared to CPU, GPU, and FPGA implementation by one to three orders.

While with such a significant enhancement, it remains to be verified that this method could apply to other computation-intensive layers such as convolution or self-attention block. Since the required DRAM access is lesser for these operations, EIE may gain less improvement than the cases shown in the paper.