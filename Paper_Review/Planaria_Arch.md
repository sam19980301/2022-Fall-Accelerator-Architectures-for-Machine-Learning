Paper Review: Planaria Arch. (MICRO, 2020)
===

###### tags: `AAML`

* Planaria: Dynamic Architecture Fission for Spatial Multi-Tenant Acceleration of Deep Neural Networks
    * Published in MICRO, 2020 by Soroush Ghodrati et al.

<!-- summary, strength, weakness, questions, comment -->

### Paper Summary
With the growing demand for INFerence-as-a-Service (INFaaS) from cloud datacenter, an accelerator optimized for multi-tenant applications could provide more efficient and reliable services. To this end, the paper proposes Planaria, a flexible architecture that could spatially allocate computation resources across DNN inference tasks.

As a systolic-array-based accelerator, Planaria supports omni-direction data movement and reorganization mechanism called *Fission Pod* to offer matrix multiplication operations in different granularity. This design has four *Fission Pods*, each containing four sub-arrays (32x32 PEs) and a shared memory buffer. Sixteen stand-alone and full-fledged sub-arrays could work together for a large task or individually for several small ones, exploiting the resource utilization based on the current workload. A task scheduler is responsible for such resource allocation. For each DNN model, required cycles are estimated at compiling stage under different resource constraints. With this timing information, the task scheduler from the CPU side could dynamically allocate as few hardware resources as possible to meet the QoS requirement.

With the abovementioned optimizations, Planaria improves throughput, SLA satisfaction rate, and fairness only with the acceptable area and power overhead.

From a high-level aspect, the CPU is designed for general sequential operations, and GPU is for general parallel ones. On the other hand, an AI accelerator mainly focuses on parallelizing DNN-related operations, which is more like an ASIC. While considering the cost of designing & fabricating chips, the emerging DNN models every day, and multi-tenant applications requirement, it'd be better if an accelerator is "general" enough to handle different dataflow and operations. In other words, it seems that the accelerator is moving toward GP-accelerator just like past GPU toward GPGPU -- the design should perform fast and ensure enough flexibility. If that is the case, perhaps those GPU optimization methods could be a good reference for designing an accelerator.
