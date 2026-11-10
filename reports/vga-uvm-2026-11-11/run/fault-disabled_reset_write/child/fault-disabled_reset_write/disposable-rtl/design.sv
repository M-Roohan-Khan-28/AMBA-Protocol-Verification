module vga_controller_sram(

    input  logic       clk,
    input  logic       reset,
    input  logic       sram_we,
    input  logic [12:0] sram_addr,
    input  logic [7:0] sram_data_in,

    output logic       hsync,
    output logic       vsync,
    output logic       active_video,
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue

);

logic [1:0] clock_divider;
logic [9:0] h_count;
logic [9:0] v_count;
logic [6:0] frame_x;
logic [5:0] frame_y;
logic [12:0] read_address;
logic [7:0] pixel_data;
logic [7:0] sram [0:4799];

integer x;
integer y;

initial
begin

    for(y = 0; y < 60; y = y + 1)
    begin
        for(x = 0; x < 80; x = x + 1)
        begin

            if(x < 27)
                sram[y*80 + x] = 8'b111_000_00;
            else if(x < 54)
                sram[y*80 + x] = 8'b000_111_00;
            else
                sram[y*80 + x] = 8'b000_000_11;

            // Unique DIL signature stored inside SRAM
            if((y >= 24 && y <= 34) &&
               ((x == 28) || (y == 24 && x >= 28 && x <= 33) ||
                (y == 34 && x >= 28 && x <= 33) ||
                (x == 34 && y >= 25 && y <= 33)))
                sram[y*80 + x] = 8'hFF;

            if((y >= 24 && y <= 34) &&
               ((y == 24 && x >= 38 && x <= 42) ||
                (y == 34 && x >= 38 && x <= 42) ||
                (x == 40)))
                sram[y*80 + x] = 8'hFF;

            if((y >= 24 && y <= 34) &&
               ((x == 46) || (y == 34 && x >= 46 && x <= 52)))
                sram[y*80 + x] = 8'hFF;

        end
    end

end

// This initialized framebuffer also has an initial block, so use a plain
// clocked process rather than always_ff's single-writer restriction.
always @(posedge clk)
begin

    // The 13-bit write address can exceed the 4,800-byte framebuffer.
    // Ignore out-of-range requests; no wrapped or unknown-index write.
    if(sram_we && !reset && sram_addr < 13'd4800)
        sram[sram_addr] <= sram_data_in;

end

always_ff @(posedge clk or posedge reset)
begin

    if(reset)
    begin
        clock_divider <= 2'd0;
        h_count       <= 10'd0;
        v_count       <= 10'd0;
    end
    else
    begin

        clock_divider <= clock_divider + 1'b1;

        if(clock_divider == 2'd3)
        begin

            if(h_count == 10'd799)
            begin
                h_count <= 10'd0;

                if(v_count == 10'd524)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 1'b1;
            end
            else
                h_count <= h_count + 1'b1;

        end

    end

end

always_comb
begin

    hsync = ~((h_count >= 10'd656) && (h_count < 10'd752));
    vsync = ~((v_count >= 10'd490) && (v_count < 10'd492));

    active_video = (h_count < 10'd640) && (v_count < 10'd480);

    frame_x = h_count[9:3];
    frame_y = v_count[8:3];
    read_address = frame_y * 13'd80 + frame_x;

    if(active_video)
        pixel_data = sram[read_address];
    else
        pixel_data = 8'h00;

    if(active_video)
    begin
        red   = {pixel_data[7:5], pixel_data[7]};
        green = {pixel_data[4:2], pixel_data[4]};
        blue  = {pixel_data[1:0], pixel_data[1:0]};
    end
    else
    begin
        red   = 4'h0;
        green = 4'h0;
        blue  = 4'h0;
    end

end

endmodule
