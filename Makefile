mandelbrot.bin: mandelbrot.asm
	nasm -f bin mandelbrot.asm -o mandelbrot.bin

run: mandelbrot.bin
	qemu-system-i386 mandelbrot.bin

debug: mandelbrot.bin
	qemu-system-i386 mandelbrot.bin -S -s &
	gdb -ix gdbinit_real_mode.txt \
	-ex "target remote localhost:1234" \
	-ex "break *0x7c00" \
	-ex "c"
	killall qemu-system-i386