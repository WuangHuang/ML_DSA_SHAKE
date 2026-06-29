
`timescale 1ns / 1ps

module tb_ML_DSA_LIGHTWAVE_SHAKE();

    reg         iClk;
    reg         iRst_n;
    reg         iStart;
    reg         iMode;  
    
    reg [63:0]  iData;
    reg         iValid;
    reg         iLast;
    reg         iLast_16bit;
    wire        oReady;
    
    reg         iSqueeze_En;
    wire [63:0] oHash;
    wire        oHash_Valid;
    wire        oDone;

    ML_DSA_LIGHTWEIGHT_SHAKE uut (
        .iClk(iClk),
        .iRst_n(iRst_n),
        .iStart(iStart),
        .iMode(iMode),
        .iData(iData),
        .iValid(iValid),
        .iLast(iLast),
        .iLast_16bit(iLast_16bit),
        .oReady(oReady),
        .iSqueeze_En(iSqueeze_En), 
        .oHash_Word(oHash),
        .oHash_Valid(oHash_Valid),
        .oDone(oDone)
    );

    initial begin
        iClk = 0;
        forever #5 iClk = ~iClk; 
    end

    integer out_idx;
    reg [1087:0] digest_out;

    always @(posedge iClk) begin
        if (!iRst_n || iStart) begin
            out_idx <= 0;
            digest_out <= 1088'h0;
        end else if (oHash_Valid) begin
            case (out_idx)
                0:  digest_out[1087:1024] <= oHash; 
                1:  digest_out[1023:960]  <= oHash; 
                2:  digest_out[959:896]   <= oHash;
                3:  digest_out[895:832]   <= oHash;
                4:  digest_out[831:768]   <= oHash;
                5:  digest_out[767:704]   <= oHash;
                6:  digest_out[703:640]   <= oHash;
                7:  digest_out[639:576]   <= oHash;
                8:  digest_out[575:512]   <= oHash;
                9:  digest_out[511:448]   <= oHash;
                10: digest_out[447:384]   <= oHash;
                11: digest_out[383:320]   <= oHash;
                12: digest_out[319:256]   <= oHash;
                13: digest_out[255:192]   <= oHash;
                14: digest_out[191:128]   <= oHash;
                15: digest_out[127:64]    <= oHash;
                16: digest_out[63:0]      <= oHash;
            endcase
            out_idx <= out_idx + 1;
        end
    end

    task start_hash;
        begin
            @(negedge iClk);
            iStart = 1'b1;
            @(negedge iClk);
            iStart = 1'b0;
        end
    endtask

    reg mute_log = 0; 

    task send_word;
        input [63:0] t_data;
        input        t_is_last;
        input        t_is_16bit;
        begin
            if (!mute_log)
                $display("Data: %016X | Last: %b", t_data, t_is_last);

            @(negedge iClk);
            iValid      = 1'b1;
            iData       = t_data;
            iLast       = t_is_last;
            iLast_16bit = t_is_16bit;
            
            wait(oReady == 1'b1);
            @(posedge iClk); 
            
            @(negedge iClk);
            iValid      = 1'b0;
            iLast       = 1'b0;
            iLast_16bit = 1'b0;
        end
    endtask

    task check_hash;
        input [1087:0] expected_hash;
        begin
            wait(oDone == 1'b1);
            
            @(negedge iClk);
            iSqueeze_En = 1'b1;
            
            wait(out_idx == 17);
            
            @(negedge iClk);
            iSqueeze_En = 1'b0;
            
            @(posedge iClk);
            $display("   -------------------------------------------------------------------------");
            $display("   [Digest Out]    %X", digest_out);
            $display("   [Expected Hash] %X", expected_hash);
            
            if (digest_out === expected_hash)
                $display("========================================> PASS\n");
            else
                $display("========================================> FAILED\n");
        end
    endtask

    integer w;

    initial begin
        iRst_n = 0; iStart = 0;
        iValid = 0; iLast = 0; iLast_16bit = 0; iData = 0; iSqueeze_En = 0;
        
        #100;
        iRst_n = 1;
        #20;

        $display("TEST 0: ExpandS / ExpandMask (66 Byte)");
        iStart = 1;
        iMode = 1'b1;
        start_hash();
        mute_log = 0;
        send_word(64'h1111222233334444, 1'b0, 1'b0); 
        send_word(64'h5555666677778888, 1'b0, 1'b0); 
        send_word(64'h9999AAAABBBBCCCC, 1'b0, 1'b0); 
        send_word(64'hDDDDEEEEFFFF0000, 1'b0, 1'b0); 
        send_word(64'hB1B2B3B4B5B6B7B8, 1'b0, 1'b0); 
        send_word(64'hC1C2C3C4C5C6C7C8, 1'b0, 1'b0); 
        send_word(64'hD1D2D3D4D5D6D7D8, 1'b0, 1'b0); 
        send_word(64'hE1E2E3E4E5E6E7E8, 1'b0, 1'b0); 
        send_word(64'h000000000000ABCD, 1'b1, 1'b1); // Word 9 
        check_hash(1088'h51C940EE404481023B443CEE19942EC600E8C8EC22ABCF4F2750CD450966040715BC2084C5C7936792B9E405802CD101BC05425A5CC58791A4195EBB7BE98B0F0D311FB5BF6C70B0487E9BB3484E174F76CFB4EFAD1A33D283270CAF116464EE8A847646B3AB1A8E30B6440CC7A225CA7DAAB2851C9DC1C7746F612980F642F9864CA4E5D8F9930E);

        iStart = 1;
        $display("TEST 1: KeyGen - Expand Seed (32 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 0;
        for (w = 0; w < 3; w = w + 1) begin
            send_word(64'h1111111111111111, 1'b0, 1'b0);
        end
        send_word(64'h1111111111111111, 1'b1, 1'b0); // Word 4 (Last)
        check_hash(1088'hFFBBAE4F351B619460FA09EAED2696331EBA5800A356B06A87D92BB3694802003193104C76C4213377ECFD345B79639B56D2F9D7F52C36F81DD0F8F9029244A1AFD9948D5FFDACC37F573742EA32C04AE97AEA307658B56A3B5C3157A0343462B4676D285A676F2351E094B04DB0F509386EBC47FE6E5D1A88ED640F5AAD1D9046C1FAA3B3C8169A); 

        $display("TEST 2: SampleInBall (64 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 0;
        for (w = 0; w < 7; w = w + 1) begin
            send_word(64'h2222222222222222, 1'b0, 1'b0);
        end
        send_word(64'h2222222222222222, 1'b1, 1'b0); // Word 8 (Last)
        check_hash(1088'h18CFCA11E00FFD3F4FA40ACA2ADFD503B60575B68DF6CC48FCEFF3623B8A7DA1BDD2B1F72AACC2A89C8E6F1CF13FA81790B8A15054C1C1C87690868B40DCF1739B7DAA5F33FC5F84A392916E45201C6F3A74C6B596FC5ACE9EB379D45CC131319CEE67C52F553C20DA59602738D304EA57B93939E95F0F93633C3A2F8644E44C72435F298B50E27E);

        $display("TEST 3: ExpandS / ExpandMask (66 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 0;
        for (w = 0; w < 8; w = w + 1) begin
            send_word(64'h3333333333333333, 1'b0, 1'b0);
        end
        send_word(64'h0000000000003333, 1'b1, 1'b1); // Word 9 (Last, Dư 16bit)
        check_hash(1088'h9A21A347990FA981E315DBD5505D5ECCD56E3D1579451B2520B9247EC7BC886B34F3339E480E839627CA110EBF37E441C2E8CA7481BF1C184DDD1A939FBCA282E8C5500555D7AD09628AAB57E7B6074367B25E41A885067C93D3CFAB8A0569E1BB182CB4C4D5F65222BBFD7B0653919A25E2D28F950CE6365CB2B81048E12435E0A31D7F7B1FC13F);

        $display("TEST 4: Sign - secret seed (128 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 0;
        for (w = 0; w < 15; w = w + 1) begin
            send_word(64'h4444444444444444, 1'b0, 1'b0);
        end
        send_word(64'h4444444444444444, 1'b1, 1'b0); // Word 16 (Last)
        check_hash(1088'h44352005A50F864E1BB8672F735EDBDE3356C10FED4C11E59A771510146FDFEA93546152FA392CA4FE6E3C94958232111F76CC4DF75B41E291C9678AE752324BD9CC83EF3018BEF0BA33B87AFEB37E845636A78583EEB8E53B07A6046525DE3BA21EBF26FF2D366F3990D14530286A995C9A8DE5BD0DC892B0D3C4EA4BD45F6B7A8890AB9289446C); 

        $display("TEST 5: Sign/Verify -  (1088 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 1; 
        for (w = 0; w < 135; w = w + 1) begin 
            send_word(64'h5555555555555555, 1'b0, 1'b0);
        end
        mute_log = 0;
        send_word(64'h5555555555555555, 1'b1, 1'b0); // Word 136 (Last)
        check_hash(1088'h156C79294F216430B040A698FBD663AB03F9CDDF6D5FD508529D754CBBEAF45442463E7C69C3CB16669952D6B9C45AEDBD02F993696D4BF2B0247D252947AE60794E37F3B0EC1CB562371169BD822F7EF9422F7853B4AC0DF2A802E6A1989E829EAED710F96B4D76E1725768EFD479058A235F7CAC25224BEAA40A40B0BF5F46C82BDE7DFAB50B97);

        $display("TEST 6: KeyGen/Verify - Public Key ML-DSA-87 (2592 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 1; 
        for (w = 0; w < 323; w = w + 1) begin 
            send_word(64'h6666666666666666, 1'b0, 1'b0);
        end
        mute_log = 0;
        send_word(64'h6666666666666666, 1'b1, 1'b0); // Word 324 (Last)
        check_hash(1088'h927E9E51547422411EE7A34C6951AECD53E108AEA9D78709BEE6D09FBD58E4FAF9EDBF059CE957C86B5641E0E1D4BC34BB501C49A8D3DE5B2E3F5EB67296A9DA0B731B98EE84B45687C6C8E85876B4AF8A00B499F9FFBDA48EF56F9053463C6D2FF8FAC4A27BE328FAF4DBB45DB202AC5770D85C2E7D7AE0D93444F0B74330266DA0424008EB81C0); 

        $display("TEST 7: ExpandA (RejNTTPoly) - SHAKE128 (34 Byte)");
        iMode = 1'b0; // SHAKE128
        start_hash();
        mute_log = 0;
        for (w = 0; w < 4; w = w + 1) begin
            send_word(64'h7777777777777777, 1'b0, 1'b0);
        end
        send_word(64'h0000000000007777, 1'b1, 1'b1);
        check_hash(1088'h1B1F4D2F9DAAC7637A66337BFB013B0B3BB7A152FD92E40A9FB4F668BC0323815084B7A9783EA5A5E87F49C2C1182CBE8B354FF367C63C7EBD147589E5E6B4204FFF0BCF0F84890852CD90234656FA9BFD67FA6F5ADD6883205F8816612E81C8D0D788A60E97AD85BB55F089B86CF817C6E6620A442E2801084D332F07875909536EA9DD1496A2DC);

        $display("TEST 8: 64 Byte Block ZEROS");
        iMode = 1'b1; 
        start_hash();
        mute_log = 0;
        for (w = 0; w < 7; w = w + 1) begin
            send_word(64'h0, 1'b0, 1'b0);
        end
        send_word(64'h0, 1'b1, 1'b0);
        check_hash(1088'h7EA5F2EA9E9487DE4753918BBF5308EB91FA641889236C55D708ECB4D9666A3608D79DAE85E23E2BEB312FEDB521E82CF1A233ADCD4A9C276C748BECD595C409C572EEE787DB91A414980911B5AF6CEDC51135F12BD074FFFC140F68698CA2780671B2416C365A385ADCFED1F5FE78FE9E753BFFA22875DEC51D81F86AE41DA5A120243B1BFE9077);

        #500;
        $finish;
    end

    initial begin
        $dumpfile("tb_ML_DSA_LIGHTWAVE_SHAKE.vcd");
        $dumpvars(0, tb_ML_DSA_LIGHTWAVE_SHAKE);
    end

endmodule
