

(* flatten_hierarchy = "yes" *)
module SHAKE_KECCAK_F (
    input  wire [1599:0] iState, 
    input  wire [4:0]    iRound_Index, // Nhận trực tiếp index (0->23) thay vì 64-bit RC
    output wire [1599:0] oState 
);

    // =================================================================
    // 1. ROM 7-BIT TỐI ƯU CỰC ĐỘ (Tiết kiệm hàng trăm LUTs & Dây Routing)
    // Map bit: {b63, b31, b15, b7, b3, b1, b0}
    // =================================================================
    reg [6:0] rc_7b;
    always @(*) begin
        case (iRound_Index)
            5'd0 : rc_7b = 7'b0000001; // 0x01
            5'd1 : rc_7b = 7'b0011010; // 0x82   -> b15, b7, b1
            5'd2 : rc_7b = 7'b1011110; // 0x8A   -> b63, b15, b7, b3, b1
            5'd3 : rc_7b = 7'b1110000; // 0x8000 -> b63, b31, b15
            5'd4 : rc_7b = 7'b0011111; // 0x8B   -> b15, b7, b3, b1, b0
            5'd5 : rc_7b = 7'b0100001; // 0x01   -> b31, b0
            5'd6 : rc_7b = 7'b1111001; // 0x81   -> b63, b31, b15, b7, b0
            5'd7 : rc_7b = 7'b1010101; // 0x09   -> b63, b15, b3, b0
            5'd8 : rc_7b = 7'b0001110; // 0x8A   -> b7, b3, b1
            5'd9 : rc_7b = 7'b0001100; // 0x88   -> b7, b3
            5'd10: rc_7b = 7'b0110101; // 0x09   -> b31, b15, b3, b0
            5'd11: rc_7b = 7'b0100110; // 0x0A   -> b31, b3, b1
            5'd12: rc_7b = 7'b0111111; // 0x8B   -> b31, b15, b7, b3, b1, b0
            5'd13: rc_7b = 7'b1001111; // 0x8B   -> b63, b7, b3, b1, b0
            5'd14: rc_7b = 7'b1011101; // 0x89   -> b63, b15, b7, b3, b0
            5'd15: rc_7b = 7'b1010011; // 0x03   -> b63, b15, b1, b0
            5'd16: rc_7b = 7'b1010010; // 0x02   -> b63, b15, b1
            5'd17: rc_7b = 7'b1001000; // 0x80   -> b63, b7
            5'd18: rc_7b = 7'b0010110; // 0x0A   -> b15, b3, b1
            5'd19: rc_7b = 7'b1100110; // 0x0A   -> b63, b31, b3, b1
            5'd20: rc_7b = 7'b1111001; // 0x81   -> b63, b31, b15, b7, b0
            5'd21: rc_7b = 7'b1011000; // 0x80   -> b63, b15, b7
            5'd22: rc_7b = 7'b0100001; // 0x01   -> b31, b0
            5'd23: rc_7b = 7'b1110100; // 0x08   -> b63, b31, b15, b3
            default: rc_7b = 7'b0000000;
        endcase
    end

    // =================================================================
    // MAPPING MẢNG ĐẦU VÀO
    // =================================================================
    wire [63:0] A00=iState[1599:1536], A10=iState[1535:1472], A20=iState[1471:1408], A30=iState[1407:1344], A40=iState[1343:1280];
    wire [63:0] A01=iState[1279:1216], A11=iState[1215:1152], A21=iState[1151:1088], A31=iState[1087:1024], A41=iState[1023:960];
    wire [63:0] A02=iState[959:896],   A12=iState[895:832],   A22=iState[831:768],   A32=iState[767:704],   A42=iState[703:640];
    wire [63:0] A03=iState[639:576],   A13=iState[575:512],   A23=iState[511:448],   A33=iState[447:384],   A43=iState[383:320];
    wire [63:0] A04=iState[319:256],   A14=iState[255:192],   A24=iState[191:128],   A34=iState[127:64],    A44=iState[63:0];

    // =================================================================
    // BƯỚC: THETA
    // =================================================================
    wire [63:0] C0=A00^A01^A02^A03^A04, C1=A10^A11^A12^A13^A14, C2=A20^A21^A22^A23^A24, C3=A30^A31^A32^A33^A34, C4=A40^A41^A42^A43^A44;

    wire [63:0] A00_theta=A00^C4^{C1[62:0],C1[63]}, A01_theta=A01^C4^{C1[62:0],C1[63]}, A02_theta=A02^C4^{C1[62:0],C1[63]}, A03_theta=A03^C4^{C1[62:0],C1[63]}, A04_theta=A04^C4^{C1[62:0],C1[63]};
    wire [63:0] A10_theta=A10^C0^{C2[62:0],C2[63]}, A11_theta=A11^C0^{C2[62:0],C2[63]}, A12_theta=A12^C0^{C2[62:0],C2[63]}, A13_theta=A13^C0^{C2[62:0],C2[63]}, A14_theta=A14^C0^{C2[62:0],C2[63]};
    wire [63:0] A20_theta=A20^C1^{C3[62:0],C3[63]}, A21_theta=A21^C1^{C3[62:0],C3[63]}, A22_theta=A22^C1^{C3[62:0],C3[63]}, A23_theta=A23^C1^{C3[62:0],C3[63]}, A24_theta=A24^C1^{C3[62:0],C3[63]};
    wire [63:0] A30_theta=A30^C2^{C4[62:0],C4[63]}, A31_theta=A31^C2^{C4[62:0],C4[63]}, A32_theta=A32^C2^{C4[62:0],C4[63]}, A33_theta=A33^C2^{C4[62:0],C4[63]}, A34_theta=A34^C2^{C4[62:0],C4[63]};
    wire [63:0] A40_theta=A40^C3^{C0[62:0],C0[63]}, A41_theta=A41^C3^{C0[62:0],C0[63]}, A42_theta=A42^C3^{C0[62:0],C0[63]}, A43_theta=A43^C3^{C0[62:0],C0[63]}, A44_theta=A44^C3^{C0[62:0],C0[63]};

    // =================================================================
    // BƯỚC: RHO & PI
    // =================================================================
    wire [63:0] A00_rhopi=A00_theta,                           A01_rhopi={A30_theta[35:0],A30_theta[63:36]}, A02_rhopi={A10_theta[62:0],A10_theta[63]},    A03_rhopi={A40_theta[36:0],A40_theta[63:37]}, A04_rhopi={A20_theta[1:0],A20_theta[63:2]};
    wire [63:0] A10_rhopi={A11_theta[19:0],A11_theta[63:20]}, A11_rhopi={A41_theta[43:0],A41_theta[63:44]}, A12_rhopi={A21_theta[57:0],A21_theta[63:58]}, A13_rhopi={A01_theta[27:0],A01_theta[63:28]}, A14_rhopi={A31_theta[8:0],A31_theta[63:9]};
    wire [63:0] A20_rhopi={A22_theta[20:0],A22_theta[63:21]}, A21_rhopi={A02_theta[60:0],A02_theta[63:61]}, A22_rhopi={A32_theta[38:0],A32_theta[63:39]}, A23_rhopi={A12_theta[53:0],A12_theta[63:54]}, A24_rhopi={A42_theta[24:0],A42_theta[63:25]};
    wire [63:0] A30_rhopi={A33_theta[42:0],A33_theta[63:43]}, A31_rhopi={A13_theta[18:0],A13_theta[63:19]}, A32_rhopi={A43_theta[55:0],A43_theta[63:56]}, A33_rhopi={A23_theta[48:0],A23_theta[63:49]}, A34_rhopi={A03_theta[22:0],A03_theta[63:23]};
    wire [63:0] A40_rhopi={A44_theta[49:0],A44_theta[63:50]}, A41_rhopi={A24_theta[2:0],A24_theta[63:3]},   A42_rhopi={A04_theta[45:0],A04_theta[63:46]}, A43_rhopi={A34_theta[7:0],A34_theta[63:8]},   A44_rhopi={A14_theta[61:0],A14_theta[63:62]};

    // =================================================================
    // BƯỚC: CHI (Hoàn toàn độc lập với Iota)
    // =================================================================
    wire [63:0] A00_chi=A00_rhopi^((~A10_rhopi)&A20_rhopi), A01_chi=A01_rhopi^((~A11_rhopi)&A21_rhopi), A02_chi=A02_rhopi^((~A12_rhopi)&A22_rhopi), A03_chi=A03_rhopi^((~A13_rhopi)&A23_rhopi), A04_chi=A04_rhopi^((~A14_rhopi)&A24_rhopi);
    wire [63:0] A10_chi=A10_rhopi^((~A20_rhopi)&A30_rhopi), A11_chi=A11_rhopi^((~A21_rhopi)&A31_rhopi), A12_chi=A12_rhopi^((~A22_rhopi)&A32_rhopi), A13_chi=A13_rhopi^((~A23_rhopi)&A33_rhopi), A14_chi=A14_rhopi^((~A24_rhopi)&A34_rhopi);
    wire [63:0] A20_chi=A20_rhopi^((~A30_rhopi)&A40_rhopi), A21_chi=A21_rhopi^((~A31_rhopi)&A41_rhopi), A22_chi=A22_rhopi^((~A32_rhopi)&A42_rhopi), A23_chi=A23_rhopi^((~A33_rhopi)&A43_rhopi), A24_chi=A24_rhopi^((~A34_rhopi)&A44_rhopi);
    wire [63:0] A30_chi=A30_rhopi^((~A40_rhopi)&A00_rhopi), A31_chi=A31_rhopi^((~A41_rhopi)&A01_rhopi), A32_chi=A32_rhopi^((~A42_rhopi)&A02_rhopi), A33_chi=A33_rhopi^((~A43_rhopi)&A03_rhopi), A34_chi=A34_rhopi^((~A44_rhopi)&A04_rhopi);
    wire [63:0] A40_chi=A40_rhopi^((~A00_rhopi)&A10_rhopi), A41_chi=A41_rhopi^((~A01_rhopi)&A11_rhopi), A42_chi=A42_rhopi^((~A02_rhopi)&A12_rhopi), A43_chi=A43_rhopi^((~A03_rhopi)&A13_rhopi), A44_chi=A44_rhopi^((~A04_rhopi)&A14_rhopi);

    // =================================================================
    // BƯỚC: IOTA (Chỉ gắp 7 bit, 57 bit còn lại đi dây đồng nối thẳng)
    // =================================================================
    wire [63:0] A00_chilota = {
        A00_chi[63] ^ rc_7b[6],
        A00_chi[62:32],
        A00_chi[31] ^ rc_7b[5],
        A00_chi[30:16],
        A00_chi[15] ^ rc_7b[4],
        A00_chi[14:8],
        A00_chi[7]  ^ rc_7b[3],
        A00_chi[6:4],
        A00_chi[3]  ^ rc_7b[2],
        A00_chi[2],
        A00_chi[1]  ^ rc_7b[1],
        A00_chi[0]  ^ rc_7b[0]
    };

    // =================================================================
    // ĐÓNG GÓI RA OSTATE
    // =================================================================
    assign oState = {
        A00_chilota, A10_chi, A20_chi, A30_chi, A40_chi, 
        A01_chi,     A11_chi, A21_chi, A31_chi, A41_chi, 
        A02_chi,     A12_chi, A22_chi, A32_chi, A42_chi, 
        A03_chi,     A13_chi, A23_chi, A33_chi, A43_chi, 
        A04_chi,     A14_chi, A24_chi, A34_chi, A44_chi
    };

endmodule