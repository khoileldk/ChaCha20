module chacha20_core (
  input wire clk,
  input wire rst,
  
  input wire cs,
  input wire we,
  input wire [3:0] addr,
  input wire [31:0] din,
  input wire start,
  
  output reg ready,
  output reg [31:0] dout
);

localparam idle    = 3'd0;
localparam init    = 3'd1;
localparam round   = 3'd2;
localparam fin_add = 3'd3;
localparam done    = 3'd4;

reg [2:0] state, next_state;
reg [4:0] round_count;
reg qr_wait; // Bien cho 1 clk tu tang Pipeline

reg [31:0] state_matrix [0:15];
reg [31:0] init_matrix [0:15];
reg [31:0] keystream_mem [0:15];

wire [31:0] qr_a[0:3], qr_b[0:3], qr_c[0:3], qr_d[0:3];
wire [31:0] qr_a_out[0:3], qr_b_out[0:3], qr_c_out[0:3], qr_d_out[0:3];

chacha20_qr qr_inst_0 (
  .clk(clk), .rst(rst),
  .a(qr_a[0]), .b(qr_b[0]), .c(qr_c[0]), .d(qr_d[0]),
  .a_out(qr_a_out[0]), .b_out(qr_b_out[0]), .c_out(qr_c_out[0]), .d_out(qr_d_out[0])
);
chacha20_qr qr_inst_1 (
  .clk(clk), .rst(rst),
  .a(qr_a[1]), .b(qr_b[1]), .c(qr_c[1]), .d(qr_d[1]),
  .a_out(qr_a_out[1]), .b_out(qr_b_out[1]), .c_out(qr_c_out[1]), .d_out(qr_d_out[1])
);
chacha20_qr qr_inst_2 (
  .clk(clk), .rst(rst),
  .a(qr_a[2]), .b(qr_b[2]), .c(qr_c[2]), .d(qr_d[2]),
  .a_out(qr_a_out[2]), .b_out(qr_b_out[2]), .c_out(qr_c_out[2]), .d_out(qr_d_out[2])
);
chacha20_qr qr_inst_3 (
  .clk(clk), .rst(rst),
  .a(qr_a[3]), .b(qr_b[3]), .c(qr_c[3]), .d(qr_d[3]),
  .a_out(qr_a_out[3]), .b_out(qr_b_out[3]), .c_out(qr_c_out[3]), .d_out(qr_d_out[3])
);

wire is_diag = round_count[0];
assign qr_a[0] = state_matrix[0]; assign qr_b[0] = is_diag ? state_matrix[5] : state_matrix[4];
assign qr_c[0] = is_diag ? state_matrix[10] : state_matrix[8]; assign qr_d[0] = is_diag ? state_matrix[15] : state_matrix[12];

assign qr_a[1] = state_matrix[1]; assign qr_b[1] = is_diag ? state_matrix[6] : state_matrix[5];
assign qr_c[1] = is_diag ? state_matrix[11] : state_matrix[9]; assign qr_d[1] = is_diag ? state_matrix[12] : state_matrix[13];

assign qr_a[2] = state_matrix[2]; assign qr_b[2] = is_diag ? state_matrix[7] : state_matrix[6];
assign qr_c[2] = is_diag ? state_matrix[8] : state_matrix[10]; assign qr_d[2] = is_diag ? state_matrix[13] : state_matrix[14];

assign qr_a[3] = state_matrix[3]; assign qr_b[3] = is_diag ? state_matrix[4] : state_matrix[7];
assign qr_c[3] = is_diag ? state_matrix[9] : state_matrix[11]; assign qr_d[3] = is_diag ? state_matrix[14] : state_matrix[15];

// FSM 
always @(*) begin
    next_state = state;
    case(state)
        idle:    if(start) next_state = init;
        init:    next_state = round;
        round:   if(round_count == 5'd19 && qr_wait == 1'b1) next_state = fin_add;
                 else next_state = round;
        fin_add: next_state = done;
        done:    if(start) next_state = init; else next_state = done;
        default: next_state = idle;
    endcase
end

integer i;
always @(posedge clk) begin
    if (cs && !we && ready) dout <= keystream_mem[addr];
    else dout <= 32'd0;
end

// FSM 
always @(posedge clk or posedge rst) begin
    if(rst) begin
        state <= idle;
        round_count <= 0;
        ready <= 0;
        qr_wait <= 0;
    end else begin
        state <= next_state;
        
        if ((state == idle || state == done) && cs && we) begin
            if (addr >= 4'd4 && addr <= 4'd15) init_matrix[addr] <= din;
        end

        case(state)
            idle: begin
                ready <= 0;
                round_count <= 0;
                qr_wait <= 0;
            end
            
            init: begin
                ready <= 0; 
                round_count <= 0;
                qr_wait <= 0; 
                
                init_matrix[0] <= 32'h61707865; state_matrix[0] <= 32'h61707865;
                init_matrix[1] <= 32'h3320646e; state_matrix[1] <= 32'h3320646e;
                init_matrix[2] <= 32'h79622d32; state_matrix[2] <= 32'h79622d32;
                init_matrix[3] <= 32'h6b206574; state_matrix[3] <= 32'h6b206574;
                
                for (i = 4; i < 16; i = i + 1) state_matrix[i] <= init_matrix[i];
            end
            
            round: begin
                if (qr_wait == 0) begin
                    qr_wait <= 1; // Nhip 1 day du lieu vao thanh ghi pipeline
                end else begin
                    qr_wait <= 0; // Nhip 2 cap nhat ket qua hop le vao ma tran
                    if (!is_diag) begin 
                        state_matrix[0] <= qr_a_out[0]; state_matrix[4] <= qr_b_out[0]; state_matrix[8] <= qr_c_out[0]; state_matrix[12] <= qr_d_out[0];
                        state_matrix[1] <= qr_a_out[1]; state_matrix[5] <= qr_b_out[1]; state_matrix[9] <= qr_c_out[1]; state_matrix[13] <= qr_d_out[1];
                        state_matrix[2] <= qr_a_out[2]; state_matrix[6] <= qr_b_out[2]; state_matrix[10]<= qr_c_out[2]; state_matrix[14] <= qr_d_out[2];
                        state_matrix[3] <= qr_a_out[3]; state_matrix[7] <= qr_b_out[3]; state_matrix[11]<= qr_c_out[3]; state_matrix[15] <= qr_d_out[3];
                    end else begin 
                        state_matrix[0] <= qr_a_out[0]; state_matrix[5] <= qr_b_out[0]; state_matrix[10]<= qr_c_out[0]; state_matrix[15]<= qr_d_out[0];
                        state_matrix[1] <= qr_a_out[1]; state_matrix[6] <= qr_b_out[1]; state_matrix[11]<= qr_c_out[1]; state_matrix[12] <= qr_d_out[1];
                        state_matrix[2] <= qr_a_out[2]; state_matrix[7] <= qr_b_out[2]; state_matrix[8] <= qr_c_out[2]; state_matrix[13] <= qr_d_out[2];
                        state_matrix[3] <= qr_a_out[3]; state_matrix[4] <= qr_b_out[3]; state_matrix[9] <= qr_c_out[3]; state_matrix[14] <= qr_d_out[3];
                    end
                    round_count <= round_count + 1'b1;
                end
            end
            
            fin_add: begin
                for (i = 0; i < 16; i = i + 1) keystream_mem[i] <= state_matrix[i] + init_matrix[i];
            end
            
            done: begin
                if (start) ready <= 0;
                else ready <= 1; 
            end
        endcase
    end
end
endmodule