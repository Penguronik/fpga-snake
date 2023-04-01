# fpga_snake

## Compilation
The instructions below are for compiling this project in a linux environment, if you are on a Windows system you can use [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) to do so.

Requirements:
- C++ (`apt install build-essential`)
- Verilator (`apt install verilator`)
- SDL2 (`apt install libsdl2-dev`)
- Source code (from here)

Run `make snake` to build the snake game or `make tron` to build the tron game. They will be built in the obj_dir directory. Run `./obj_dir/snake` or `./obj_dir/tron` to start the program.

## Simulation
The graphical simulation is done using the SDL2 library which we connect to the cpp simulation code that Verilator generates from our System Verilog code. The implementation of SDL2 with the verilog code is accomplished using the graphics modules and framework made by Will Green as part of the [Project F](https://github.com/projf) github repo. Project F modules are included in this repo in the Project_F folder allowing for the project to be built. There are also aspects of the Project F graphical simulation modules in the tron_main.vs and snake_main.vs files to allow for the graphical simulation.

## State Machine Diagram
Below is the state machine used in the snake game for the main game logic. It is updated once every clock cycle. The different components of the game base their actions on the state machine's state.
![snake state machine](https://user-images.githubusercontent.com/35043400/229241391-4dea9486-44e3-4987-a71d-84befded08e3.png)
###### (In the case of the computer simulation, the "Start Signal" is pressing the space bar key)
