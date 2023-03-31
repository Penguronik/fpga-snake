/*
 #### TO DO:
 rename clk_game to just game, as it is not officially a clock
 create a clock version of game called clk_game and use it for the existing debouncer
 rename the signals with _next in them to just have an intermediate variable in between and the one you use be called without _next
 if you create a frame clock change the filter random number logic use that clock as well
 whats stopping you from using the clock version of game as the clock instead of clk_pix?
 move snake collision conditionals into if (clk_game) as well
 create a singular lFSR module that handles most width cases
 make PELLET_INC increase feel more natural?
*/

/* When changing resolution or SNAKE_SIZE, update the following when necessary:
	CORDW, H_RES, V_RES, SNAKE_SIZE, H_WIDTH, V_WIDTH, H_SIZE, V_SIZE, GRIDW, LFSR modules
*/

`default_nettype none
`timescale 1ns / 1ps

module top_snake #(parameter CORDW=10) // coordinate width, set the number of bits the coordinates have to be represented by in the current resolution
(
    input  wire logic clk_pix,             // pixel clock
    input  wire logic sim_rst,             // sim reset
    input  wire logic btn_start,           // start button
    input  wire logic btn_right_p1,        // right button for player 1
    input  wire logic btn_left_p1,         // left button for player 1
    input  wire logic btn_up_p1,           // up button for player 1
    input  wire logic btn_down_p1,         // down button for player 1
    input  wire logic btn_right_p2,        // right button for player 2
    input  wire logic btn_left_p2,         // left button for player 2
    input  wire logic btn_up_p2,           // up button for player 2
    input  wire logic btn_down_p2,         // down button for player 2
    output      logic [CORDW-1:0] sdl_sx,  // horizontal SDL position
    output      logic [CORDW-1:0] sdl_sy,  // vertical SDL position
    output      logic sdl_de,              // data enable (low in blanking interval)
    output      logic [7:0] sdl_r,         // 8-bit red
    output      logic [7:0] sdl_g,         // 8-bit green
    output      logic [7:0] sdl_b          // 8-bit blue
    );

    // gameplay parameters
    localparam WIN         =  9;  // score needed to win a game (max 9)
    localparam SNAKE_SIZE  =  8;  // width and legth of a single snake square in pixels, has to be a power of 2 that divides the H_RES and V_RES
    // When changing the SNAKE_SIZE make sure to also change the H_SIZE, V_SIZE, and GRIDW params
    localparam INIT_DIST   = 40;  // Initial distance of snake from the wall
    localparam I_SPEED	   =  2;  // inverse speed modifier (higher means slower)
    localparam INIT_LENGTH =  3;  // Initial length of snake
    localparam PELLET_INC  =  3;  // The incremement that the snake's length increases by when a pellet is collected
    
    // clock
    logic [3:0] cycle;
    logic clk_game;
    
    // temp for loop iterators
    logic [CORDW-1:0] x_1, x_2;
    logic [CORDW-1:0] y_1, y_2;
    
    // display sync signals and coordinates
    logic [CORDW-1:0] sx, sy;
    logic de;
    simple_480p display_inst (
        .clk_pix,
        .rst_pix(sim_rst),
        .sx,
        .sy,
        /* verilator lint_off PINCONNECTEMPTY */
        .hsync(),
        .vsync(),
        /* verilator lint_on PINCONNECTEMPTY */
        .de
    );

    // screen dimensions (must match display_inst)
    localparam H_RES = 640;  // horizontal screen resolution
    localparam V_RES = 480;  // vertical screen resolution
    localparam H_WIDTH = 7; // number of pixels needed to represent the horizontal size, used for array lookups
    localparam V_WIDTH = 6; // number of pixels needed to represent the vertical size, used for array lookups
    localparam [CORDW-1:0] H_SIZE = 80; // resolution divided by snake size (H_RES/SNAKE_SIZE)
    localparam [CORDW-1:0] V_SIZE = 60; // resolution divided by snake size (V_RES/SNAKE_SIZE)
    localparam GRIDW  = 12; // grid width, set the number of bits needed to represent the entire H_SIZE*V_SIZE grid of SNAKE_SIZE*SNAKE_SIZE squares

    logic frame;  // high for one clock tick at the start of vertical blanking
    always_comb frame = (sy == V_RES && sx == 0);

    // scores
    logic [3:0] score_p1;  // left-side score
    logic [3:0] score_p2;  // right-side score

    // drawing signals
    logic snake_p1_head, snake_p2_head, pellet, snake_p1, snake_p2;

    // snake head properties
    logic [CORDW-1:0] snake_p1_x, snake_p1_y, snake_p2_x, snake_p2_y;
    enum {UP, DOWN, LEFT, RIGHT} snake_p1_dir, snake_p2_dir;
    logic [GRIDW-1:0] snake_p1_length, snake_p2_length;
    logic coll_p1, coll_p2;
    
    // snake body properties
    logic [GRIDW-1:0] snake_p1_body [H_SIZE-1:0] [V_SIZE-1:0];
    logic [GRIDW-1:0] snake_p2_body [H_SIZE-1:0] [V_SIZE-1:0]; // H_SIZE by V_SIZE array storing a value for each spot. The value stored on each spot represents how many game clock cycles until that spot is no longer a part of the snake body
    
    // pellet properties
    logic [CORDW-1:0] pellet_rand_x, pellet_x_filter, pellet_x;
    logic [CORDW-1:0] pellet_rand_y, pellet_y_filter, pellet_y;
    logic pellet_collected;

    // debounce buttons
    logic sig_start, 
    	  sig_right_p1, sig_left_p1, sig_up_p1, sig_down_p1, 
		  sig_right_p2, sig_left_p2, sig_up_p2, sig_down_p2;
    // buffer until clock cycle of buttons
    logic sig_right_p1_next, sig_left_p1_next, sig_up_p1_next, sig_down_p1_next, 
    	  sig_right_p2_next, sig_left_p2_next, sig_up_p2_next, sig_down_p2_next;
    debounce deb_start (.clk(clk_pix), .in(btn_start), .out(), .ondn(), .onup(sig_start));
    debounce deb_right_p1 (.clk(clk_pix), .in(btn_right_p1), .out(sig_right_p1), .ondn(), .onup());
    debounce deb_left_p1 (.clk(clk_pix), .in(btn_left_p1), .out(sig_left_p1), .ondn(), .onup());
    debounce deb_up_p1 (.clk(clk_pix), .in(btn_up_p1), .out(sig_up_p1), .ondn(), .onup());
    debounce deb_down_p1 (.clk(clk_pix), .in(btn_down_p1), .out(sig_down_p1), .ondn(), .onup());
    debounce deb_right_p2 (.clk(clk_pix), .in(btn_right_p2), .out(sig_right_p2), .ondn(), .onup());
    debounce deb_left_p2 (.clk(clk_pix), .in(btn_left_p2), .out(sig_left_p2), .ondn(), .onup());
    debounce deb_up_p2 (.clk(clk_pix), .in(btn_up_p2), .out(sig_up_p2), .ondn(), .onup());
    debounce deb_down_p2 (.clk(clk_pix), .in(btn_down_p2), .out(sig_down_p2), .ondn(), .onup());

	// slow down game clock to once every *I_SPEED* frames
	always_ff @(posedge clk_pix) begin
		if (frame) begin
			if (cycle < I_SPEED) begin // cycle through for *I_SPEED* frames
				clk_game <= 0;
				cycle <= cycle + 1;
			end else begin // and set clk_game to true for a single clk_pix cycle
				clk_game <= 1;
				cycle <= 0;
			end
		end else clk_game <= 0; // ensure clk_game is active for only a single clk_pix cycle
	end
	
	// buffer until clock cycle of game
    input_buffer buff_right_p1 (.clk(clk_game), .signal(sig_right_p1), .out(sig_right_p1_next));
	input_buffer buff_left_p1 (.clk(clk_game), .signal(sig_left_p1), .out(sig_left_p1_next));
	input_buffer buff_up_p1 (.clk(clk_game), .signal(sig_up_p1), .out(sig_up_p1_next));
	input_buffer buff_down_p1 (.clk(clk_game), .signal(sig_down_p1), .out(sig_down_p1_next));
	input_buffer buff_right_p2 (.clk(clk_game), .signal(sig_right_p2), .out(sig_right_p2_next));
	input_buffer buff_left_p2 (.clk(clk_game), .signal(sig_left_p2), .out(sig_left_p2_next));
	input_buffer buff_up_p2 (.clk(clk_game), .signal(sig_up_p2), .out(sig_up_p2_next));
	input_buffer buff_down_p2 (.clk(clk_game), .signal(sig_down_p2), .out(sig_down_p2_next));
	
	// pseudo-random number generator for pellet placement, the LSFR bit width needs to be match H_WIDTH and V_WIDTH
	LFSR_7bit pellet_rng_x (.clk(clk_pix), .rst(sim_rst), .LFSR_Data(pellet_rand_x[H_WIDTH-1:0]));
	LFSR_6bit pellet_rng_y (.clk(clk_pix), .rst(sim_rst), .LFSR_Data(pellet_rand_y[V_WIDTH-1:0]));
	
	// filter random number
	always_ff @(posedge clk_pix) begin
		if ((pellet_rand_x < H_SIZE) && (pellet_rand_y < V_SIZE)) begin
			if ((snake_p1_body [pellet_rand_x[H_WIDTH-1:0]] [pellet_rand_y[V_WIDTH-1:0]] == 0) && (snake_p2_body [pellet_rand_x[H_WIDTH-1:0]] [pellet_rand_y[V_WIDTH-1:0]] == 0)) begin
				pellet_x_filter <= pellet_rand_x;
				pellet_y_filter <= pellet_rand_y;
			end
		end
	end

    // game state
    enum {NEW_GAME, POSITION, READY, POINT, END_GAME, PLAY} state, state_next;
    always_comb begin
    	case (state)
    		NEW_GAME: state_next = POSITION;
   	    	POSITION: state_next = READY;
   	    	READY: state_next = sig_start ? PLAY : READY;
   	    	POINT: state_next = sig_start ? POSITION : POINT;
   	    	END_GAME: state_next = sig_start ? NEW_GAME : END_GAME;
   	    	PLAY: begin
   	    		if (coll_p1 || coll_p2) begin
   	    	    	if ((score_p1 == WIN) || (score_p2 == WIN)) state_next = END_GAME;
   	    	    	else state_next = POINT;
    	    	end else state_next = PLAY;
	    	end
	    	default: state_next = NEW_GAME;
        endcase
        if (sim_rst) state_next = NEW_GAME;
    end
    
    always_ff @(posedge clk_pix) begin
    	state <= state_next;
	end
	
	// player 1 control
	always_ff @(posedge clk_pix) begin
		case (state)
			NEW_GAME: score_p1 <= 0;
			POSITION: begin
				snake_p1_x <= INIT_DIST;
				snake_p1_y <= (V_RES - SNAKE_SIZE)/2 + SNAKE_SIZE/2;
				snake_p1_dir <= RIGHT;
				snake_p1_length <= INIT_LENGTH;
				for (x_1 = 0; x_1 < H_SIZE; x_1 = x_1 + 1) begin
					for (y_1 = 0; y_1 < V_SIZE; y_1 = y_1 + 1) begin
						snake_p1_body [x_1[H_WIDTH-1:0]] [y_1[V_WIDTH-1:0]] = 0; // blocking assignment used as delayed assignment to arrays inside for loops is unsupported and this accomplishes the same thing
					end
				end
				coll_p1 <= 0;
			end
			PLAY: begin
				if (clk_game) begin
					if (sig_right_p1_next && (snake_p1_dir != LEFT)) begin
						snake_p1_dir <= RIGHT;
					end else if (sig_left_p1_next && (snake_p1_dir != RIGHT)) begin
						snake_p1_dir <= LEFT;
					end else if (sig_up_p1_next && (snake_p1_dir != DOWN)) begin
						snake_p1_dir <= UP;
					end else if (sig_down_p1_next && (snake_p1_dir != UP)) begin
						snake_p1_dir <= DOWN;
					end
					
					case (snake_p1_dir)
						UP: begin
							if (snake_p1_y < SNAKE_SIZE) begin
		                        score_p2 <= score_p2 + 1;
		                        coll_p1 <= 1;
		                    end else snake_p1_y <= snake_p1_y - SNAKE_SIZE;
	                    end
						DOWN: begin
							if (snake_p1_y + SNAKE_SIZE >= V_RES-1) begin
		                        score_p2 <= score_p2 + 1;
		                        coll_p1 <= 1;
		                    end else snake_p1_y <= snake_p1_y + SNAKE_SIZE;
	                    end
						LEFT: begin
							if (snake_p1_x < SNAKE_SIZE) begin
		                        score_p2 <= score_p2 + 1;
		                        coll_p1 <= 1;
		                    end else snake_p1_x <= snake_p1_x - SNAKE_SIZE;
	                    end
						RIGHT: begin
							if (snake_p1_x + SNAKE_SIZE >= H_RES-1) begin
		                        score_p2 <= score_p2 + 1;
		                        coll_p1 <= 1;
		                    end else snake_p1_x <= snake_p1_x + SNAKE_SIZE;
	                    end
                    endcase
                    snake_p1_body [snake_p1_x/SNAKE_SIZE] [snake_p1_y/SNAKE_SIZE] <= snake_p1_length;
                    
                    if ((pellet_x == snake_p1_x/SNAKE_SIZE) && (pellet_y == snake_p1_y/SNAKE_SIZE)) begin
                    	pellet_collected <= 1;
                    	snake_p1_length <= snake_p1_length + PELLET_INC;
                	end else begin
                		for (x_1 = 0; x_1 < H_SIZE; x_1 = x_1 + 1) begin
							for (y_1 = 0; y_1 < V_SIZE; y_1 = y_1 + 1) begin
								if (snake_p1_body [x_1[H_WIDTH-1:0]] [y_1[V_WIDTH-1:0]] > 0) snake_p1_body [x_1[H_WIDTH-1:0]] [y_1[V_WIDTH-1:0]] = snake_p1_body [x_1[H_WIDTH-1:0]] [y_1[V_WIDTH-1:0]] - 1;
							end
						end
					end
					
				end
				
				if ((!coll_p1) && ((snake_p1_head && snake_p1) || (snake_p1_head && snake_p2) || (snake_p1_head && snake_p2_head))) begin
					score_p2 <= score_p2 + 1;
					coll_p1 <= 1;
				end
				
			end
		endcase
		
	end
	
	// player 2 control
	always_ff @(posedge clk_pix) begin
		case (state)
			NEW_GAME: score_p2 <= 0;
			POSITION: begin
				snake_p2_x <= H_RES - INIT_DIST;
				snake_p2_y <= (V_RES - SNAKE_SIZE)/2 + SNAKE_SIZE/2;
				snake_p2_dir <= LEFT;
				snake_p2_length <= INIT_LENGTH;
				for (x_2 = 0; x_2 < H_SIZE; x_2 = x_2 + 1) begin
					for (y_2 = 0; y_2 < V_SIZE; y_2 = y_2 + 1) begin
						snake_p2_body [x_2[H_WIDTH-1:0]] [y_2[V_WIDTH-1:0]] = 0; // blocking assignment used as delayed assignment to arrays inside for loops is unsupported and this accomplishes the same thing
					end
				end
				coll_p2 <= 0;
			end
			PLAY: begin
				if (clk_game) begin
					if (sig_right_p2_next && (snake_p2_dir != LEFT)) begin
						snake_p2_dir <= RIGHT;
					end else if (sig_left_p2_next && (snake_p2_dir != RIGHT)) begin
						snake_p2_dir <= LEFT;
					end else if (sig_up_p2_next && (snake_p2_dir != DOWN)) begin
						snake_p2_dir <= UP;
					end else if (sig_down_p2_next && (snake_p2_dir != UP)) begin
						snake_p2_dir <= DOWN;
					end
					
					case (snake_p2_dir)
						UP: begin
							if (snake_p2_y < SNAKE_SIZE) begin
		                        score_p1 <= score_p1 + 1;
		                        coll_p2 <= 1;
		                    end else snake_p2_y <= snake_p2_y - SNAKE_SIZE;
	                    end
						DOWN: begin
							if (snake_p2_y + SNAKE_SIZE >= V_RES-1) begin
		                        score_p1 <= score_p1 + 1;
		                        coll_p2 <= 1;
		                    end else snake_p2_y <= snake_p2_y + SNAKE_SIZE;
	                    end
						LEFT: begin
							if (snake_p2_x < SNAKE_SIZE) begin
		                        score_p1 <= score_p1 + 1;
		                        coll_p2 <= 1;
		                    end else snake_p2_x <= snake_p2_x - SNAKE_SIZE;
	                    end
						RIGHT: begin
							if (snake_p2_x + SNAKE_SIZE >= H_RES-1) begin
		                        score_p1 <= score_p1 + 1;
		                        coll_p2 <= 1;
		                    end else snake_p2_x <= snake_p2_x + SNAKE_SIZE;
	                    end
                    endcase
                    snake_p2_body [snake_p2_x/SNAKE_SIZE] [snake_p2_y/SNAKE_SIZE] <= snake_p2_length;
                    
                    if ((pellet_x == snake_p2_x/SNAKE_SIZE) && (pellet_y == snake_p2_y/SNAKE_SIZE)) begin
                    	pellet_collected <= 1;
                    	snake_p2_length <= snake_p2_length + PELLET_INC;
                	end else begin
                		for (x_2 = 0; x_2 < H_SIZE; x_2 = x_2 + 1) begin
							for (y_2 = 0; y_2 < V_SIZE; y_2 = y_2 + 1) begin
								if (snake_p2_body [x_2[H_WIDTH-1:0]] [y_2[V_WIDTH-1:0]] > 0) snake_p2_body [x_2[H_WIDTH-1:0]] [y_2[V_WIDTH-1:0]] = snake_p2_body [x_2[H_WIDTH-1:0]] [y_2[V_WIDTH-1:0]] - 1;
							end
						end
					end
                    
				end
				
				if ((!coll_p2) && ((snake_p2_head && snake_p2) || (snake_p2_head && snake_p1) || (snake_p2_head && snake_p1_head))) begin
					score_p1 <= score_p1 + 1;
					coll_p2 <= 1;
				end
				
				/*if ((!pellet_collected) && (pellet && snake_p2_head)) begin
					pellet_collected <= 1;
					snake_p2_length <= snake_p2_length + 1;
					for (x_2 = 0; x_2 < H_SIZE; x_2 = x_2 + 1) begin
						for (y_2 = 0; y_2 < V_SIZE; y_2 = y_2 + 1) begin
							if (snake_p2_body > 0) snake_p2_body [x_2] [y_2] = snake_p2_body [x_2] [y_2] + 1; // blocking assignment used as delayed assignment to arrays inside for loops is unsupported and this accomplishes the same thing			 
						end
					end
				end*/ // this breaks the code, have to fix this somehow, I think including it in the clk_game section is a good idea for now
				
			end
		endcase
		
	end
	
	// pellet logic
	always_ff @(posedge clk_pix) begin
		case (state)
			POSITION: begin
				pellet_collected <= 1;
				pellet_x <= 10'b1111111111; // set to value outside of grid
				pellet_y <= 10'b1111111111; // set to value outside of grid
			end
			
			PLAY: begin
				if (pellet_collected) begin
					pellet_x <= pellet_x_filter;
					pellet_y <= pellet_y_filter;
					pellet_collected <= 0;
				end
			end
		endcase
	end
	
	// activate draw signals
	always_comb begin
		snake_p1_head = (sx >= snake_p1_x) && (sx < snake_p1_x + SNAKE_SIZE)
						&& (sy >= snake_p1_y) && (sy < snake_p1_y + SNAKE_SIZE);
						
		snake_p1 = snake_p1_body [sx/SNAKE_SIZE] [sy/SNAKE_SIZE] > 0;
		
		snake_p2_head = (sx >= snake_p2_x) && (sx < snake_p2_x + SNAKE_SIZE)
						&& (sy >= snake_p2_y) && (sy < snake_p2_y + SNAKE_SIZE);
						
		snake_p2 = snake_p2_body [sx/SNAKE_SIZE] [sy/SNAKE_SIZE] > 0;
		
		pellet = (sx/SNAKE_SIZE == pellet_x) && (sy/SNAKE_SIZE == pellet_y);
		
	end

    // draw the score
    logic pix_score;  // pixel of score char
    simple_score simple_score_inst (
        .clk_pix,
        .sx,
        .sy,
        .score_l(score_p1),
        .score_r(score_p2),
        .pix(pix_score)
    );

    // paint colour
    logic [3:0] paint_r, paint_g, paint_b;
    always_comb begin
        if (pix_score) {paint_r, paint_g, paint_b} = 12'hF30;  // score
        else if ((snake_p1_head || snake_p1) && (snake_p2_head || snake_p2)) {paint_r, paint_g, paint_b} = 12'hF00; // snake 1 & 2 collision
        else if (snake_p1_head || snake_p1) {paint_r, paint_g, paint_b} = 12'h0F0;  // snake 1
        else if (snake_p2_head || snake_p2) {paint_r, paint_g, paint_b} = 12'hF0F;  // snake 2
        else if (pellet) {paint_r, paint_g, paint_b} = 12'hFC0;  // pellet
        else {paint_r, paint_g, paint_b} = 12'h200;  // background
    end

    // display colour: paint colour but black in blanking interval
    logic [3:0] display_r, display_g, display_b;
    always_comb begin
        display_r = (de) ? paint_r : 4'h0;
        display_g = (de) ? paint_g : 4'h0;
        display_b = (de) ? paint_b : 4'h0;
    end

    // SDL output (8 bits per colour channel)
    always_ff @(posedge clk_pix) begin
        sdl_sx <= sx;
        sdl_sy <= sy;
        sdl_de <= de;
        sdl_r <= {2{display_r}};
        sdl_g <= {2{display_g}};
        sdl_b <= {2{display_b}};
    end
endmodule

module input_buffer (
	input wire logic clk,
	input wire logic signal,
	output wire logic out
	);
	// input buffering to only take the input for one clock cycle
	logic signal_active;
	always_ff @(posedge clk) begin
		if (signal_active) begin
			out <= 0;
			signal_active <= signal;
		end else begin
			out <= signal;
			signal_active <= signal;
		end
	end
endmodule

module LFSR_7bit // linear feedback shift register of 7 bit width
	(
	input clk,
	input rst,
	output [6:0] LFSR_Data
	);
 
	logic [7:1] LFSR = 0;
	logic       XNOR;
 
	always_ff @(posedge clk) begin
		if (rst) LFSR <= 7'b1000001; // on reset set seed
		else LFSR <= {LFSR[6:1], XNOR}; // move down one bit to the left and add the XNOR bit to the right
	end

	// taps from https://docs.xilinx.com/v/u/en-US/xapp210
	always_comb begin
		XNOR = LFSR[7] ^~ LFSR[6]; // this configuration allows for the most unique and "random" outputs
	end
 
	assign LFSR_Data = LFSR[7:1];
 
endmodule

module LFSR_6bit // linear feedback shift register of 6 bit width
	(
	input clk,
	input rst,
	output [5:0] LFSR_Data
	);
 
	logic [6:1] LFSR = 0;
	logic       XNOR;
 
	always_ff @(posedge clk) begin
		if (rst) LFSR <= 6'b100001; // on reset set seed
		else LFSR <= {LFSR[5:1], XNOR}; // move down one bit to the left and add the XNOR bit to the right
	end

	// taps from https://docs.xilinx.com/v/u/en-US/xapp210
	always_comb begin
		XNOR = LFSR[6] ^~ LFSR[5]; // this configuration allows for the most unique and "random" outputs
	end
 
	assign LFSR_Data = LFSR[6:1];
 
endmodule
/*
module LFSR_5bit // linear feedback shift register of 5 bit width
	(
	input clk,
	input rst,
	output [4:0] LFSR_Data
	);
 
	logic [5:1] LFSR = 0;
	logic       XNOR;
 
	always_ff @(posedge clk) begin
		if (rst) LFSR <= 5'b10001; // on reset set seed
		else LFSR <= {LFSR[4:1], XNOR}; // move down one bit to the left and add the XNOR bit to the right
	end

	// taps from https://docs.xilinx.com/v/u/en-US/xapp210
	always_comb begin
		XNOR = LFSR[5] ^~ LFSR[3]; // this configuration allows for the most unique and "random" outputs
	end
 
	assign LFSR_Data = LFSR[5:1];
 
endmodule
*/
