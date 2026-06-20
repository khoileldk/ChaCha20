module chacha20_qr_tb;

reg [31:0] a, b, c, d;
wire [31:0] a_out, b_out, c_out, d_out;

chacha20_qr uut (
    .a(a),
    .b(b),
    .c(c),
    .d(d),
    .a_out(a_out),
    .b_out(b_out),
    .c_out(c_out),
    .d_out(d_out)
);

initial begin
    a = 32'h11111111;
    b = 32'h01020304;
    c = 32'h9b8d6f43;
    d = 32'h01234567;

    #10;

    $display("a_out = %h", a_out);
    $display("b_out = %h", b_out);
    $display("c_out = %h", c_out);
    $display("d_out = %h", d_out);

    $finish;
end

endmodule