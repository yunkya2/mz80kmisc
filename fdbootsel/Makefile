all: fdbootsel.bin

%.bin: %.asm
	zasm -uw $^ $@

clean:
	-rm -rf *.bin *.lst
