# fpga_snake
This is a 2 player snake game made in System Verilog to be synthesized for FPGAs. Also included in this repo is a 2 player tron game. The project also includes the components necessary to run a simulation of this System Verilog code on your computer by following the steps in [Compilation](https://github.com/Penguronik/fpga_snake/edit/main/README.md#compilation). How this graphical simulation is accomplished is explained in [Simulation](https://github.com/Penguronik/fpga_snake/edit/main/README.md#compilation). Also check out the [State Machine Diagram](https://github.com/Penguronik/fpga_snake/edit/main/README.md#compilation) and [Snake Tail Logic](https://github.com/Penguronik/fpga_snake/edit/main/README.md#compilation) for some more info on the logic behind the code.

![fpga-snake-gif](https://user-images.githubusercontent.com/35043400/229264796-87aa0ab5-23ab-4997-a65d-981694742f6d.gif)

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

## Snake Tail Logic
There is an array holding a value of 0 for each spot in the game grid. As the snake's head moves on each game clock cycle, it assigns a value to the spot it was last at equal to it's length variable. Meanwhile, on each game clock cycle the values of all non zero spots in the array of the grid is decreased by one. Finally, on each game clock cycle, all non zero spots in the array are drawn to the screen as part of the snake. This allows the snake to have a tail of a variable length that grows and shrinks as expected. When a pellet is collected, all that needs to be done is incrementing the snake's length variable. 

Below is an example of the values each grid spot holds as the snake head moves:


<img align="left" src="https://user-images.githubusercontent.com/35043400/229265874-7b4c5542-5ccf-4be8-a89b-241ea99ef8fc.png" alt="fpga_gif2110-numbered" width="397" height="313" />
<img align="right" src="https://user-images.githubusercontent.com/35043400/229265876-21b9bf2c-960d-41b3-aaf1-b3965f8b7597.png" alt="fpga_gif2113-numbered" width="397" height="313" />
