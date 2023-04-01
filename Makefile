
tron: tron.exe

snake: snake.exe

%.exe: %.mk
	make -C ./obj_dir -f Vtop_$<

PROJF_LIBS = -IProject_F

%.mk: top_%.sv
	verilator -O3 --x-assign fast --x-initial fast --noassert -I.. ${PROJF_LIBS} \
	    -cc $< --exe main_$(basename $@).cpp -o $(basename $@) \
		-CFLAGS "`sdl2-config --cflags`" -LDFLAGS "`sdl2-config --libs`"

clean:
	rm -rf ./obj_dir

.PHONY: clean
