all: test_rom_2.vhd


test_rom_2.vhd: TestRom2.asm AlteraRomTemplate.vhd
	picoasm -i TestRom2.asm -t AlteraRomTemplate.vhd -m test_rom_2
