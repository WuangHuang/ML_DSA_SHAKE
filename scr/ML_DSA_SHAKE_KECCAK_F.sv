
module SHAKE_KECCAK_F (
    input  wire [1599:0] iState, 
    input  wire [63:0]   RC, 
    output wire [1599:0] oState 
);

    //MAPPING: A[x, y, z] = S[64(5y + x) + z] {x,y in [0,5), z in [0,64)}
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    wire [63:0] A00 = iState[1599:1536]; wire [63:0] A10 = iState[1535:1472]; wire [63:0] A20 = iState[1471:1408]; wire [63:0] A30 = iState[1407:1344]; wire [63:0] A40 = iState[1343:1280];
    wire [63:0] A01 = iState[1279:1216]; wire [63:0] A11 = iState[1215:1152]; wire [63:0] A21 = iState[1151:1088]; wire [63:0] A31 = iState[1087:1024]; wire [63:0] A41 = iState[1023:960];
    wire [63:0] A02 = iState[959:896];   wire [63:0] A12 = iState[895:832];   wire [63:0] A22 = iState[831:768];   wire [63:0] A32 = iState[767:704];   wire [63:0] A42 = iState[703:640];
    wire [63:0] A03 = iState[639:576];   wire [63:0] A13 = iState[575:512];   wire [63:0] A23 = iState[511:448];   wire [63:0] A33 = iState[447:384];   wire [63:0] A43 = iState[383:320];
    wire [63:0] A04 = iState[319:256];   wire [63:0] A14 = iState[255:192];   wire [63:0] A24 = iState[191:128];   wire [63:0] A34 = iState[127:64];    wire [63:0] A44 = iState[63:0];
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    //Specication of Theta
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    wire [63:0] C0 = A00 ^ A01 ^ A02 ^ A03 ^ A04; 
    wire [63:0] C1 = A10 ^ A11 ^ A12 ^ A13 ^ A14; 
    wire [63:0] C2 = A20 ^ A21 ^ A22 ^ A23 ^ A24; 
    wire [63:0] C3 = A30 ^ A31 ^ A32 ^ A33 ^ A34; 
    wire [63:0] C4 = A40 ^ A41 ^ A42 ^ A43 ^ A44;

    wire [63:0] A00_theta = A00 ^ C4 ^ {C1[62:0], C1[63]}; wire [63:0] A01_theta = A01 ^ C4 ^ {C1[62:0], C1[63]}; wire [63:0] A02_theta = A02 ^ C4 ^ {C1[62:0], C1[63]}; wire [63:0] A03_theta = A03 ^ C4 ^ {C1[62:0], C1[63]}; wire [63:0] A04_theta = A04 ^ C4 ^ {C1[62:0], C1[63]};
    wire [63:0] A10_theta = A10 ^ C0 ^ {C2[62:0], C2[63]}; wire [63:0] A11_theta = A11 ^ C0 ^ {C2[62:0], C2[63]}; wire [63:0] A12_theta = A12 ^ C0 ^ {C2[62:0], C2[63]}; wire [63:0] A13_theta = A13 ^ C0 ^ {C2[62:0], C2[63]}; wire [63:0] A14_theta = A14 ^ C0 ^ {C2[62:0], C2[63]};
    wire [63:0] A20_theta = A20 ^ C1 ^ {C3[62:0], C3[63]}; wire [63:0] A21_theta = A21 ^ C1 ^ {C3[62:0], C3[63]}; wire [63:0] A22_theta = A22 ^ C1 ^ {C3[62:0], C3[63]}; wire [63:0] A23_theta = A23 ^ C1 ^ {C3[62:0], C3[63]}; wire [63:0] A24_theta = A24 ^ C1 ^ {C3[62:0], C3[63]};
    wire [63:0] A30_theta = A30 ^ C2 ^ {C4[62:0], C4[63]}; wire [63:0] A31_theta = A31 ^ C2 ^ {C4[62:0], C4[63]}; wire [63:0] A32_theta = A32 ^ C2 ^ {C4[62:0], C4[63]}; wire [63:0] A33_theta = A33 ^ C2 ^ {C4[62:0], C4[63]}; wire [63:0] A34_theta = A34 ^ C2 ^ {C4[62:0], C4[63]};
    wire [63:0] A40_theta = A40 ^ C3 ^ {C0[62:0], C0[63]}; wire [63:0] A41_theta = A41 ^ C3 ^ {C0[62:0], C0[63]}; wire [63:0] A42_theta = A42 ^ C3 ^ {C0[62:0], C0[63]}; wire [63:0] A43_theta = A43 ^ C3 ^ {C0[62:0], C0[63]}; wire [63:0] A44_theta = A44 ^ C3 ^ {C0[62:0], C0[63]};
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  
    //Specification of Rho and Pi
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    wire [63:0] A00_rhopi = A00_theta;                           wire [63:0] A01_rhopi = {A30_theta[35:0], A30_theta[63:36]}; wire [63:0] A02_rhopi = {A10_theta[62:0], A10_theta[63]};    wire [63:0] A03_rhopi = {A40_theta[36:0], A40_theta[63:37]}; wire [63:0] A04_rhopi = {A20_theta[ 1:0], A20_theta[63:2 ]};
    wire [63:0] A10_rhopi = {A11_theta[19:0], A11_theta[63:20]}; wire [63:0] A11_rhopi = {A41_theta[43:0], A41_theta[63:44]}; wire [63:0] A12_rhopi = {A21_theta[57:0], A21_theta[63:58]}; wire [63:0] A13_rhopi = {A01_theta[27:0], A01_theta[63:28]}; wire [63:0] A14_rhopi = {A31_theta[ 8:0], A31_theta[63:9 ]};
    wire [63:0] A20_rhopi = {A22_theta[20:0], A22_theta[63:21]}; wire [63:0] A21_rhopi = {A02_theta[60:0], A02_theta[63:61]}; wire [63:0] A22_rhopi = {A32_theta[38:0], A32_theta[63:39]}; wire [63:0] A23_rhopi = {A12_theta[53:0], A12_theta[63:54]}; wire [63:0] A24_rhopi = {A42_theta[24:0], A42_theta[63:25]};
    wire [63:0] A30_rhopi = {A33_theta[42:0], A33_theta[63:43]}; wire [63:0] A31_rhopi = {A13_theta[18:0], A13_theta[63:19]}; wire [63:0] A32_rhopi = {A43_theta[55:0], A43_theta[63:56]}; wire [63:0] A33_rhopi = {A23_theta[48:0], A23_theta[63:49]}; wire [63:0] A34_rhopi = {A03_theta[22:0], A03_theta[63:23]};
    wire [63:0] A40_rhopi = {A44_theta[49:0], A44_theta[63:50]}; wire [63:0] A41_rhopi = {A24_theta[ 2:0], A24_theta[63:3 ]}; wire [63:0] A42_rhopi = {A04_theta[45:0], A04_theta[63:46]}; wire [63:0] A43_rhopi = {A34_theta[ 7:0], A34_theta[63:8 ]}; wire [63:0] A44_rhopi = {A14_theta[61:0], A14_theta[63:62]};
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Specification of Chi and Lota
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    wire [63:0] A00_chilota = A00_rhopi ^ ((~A10_rhopi) & A20_rhopi) ^ RC; wire [63:0] A01_chilota = A01_rhopi ^ ((~A11_rhopi) & A21_rhopi); wire [63:0] A02_chilota = A02_rhopi ^ ((~A12_rhopi) & A22_rhopi); wire [63:0] A03_chilota = A03_rhopi ^ ((~A13_rhopi) & A23_rhopi); wire [63:0] A04_chilota = A04_rhopi ^ ((~A14_rhopi) & A24_rhopi);
    wire [63:0] A10_chilota = A10_rhopi ^ ((~A20_rhopi) & A30_rhopi);       wire [63:0] A11_chilota = A11_rhopi ^ ((~A21_rhopi) & A31_rhopi); wire [63:0] A12_chilota = A12_rhopi ^ ((~A22_rhopi) & A32_rhopi); wire [63:0] A13_chilota = A13_rhopi ^ ((~A23_rhopi) & A33_rhopi); wire [63:0] A14_chilota = A14_rhopi ^ ((~A24_rhopi) & A34_rhopi);
    wire [63:0] A20_chilota = A20_rhopi ^ ((~A30_rhopi) & A40_rhopi);       wire [63:0] A21_chilota = A21_rhopi ^ ((~A31_rhopi) & A41_rhopi); wire [63:0] A22_chilota = A22_rhopi ^ ((~A32_rhopi) & A42_rhopi); wire [63:0] A23_chilota = A23_rhopi ^ ((~A33_rhopi) & A43_rhopi); wire [63:0] A24_chilota = A24_rhopi ^ ((~A34_rhopi) & A44_rhopi);
    wire [63:0] A30_chilota = A30_rhopi ^ ((~A40_rhopi) & A00_rhopi);       wire [63:0] A31_chilota = A31_rhopi ^ ((~A41_rhopi) & A01_rhopi); wire [63:0] A32_chilota = A32_rhopi ^ ((~A42_rhopi) & A02_rhopi); wire [63:0] A33_chilota = A33_rhopi ^ ((~A43_rhopi) & A03_rhopi); wire [63:0] A34_chilota = A34_rhopi ^ ((~A44_rhopi) & A04_rhopi);
    wire [63:0] A40_chilota = A40_rhopi ^ ((~A00_rhopi) & A10_rhopi);       wire [63:0] A41_chilota = A41_rhopi ^ ((~A01_rhopi) & A11_rhopi); wire [63:0] A42_chilota = A42_rhopi ^ ((~A02_rhopi) & A12_rhopi); wire [63:0] A43_chilota = A43_rhopi ^ ((~A03_rhopi) & A13_rhopi); wire [63:0] A44_chilota = A44_rhopi ^ ((~A04_rhopi) & A14_rhopi);
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // Repacking: S = Plane (0) || Plane (1) || Plane (2) || Plane (3) || Plane (4). 
    assign oState = {A00_chilota, A10_chilota, A20_chilota, A30_chilota, A40_chilota, 
                     A01_chilota, A11_chilota, A21_chilota, A31_chilota, A41_chilota, 
                     A02_chilota, A12_chilota, A22_chilota, A32_chilota, A42_chilota, 
                     A03_chilota, A13_chilota, A23_chilota, A33_chilota, A43_chilota, 
                     A04_chilota, A14_chilota, A24_chilota, A34_chilota, A44_chilota};
endmodule