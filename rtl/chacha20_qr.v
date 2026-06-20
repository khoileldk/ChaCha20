module chacha20_qr (
    input wire clk, 
    input wire rst, 
    
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [31:0] c,
    input wire [31:0] d,
    
    output wire [31:0] a_out, 
    output wire [31:0] b_out, 
    output wire [31:0] c_out, 
    output wire [31:0] d_out
);

//  stage 1
wire [31:0] a0, d0, d1, c0, b0, b1;

assign a0 = a + b;
assign d0 = d ^ a0;
assign d1 = {d0[15:0], d0[31:16]};

assign c0 = c + d1;
assign b0 = b ^ c0;
assign b1 = {b0[19:0], b0[31:20]};

// Tang thanh ghi
reg [31:0] a_reg, b_reg, c_reg, d_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        a_reg <= 32'd0;
        b_reg <= 32'd0;
        c_reg <= 32'd0;
        d_reg <= 32'd0;
    end else begin
        a_reg <= a0;
        b_reg <= b1;
        c_reg <= c0;
        d_reg <= d1;
    end
end

// stage 2 
wire [31:0] a1, d2, d3, c1, b2, b3;

assign a1 = a_reg + b_reg;
assign d2 = a1 ^ d_reg;
assign d3 = {d2[23:0], d2[31:24]};

assign c1 = c_reg + d3;
assign b2 = b_reg ^ c1;
assign b3 = {b2[24:0], b2[31:25]};

// dau ra
assign a_out = a1;
assign b_out = b3;
assign c_out = c1;
assign d_out = d3;

endmodule