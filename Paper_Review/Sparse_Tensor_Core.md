Paper Review: Sparse Tensor Core. (ISCA 2021)
===

###### tags: `AAML`

* Dual-side Sparse Tensor Core
    * Published in ISCA, 2021 by Yang Wang et al.

<!-- summary, strength, weakness, questions, comment -->

### Paper Summary
Various recently proposed sparse yet performant deep neural networks (DNNs) show great potential for improving their computation efficiency. However, the irregular distribution of activation and weight data makes it hard to leverage such sparsity using current GPU designs. To this end, the paper proposes a novel architecture that combines outer product computation primitive and bitmap-based encoding format to accelerate SpGEMM (sparse general matrix-matrix multiplication) and SpCONV (sparse convolution) operations.

For SpGEMM operation, the author adopts the gather-and-scatter method to filter out those unnecessary operations. Firstly, it uses a hierarchical bitmap representation to identify the non-zero index. Then an Outer-product Tensor Core (OTC), modified from NVIDIA's Tensor Core, receives those non-zero values to perform the outer-product operation. Lastly, it scatters back the result using an accumulation buffer by matching the previous bitmap. Combined with a warp-level scheduling strategy (i.e., extended WMMA instructions), the SpGEMM operations could easily exploit such sparsity at a fine-grained level.

For the SpCONV operation, the author proposes an implicit im2col operation that converts the convolution operation into a matrix-multiplication operation. The encoding format is designed to fits the SpGEMM operation mentioned above so that it enjoys almost the same high utilization. 

As the paper has illustrated, this method could improve performance by up to one order of magnitude with a small hardware overhead. Amazingly, such improvement increases the area and power by merely 1.5% and 1.6% of the GPU design. However, since such modification only changes the Tensor Core part, I wonder if the overhead is still acceptable compared to only the original Tensor Core. Also, will there be any extra performance losses for the original dense mode matrix multiplication?