Paper Review: Simba Arch. (MICRO, 2019)
===

###### tags: `AAML`

* Simba: Scaling Deep-Learning Inference with Multi-Chip-Module-Based Architecture
    * Published in MICRO, 2019 by Yakun Sophia Shao et al.

<!-- summary, strength, weakness, questions, comment -->

### Paper Summary
Given the trend towards large-scale systems, multi-chip-modules (MCM), an approach that combines many smaller modules into a large one, elegantly deals with the increasingly complicated scalability problem. While it reduces the design complexity by reusing sub-modules, the main problem is the non-uniformity of communication latency. To this end, this paper proposes Simba, a scalable MCM-based architecture with optimization for such an imbalance issue.

Simba comprises four levels: package, chiplet, processing element(PE), and MAC unit. Hierarchical structure allows Simba to assign deep learning tasks and allocate computation units in fine-grained granularity. To fully exploit this advantage with communication latency across and within each level into consideration, three tiling optimizations are adopted. It includes a communication-aware data placement mechanism to minimize inter-chiplet traffic, a non-uniform work partition to balance computation and communication latency, and a pipelining dataflow to improve resource utilization further.

Compared to the Planaria architecture mentioned in the last paper, there is a lot in common at a high level. Both are in a hierarchical structure (for various DL models/layers) and equips with a specialized static software-based AI compiler. Assuming that the given computation type is limited and known, the design could perform the tasks efficiently using the dataflow pre-determined by the compiler. While as the system scales get larger and more kinds of DL models are deployed, I wonder whether a more complex parallel dataflow would lead to performance degradation.