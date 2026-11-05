SRC = rtl/i2s_core.v rtl/top.v

.PHONY: sim model-test bit prog clean
sim:
	mkdir -p build
	iverilog -g2012 -o build/tb tb/tb_i2s.v rtl/i2s_core.v && vvp build/tb

model-test:
	python3 model/test_autotune.py

bit: icebrk.bin
icebrk.bin: $(SRC) constraints/icebreaker.pcf
	mkdir -p build
	yosys -q -p "read_verilog $(SRC); synth_ice40 -top top -json build/top.json"
	nextpnr-ice40 --up5k --package sg48 --freq 12 --json build/top.json --pcf constraints/icebreaker.pcf --asc build/top.asc
	icepack build/top.asc $@

prog: icebrk.bin
	iceprog $<

clean:
	rm -rf build/* icebrk.bin
