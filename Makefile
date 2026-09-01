.PHONY: firmware check questa quartus clean

firmware:
	python3 firmware/build_firmware.py

check: firmware
	python3 tools/cross_check.py

# Requires ModelSim/Questa 'vsim' on PATH.
questa:
	vsim -c -do sim/run_all.do

# Requires Intel Quartus 'quartus_sh' on PATH.
quartus:
	cd quartus && quartus_sh --flow compile riscv_fan_soc

clean:
	rm -rf work transcript vsim.wlf quartus/db quartus/incremental_db quartus/output_files
