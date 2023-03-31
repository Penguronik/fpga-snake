
snake: snake.exe

%.exe: %.mk
	make -C ./obj_dir -f Vtop_$<

%.mk: top_%.sv
	verilator -O3 --x-assign fast --x-initial fast --noassert \
	    -cc $< --exe main_$(basename $@).cpp -o $(basename $@) \
		-CFLAGS "`sdl2-config --cflags`" -LDFLAGS "`sdl2-config --libs`"

all: pong

clean:
	rm -rf ./obj_dir

.PHONY: all clean
