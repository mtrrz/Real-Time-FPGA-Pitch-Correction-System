SRC = rtl/i2s_core.v rtl/top.v

.PHONY: sim model-test bit tone octave prog clean
sim:
	mkdir -p build
	iverilog -g2012 -o build/tb tb/tb_i2s.v rtl/i2s_core.v && vvp build/tb
	iverilog -g2012 -o build/tbs tb/tb_shifter.v rtl/shifter.v && vvp build/tbs
	python3 model/gen_vectors.py
	iverilog -g2012 -o build/tba tb/tb_amdf.v rtl/amdf.v && vvp build/tba

model-test:
	python3 model/test_autotune.py

bit: icebrk.bin
icebrk.bin: $(SRC) constraints/icebreaker.pcf
	mkdir -p build
	yosys -q -p "read_verilog $(SRC); synth_ice40 -top top -json build/top.json"
	nextpnr-ice40 --up5k --package sg48 --freq 25.5 --json build/top.json --pcf constraints/icebreaker.pcf --asc build/top.asc
	icepack build/top.asc $@

tone: icebrk_tone.bin
icebrk_tone.bin: rtl/i2s_core.v rtl/top_tone.v constraints/icebreaker.pcf
	mkdir -p build
	yosys -q -p "read_verilog rtl/i2s_core.v rtl/top_tone.v; synth_ice40 -top top_tone -json build/tone.json"
	nextpnr-ice40 --up5k --package sg48 --freq 25.5 --json build/tone.json --pcf constraints/icebreaker.pcf --asc build/tone.asc
	icepack build/tone.asc $@

octave: icebrk_octave.bin
icebrk_octave.bin: rtl/i2s_core.v rtl/shifter.v rtl/top_octave.v constraints/icebreaker.pcf
	mkdir -p build
	yosys -q -p "read_verilog rtl/i2s_core.v rtl/shifter.v rtl/top_octave.v; synth_ice40 -top top_octave -json build/octave.json"
	nextpnr-ice40 --up5k --package sg48 --freq 25.5 --json build/octave.json --pcf constraints/icebreaker.pcf --asc build/octave.asc
	icepack build/octave.asc $@

prog: icebrk.bin
	iceprog $<

clean:
	rm -rf build/* icebrk.bin icebrk_tone.bin icebrk_octave.bin
