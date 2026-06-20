`timescale 1ns / 1ps

module chacha20_tb();

    reg         clk;
    reg         rst;
    
    reg         cs;
    reg         we;
    reg  [3:0]  addr;
    reg  [31:0] din;
    reg         start;
    reg  [31:0] plaintext_in;
    
    wire        ready;
    wire [31:0] ciphertext_out;

    // Cac bien dem so luong testcase
    integer pass_count;
    integer fail_count;
    integer total_tests;

    chacha20 dut (
        .clk(clk),
        .rst(rst),
        .cs(cs),
        .we(we),
        .addr(addr),
        .din(din),
        .start(start),
        .plaintext_in(plaintext_in),
        .ready(ready),
        .ciphertext_out(ciphertext_out)
    );

    // Tao clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Task ho tro multiblock va check
    task run_multiblock_with_check;
        input [255:0]  t_key;
        input [95:0]   t_nonce;
        input [31:0]   t_start_counter;
        input [1023:0] t_plaintext;       // Toi da 2 block
        input [1023:0] t_expected_cipher; // Hash/Cipher ki vong
        input integer  num_blocks;        // So block 1 hoac 2
        
        reg [1023:0] actual_ciphertext;
        reg [31:0]   current_counter;
        reg          is_match;
        integer b, i;
    begin
        total_tests = total_tests + 1;
        actual_ciphertext = 1024'b0; // Xoa rac bo nho truoc khi chay
        current_counter = t_start_counter;
        
        @(posedge clk);
        
        // Nap key va nonce
        cs = 1; we = 1;
        for (i = 0; i < 8; i = i + 1) begin
            addr = 4 + i;
            din = t_key[i*32 +: 32];
            @(posedge clk);
        end
        for (i = 0; i < 3; i = i + 1) begin
            addr = 13 + i;
            din = t_nonce[i*32 +: 32];
            @(posedge clk);
        end
        
        // Vong lap xu li tung block
        for (b = 0; b < num_blocks; b = b + 1) begin
            // Nap counter
            cs = 1; we = 1;
            addr = 12; 
            din = current_counter; 
            @(posedge clk);
            
            // Kich hoat FSM
            cs = 0; we = 0;
            @(posedge clk); start = 1;
            @(posedge clk); start = 0;

            // Doi tinh toan
            wait(ready == 0);
            wait(ready == 1);
            
            // Doc 512 bit dua Plaintext vao va doc Ciphertext ra
            @(posedge clk);
            cs = 1; we = 0;
            for (i = 0; i < 16; i = i + 1) begin
                addr = i;
                plaintext_in = t_plaintext[(b*512 + i*32) +: 32];
                
                @(posedge clk); #1;
                actual_ciphertext[(b*512 + i*32) +: 32] = ciphertext_out;
            end
            cs = 0;
            
            // tang counter cho block tiep theo 
            current_counter = current_counter + 1;
        end

        // So sanh ket qua 
        if (num_blocks == 1)
            is_match = (actual_ciphertext[511:0] === t_expected_cipher[511:0]);
        else
            is_match = (actual_ciphertext === t_expected_cipher);

        // In ra thong bao Pass/Fail
        $display("--------------------------------------------------");
        $display("TESTCASE %0d (%0d BLOCKS)", total_tests, num_blocks);
        if (is_match) begin
            pass_count = pass_count + 1;
            $display("[PASS] Ciphertext matches expected hash.");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] Mismatch detected!");
            if (num_blocks == 1) begin
                $display("       Expected: %h", t_expected_cipher[511:0]);
                $display("       Actual  : %h", actual_ciphertext[511:0]);
            end else begin
                $display("       Expected: %h", t_expected_cipher);
                $display("       Actual  : %h", actual_ciphertext);
            end
        end
        @(posedge clk);
    end
    endtask

    // Luong chay testcase
    initial begin
        rst = 1; cs = 0; we = 0; addr = 0; din = 0; start = 0; plaintext_in = 0;
        pass_count = 0; fail_count = 0; total_tests = 0;
        #20 rst = 0;

        // --- TESTCASE 1: Chay 1 Block (512-bit) ---
        run_multiblock_with_check(
            256'h8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7e5d6c3a0f1e8b2c9f4a7d, // Key
            96'h2d8b7e6c5a490de1b8c2f7a3,                                              // Nonce
            32'h00000000,                                                                // Counter
            1024'ha1bae1676e2075aac3696b202c686e89bbe16220676e9bbbe1b0c66220bfbae16420bac36863207499bbe16d20a0c36c206e91bbe176206ea8c34d20bfbae144,                                                                     // Plaintext 
            1024'ha1e26cb653786f050591bbac993e8a68ec1935e3a863fc0ebcb0847cd91a9daf3d6dc2d79f3fced3030afe31cc4069e89bab8ac396afaa4c4210b060373af8fb, // Expected 
            1                                                                            // So‘ block
        );
// --- TESTCASE 2: Chay 2 Block (512-bit) ---
        run_multiblock_with_check(
            256'h9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a6c7d2b4e0a5f1c8b9e3d, //key
            96'h1b2d6e7a4f3cb0d9e8a1c2f5,     // Nonce                                         
            32'h00000002,                                                                
            1024'h202c749bbbe12075bfbae17920bbbae16b207499bbe16d20a0c36c2089bbe168632074afbae16f684320bfbae144202c6ea8c34d20bfbae1442074afbae16d206e6f6320699bbbe1b0c644202e63a1c3686b20699dbbe1b0c6676e2074a1bae16e2074afbae162206991c42079616820676e83c46820676e756820a0c376206f,   // Plaintext                                                             
            1024'h8755739a14cc3ac00d302f5cefd13807b0bcbd0880acd4df13668580780535c142760c508a8b1d4cd72c9177bdd57c10e43b5697a2b244adfcac49c79d518fb8b58b031ae4d58c9bd81d1e5cc2fb010733dc31b2d96f277932cec8a7bbaa5d8575193cf808eb0b6be822b225294927ac340beeeba6c1cc5129599452764454fe, // Expected
            2                                                                            // So‘ block
        );
// --- TESTCASE 3: Chay 2 Block (512-bit) ---
        run_multiblock_with_check(
            256'h8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6f5a3b0e9d7c1a4f2b8e, //key
            96'h1a5e8c7d4b29e0a6f1c3b8d5,     // Nonce                                         
            32'h00000005,                                                                
            1024'h2c7491bbe1642075676e202c63a1c3686e20699dbbe1b0c66c2079a0c36e20676ea0c3686320686e6120aac36863206eb4c3756c206ea8c34d20bfbae144202e226e87bbe1696870206391bbe1756874206e87bbe16968676e20a3c3672220b0c6686e2075aac368676e2075aac36c2079a7bae167202cadc3782075a5bae178,   // Plaintext                                                             
            1024'hcc5c9034b6986045e52a21ee0c93af593b3ec3c86756023928159b64a4295affdf4d5832c29b7d2878b558341596e20d17ec8574e669da67bf3cbda3e676ffcd9e443f28d8a51fd0b0b14c27fb830194706398487315408cccf1ecaa864c269142ebef1a794df4a3dde5c6bc32371befc07ac73a4b6ff6de899c2d9035561126, // Expected
            2                                                                            // So block
        );
// --- TESTCASE 4: Chay 1 Block (512-bit) ---
        run_multiblock_with_check(
            256'h4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e0a8f4b2c9e1d3a5f, //key
            96'h9b1c8d7e3a490c5b2f8d1e6a,     // Nonce                                         
            32'h00000003,                                                                
            1024'hb2c363206ea8c34d20bfbae144202c74afbae16f684320bfbae14420b3c3632089bbe1686320676eb4c3684b202e6fa8c36d20bac36320b0c6686e2069b4c368,   // Plaintext                                                             
            1024'h015461dbb69658ee44d68daae48ba59ddff01382ed14fe98da451925b8bdc372519dd5e620b95dcf00fd331477e72ba22a5ce15e9277b3082d29455f2dcf58e9, // Expected
            1                                                                            // So‘ block
        );
// --- TESTCASE 5: Chay 2 Block (512-bit) ---
        run_multiblock_with_check(
            256'h0b9a8f7e6d5c4b3a2f1e0d9c8b7a6f5e4d3c2b1a8f7e6d5c3a9be0d7f1a2c8b4, //key
            96'h3d1e8f5a6c74d0b2e9a1f8c3,     // Nonce                                         
            32'h00000000,                                                                
            1024'h68632063a9bbe16d206ebfbae191c420a3bbe173207581bbe191c420bac36863208bbbe168632075aac37274206ea7bae16c206997bbe16d20b9c364202c6391bbe143208bbbe1686320699bbbe176206fa3c36c206e97bbe168202c63a3bbe1b0c6676e20676e61676e2099bbe191c42069a1c36874208fbbe174206eb2c363,   // Plaintext                                                             
            1024'hf02b0f245f7449c31c190f8d544f6d03fcbc4f900ff9663eb7c8c2b4697e877af3873734dc38faa9ca9df6cdf0909d8d776703f3c1a38b7f86c558ba85350cd73afd14a2f974f6411ac1ec42b8c02495e1462d294b0e7e35d6f5e78e0bc5481697e279df880baf5bd2160008dd19c9d666d7b948b3e7cb5943cb9222f74db0ef, // Expected
            2                                                                            // So‘ block
        );
// --- TESTCASE 6: Chay 2 Block (512-bit) ---
        run_multiblock_with_check(
            256'h9a8b7c6d5e4f3a2b1c0d9e8f7a6b4c5d2e3f0a8b9c1e5d7b4a0fe2c8d9b1f3a6, //key
            96'h1a2f7e6d5b38c0a9f4e1d7b2,     // Nonce                                         
            32'h00000000,                                                                
            1024'h2063a9bbe16874206863a1c3687420676eb9c36320b4c376206eabbae1762099bbe191c42069a1c3687420676eb0c6686e20676e6168206fa0c37620748dbbe17420697568632063a9bbe16d206ebfbae191c420a3bbe173207581bbe191c420bac36863208bbbe168632075aac37274206ea7bae16c206997bbe16d20b9c364,   // Plaintext                                                             
            1024'hdd02bce8e53e78384bfa59e5cd83c28c1c25e63fc17d253b19499ac597c30e53d2194f55cebf965486efc229801e7bd55eb3d1e43ae5ba3e96f92020a1a837e2fe500c8d76fd1ebac1d23b00abfc2ccc91ebc6cc357f748868ea7589deb9f309ec4d66d1b461f57ecb4f560fe3228b72586b3295d13d908f3700fbc237767c39, // Expected
            2                                                                            // So‘ block
        );
// --- TESTCASE 7: Chay 2 Block (512-bit) ---
        run_multiblock_with_check(
            256'h5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c9d7e8f1a2b4c5d6b3e9f0a7d1c8b2e4f, //key
            96'h8f5c1b2d6e7a4f3cb0d9e8a1,     // Nonce                                         
            32'h00000009,                                                                
            1024'h83c4727420699dbbe14c202e6da3bae1687420aac368742074bfbae16863208bbbe162207087bbe16968676e206999bbe17420676e81bbe1696720676ea1c36c20699dbbe1b0c6676e206ebfbae169686b20618dbbe168206961742079a2c36720686eacc37420b4c37620a3c391c4206ea8c34d202cadc36863206dadbae168,   // Plaintext                                                             
            1024'h649147e958e294340f736cd1a7ed67d827fc2715b810c218aebabdf217e020bc4e6965a6e480de0cf84ffc0d2e8eda2b0456183b41c9fca703942c8108d0121afd255ed52b1ae06ffac8f4aeacb1786b083c76a5b51e7a66b1a83cce4dcfd0f4ef2a5f537b38c0be5a93f710e39afde51838c48eb03df70a4da4e17add60b015, // Expected
            2                                                                            // So block
        );
// --- TESTCASE 8: Chay 1 Block (512-bit) ---
        run_multiblock_with_check(
            256'h8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5f3e0b9a2c8f4e1d7b, //key
            96'h9b1c8d5e7b64a2f0b9c1d8e3,     // Nonce                                         
            32'h00000006,                                                                
            1024'h6f686320686ea0c36420638dbbe1682069a0c362207499bbe16d20a0c36c2069a3c36d202c74afbae16f684320bfbae1442061a7bbe163206991bbe17274206e,   // Plaintext                                                             
            1024'h6572441c3c447ae24b4a7daf469da9bc7ca2f871c4a07c65175b4ff3afc4fed42b48a594f816961e04d2ad64565c6c339926f1ca05e1868eedc6ff2051047e13, // Expected
            1                                                                            // So block
        );
// --- TESTCASE 9: Chay 2 Block (512-bit) ---
        run_multiblock_with_check(
            256'h3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b4c5d6e7b4f3cb0a8f2e9d1c5, //key
            96'h1b2d7e6c5b930d1e7b2c8a4f,     // Nonce                                         
            32'h00000007,                                                                
            1024'h93bbe172206e99bbe1756d206d9bbbe173202ca9c468676e2074bfbae1696220676eb4c3686b20a0c36d2063b3c320b3c363202ca1bae1622079adbae16220676e83c46820676e75682069b3c3687420b3c36320a0c36d20699dbbe191c4209ebbe122203a699dbbe1b0c6676e20698dbbe16d20a0c376206ea8c34d20bfbae1,   // Plaintext                                                             
            1024'hc74e3a2b64cb4973f1a9758561aee2ce160a6cbbf8f6190ad04ab51440fc4d9441b253e0e8c9c7e063f5179d39a2dcbad21e7adc87990815417e9e4c71c65894261c195cd5f608da980b082d47d910d1b7107f88d082840e86e7484c83d60bbac09f291755ab0f41b3454d0bf59708309fd33d88f0937ff87d34b459d7c7cdd4, // Expected
            2                                                                            // So‘ block
        );
// --- TESTCASE 10: Chay 2 Block (512-bit) ---
        run_multiblock_with_check(
            256'h1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1b2d7e6c5b43d0e9b1c7f2a8, //key
            96'h2b1c8d5e4b68c0a2f9e1b7d3,     // Nonce                                         
            32'h00000002,                                                                
            1024'h2069a3bae1687020699dbbe1b0c6676e20698dbbe16d209fbbe1686e2063afbae1686e2069a0c36f4820b4c354206e83c47620a0c3686e206863a1c36320a0c36c20676ea9c56320b3c391c420699dbbe1687420676e93bbe190c4202e222179a5bae191c420686eacc36d206fa0c37620a1bae17620676e616d20676ea9c563,   // Plaintext                                                             
            1024'hb2d5d99900e7c5ecdd1ddc48efa69eee7be0d228ad21a19864dcdc7617b12113de62706d0a6d4bd405f7399255d0d91f0784e3d58c0ed49e3792933a22c104d2ef62f237460d0209c798f339ef00e8873d978084195cafda015c3ddb5487b31a52a255bfd17332ecbc83e244353bf81e47033c141b875aeef15d355a9dfb25f5, // Expected
            2                                                                            // So‘ block
        );
// --- TESTCASE 11: Chay 2 Block full 0 (512-bit) ---
        run_multiblock_with_check(
            256'h0000000000000000000000000000000000000000000000000000000000000000, //key
            96'h000000000000000000000000,     // Nonce                                         
            32'h00000002,                                                                
            1024'h0,   // Plaintext                                                             
            1024'h7e1667316c1e6ae85618cd6dfff82c1f3fac62101358b1ed2e0d84f883cbd42da4915cb4349763c3732785fb20b1b8c50abfd23eaada20d56b56b3d758a02013f248a2406271f35fc094cfc913d3d2731ebc58e4fd3a1e280f5d7b1f683727015db3a0a93446c3b0c662d37b998e718e75a0681908d17eaee16c2663e6a0092d, // Expected
            2                                                                            // So block
      );
// --- TESTCASE 12: Chay 2 Block full f (512-bit) ---
        run_multiblock_with_check(
            256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, //key
            96'hffffffffffffffffffffffff,     // Nonce                                         
            32'h00000002,                                                                
            1024'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,   // Plaintext                                                             
            1024'hd84a814f3dfc2bf1814a95a2600029e3c9f925e0e8a1e35f61199c127fc898c7b985736309438a874993187270430e9a3898d9bbf2f145576f4b52fa25d19470215a2d99adcce733259de13ef07a97093bb63ca3afe5395a246a3436d687cf7818f46944ec2cdb64cb1d680da885ff02d5fe64a1c87376fe4b1dccc405a01f92, // Expected
            2                                                                            // So‘ block
      );   
        // Tong ket
        $display("\n==================================================");
        $display("                 SIMULATION SUMMARY               ");
        $display("==================================================");
        $display("Total Testcases : %0d", total_tests);
        $display("Passed          : %0d", pass_count);
        $display("Failed          : %0d", fail_count);
        
        if (fail_count == 0)
            $display(">>> ALL TESTS PASSED! <<<");
        else
            $display(">>> SOME TESTS FAILED! CHECK LOGS. <<<");
        $display("==================================================\n");

        #50 $finish;
    end

endmodule