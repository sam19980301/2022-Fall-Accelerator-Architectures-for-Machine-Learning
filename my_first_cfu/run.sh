export PATH=/tools/Xilinx/Vivado/2022.2/bin:$PATH
export PATH=$PATH:$HOME/riscv64-unknown-elf-gcc-10.1.0-2020.08.2-x86_64-linux-ubuntu14/bin
make clean
make ENABLE_TRACE_ARG=--trace renode # simulation for debugging
# time make prog USE_VIVADO=1 TTY=/dev/ttyUSB0 EXTRA_LITEX_ARGS="--sys-clk-freq 50000000 --cpu-variant=perf+cfu"
# make load BUILD_JOBS=12 TTY=/dev/ttyUSB1 EXTRA_LITEX_ARGS="--cpu-variant=perf+cfu"