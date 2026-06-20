module chacha20 (
    input wire clk,
    input wire rst,
    
    input wire cs,
    input wire we,
    input wire [3:0] addr,
    input wire [31:0] din,
    input wire start,
    
    input wire [31:0] plaintext_in, 
    
    output wire ready,           
    output wire [31:0] ciphertext_out 
);

    wire [31:0] keystream_word;

    chacha20_core my_core (
        .clk(clk),
        .rst(rst),
        .cs(cs),
        .we(we),
        .addr(addr),
        .din(din),
        .start(start),
        .ready(ready),
        .dout(keystream_word)
    );

    assign ciphertext_out = plaintext_in ^ keystream_word;

endmodule