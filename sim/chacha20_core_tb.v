`timescale 1ns / 1ps
module tb_chacha20_core();
reg          clk;
reg          rst;
reg          start;
reg  [255:0] key;
reg  [95:0]  nounce;
reg  [31:0]  counter;
wire         ready;
wire [511:0] keystream;
    chacha20_core dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .key(key),
        .nounce(nounce),
        .counter(counter),
        .ready(ready),
        .keystream(keystream)
    );
initial begin
    clk = 0;
forever #5 clk = ~clk;
end
initial begin
  //khoi tao
        rst = 1;
        start = 0;
        //cho key nonce ngau nhien
        key     = 256'h1f1e1d1c_1b1a1918_17161514_13121110_0f0e0d0c_0b0a0908_07060504_03020100;
        nounce  = 96'h00000000_4a000000_00000000;
        counter = 32'h00000001;
        //doi vai clk roi tha reset ra
        #20;
        rst = 0;
        
        // bat start
        #10;
        start = 1;
        #10;
        start = 0; // tat start di

        // cho den khi chay xong bat co ready len 1
        wait(ready == 1);
        $display("Keystream thu duoc:");
        $display("%h", keystream);
        // K?t thúc mô ph?ng
        #20;
        $finish;
    end

endmodule
