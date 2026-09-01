Generate these exact Quartus IP variation names here:

1) imem_ip : RAM: 1-PORT, 32 x 1024, no byteena, soc_demo.mif
2) dmem_ip : RAM: 1-PORT, 32 x 1024, byteena[3:0], zero init
3) cfg_ip  : RAM: 1-PORT, 32 x 256, byteena[3:0], config_demo.mif

All three must use synchronous RAM with NO additional q output register.
See docs/SRAM_IP_MULTICYCLE_STEPS.md.
