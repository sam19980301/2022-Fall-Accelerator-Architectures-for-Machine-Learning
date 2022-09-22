Paper Review: Deep Learning Hardware (ISSCC, 2019)
===

###### tags: AAML

* Deep Learning Hardware: Past, Present, and Future
    * Published in ISSCC, 2019 by Yann LeCun

### Paper Summary
The paper summarizes the hardware & software development of the deep learning (DL) model from history aspect. In the past, limited but expensive computing power, few open-source and user-friendly tools, and small datasets were the main factors that hindered the growth of DL research. While these problems are gradually being alleviated nowadays (since the 2010s), new corresponding requirements, which could be categorized into three types, remain to be solved.

With increasingly large, unlabeled dataset, training method that could "learn" the latent information of data more efficiently, such as self-supervised learning (SSL), is replacing the traditional supervised-based method. Also, the DL model is moving towards a more general one with fewer prior assumptions, such as a graph embedding network, to fit the data with a complicated structure. More importantly, with all changes from the software side, computing hardware should also be co-optimized to fully exploit the model performance. Such hardware design is of equal importance in dealing with different specific tasks. For instance, an inference model deployed at a data center will focus more on power consumption and cost, while running the DL model on edge devices requires real-time latency, etc. Without modification from the hardware side, such a requirement is nearly impossible.

To this end, the author mentioned five possible trends that could put DL application further. It includes an SSL-like learning method, a more flexible and dynamic network program, inference-oriented hardware design, low-power hardware design (including number representation, sparse activations, or KNN-like memory-based operator), and a heterogeneous-input model.

The pursuit of extreme performance will push research in all directions. While with many such possibilities for the development of future DL research, what is the most promising/crucial factor that will determine the current and next-generation application? Maybe only time will tell.