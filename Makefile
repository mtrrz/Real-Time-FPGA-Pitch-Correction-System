SRC = rtl/i2s_core.v rtl/top.v

.PHONY: sim sim-loop model-test bit tone octave autotune prog clean
sim:
	mkdir -p build
	iverilog -g2012 -o build/tb tb/tb_i2s.v rtl/i2s_core.v && vvp build/tb
	iverilog -g2012 -o build/tbs tb/tb_shifter.v rtl/shifter.v && vvp build/tbs
	python3 model/gen_vectors.py
	iverilog -g2012 -o build/tba tb/tb_amdf.v rtl/amdf.v && vvp build/tba
	iverilog -g2012 -o build/tbq tb/tb_quant.v rtl/quant.v && vvp build/tbq

# closed loop at real timing (~30 s each)
LOOP = rtl/autotune.v rtl/decim3.v rtl/amdf.v rtl/quant.v rtl/shifter.v
sim-loop:
	mkdir -p build
	iverilog -g2012 -o build/tbl tb/tb_loop.v $(LOOP)
	vvp build/tbl +freq=225 +target=220.0 | grep -E "^in |PASS|FAIL"
	vvp build/tbl +freq=170 +target=174.61 | grep -E "^in |PASS|FAIL"

model-test:
	python3 model/test_autotune.py
	python3 model/test_quant.py

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

octave: icebrk_octave.bin icebrk_autotune.bin
icebrk_octave.bin: rtl/i2s_core.v rtl/shifter.v rtl/top_octave.v constraints/icebreaker.pcf
	mkdir -p build
	yosys -q -p "read_verilog rtl/i2s_core.v rtl/shifter.v rtl/top_octave.v; synth_ice40 -top top_octave -json build/octave.json"
	nextpnr-ice40 --up5k --package sg48 --freq 25.5 --json build/octave.json --pcf constraints/icebreaker.pcf --asc build/octave.asc
	icepack build/octave.asc $@

autotune: icebrk_autotune.bin
icebrk_autotune.bin: rtl/i2s_core.v $(LOOP) rtl/top_autotune.v rtl/bq.hex rtl/rr.hex constraints/icebreaker.pcf
	mkdir -p build
	yosys -q -p "read_verilog rtl/i2s_core.v $(LOOP) rtl/top_autotune.v; synth_ice40 -top top_autotune -json build/autotune.json"
	nextpnr-ice40 --up5k --package sg48 --freq 25.5 --json build/autotune.json --pcf constraints/icebreaker.pcf --asc build/autotune.asc
	icepack build/autotune.asc $@

prog: icebrk.bin
	iceprog $<

clean:
	rm -rf build/* icebrk.bin icebrk_tone.bin icebrk_octave.bin icebrk_autotune.bin
