# ML_DSA_SHAKEgraph TD
    %% Tùy chỉnh màu sắc
    classDef io fill:#1e40af,stroke:#93c5fd,stroke-width:2px,color:#fff;
    classDef memory fill:#065f46,stroke:#6ee7b7,stroke-width:2px,color:#fff;
    classDef logic fill:#b45309,stroke:#fdba74,stroke-width:2px,color:#fff;
    classDef control fill:#4c1d95,stroke:#c4b5fd,stroke-width:2px,color:#fff;
    classDef math fill:#831843,stroke:#d8b4fe,stroke-width:2px,color:#fff;

    %% ================= KẾT NỐI I/O =================
    subgraph KHOI_GIAO_TIEP [GIAO TIẾP NATIVE (I/O)]
        iData([iData 64-bit]):::io
        iCtrl([iValid, iLast, iLast_16bit]):::io
        oReady([oReady]):::io
        oHash([oHash_Word 64-bit]):::io
        oCtrl([oHash_Valid, oDone]):::io
    end

    %% ================= KHỐI ĐIỀU KHIỂN =================
    subgraph KHOI_FSM [CONTROL UNIT - MÁY TRẠNG THÁI]
        FSM{<b>FSM Controller</b><br/>IDLE, ABSORB, PAD, PROCESS, SQUEEZE}:::control
        CNT_CYCLE[Cycle Counter<br/>0 -> 24]:::control
        CNT_ROUND[Round Counter<br/>0 -> 23]:::control
    end

    %% ================= KHỐI PADDING =================
    subgraph KHOI_PADDER [PADDER & FORMATTER]
        SWAP[Đảo Byte<br/>Little Endian]:::logic
        MUX_INJECT{MUX Tạo Padding<br/><i>inject_word</i>}:::logic
    end

    %% ================= KHỐI BĂNG CHUYỀN (DATAPATH) =================
    subgraph KHOI_DATAPATH [SPONGE STATE - SHIFT REGISTER]
        XOR_IN((XOR)):::logic
        REG_S[<b>Thanh ghi S[0] đến S[24]</b><br/>Tổng 1600 bit]:::memory
        MUX_STATE{MUX: Shift hoặc Load}:::logic
        FORMAT_OUT[Format Ouput]:::logic
    end

    %% ================= KHỐI TOÁN HỌC =================
    subgraph KHOI_KECCAK [KECCAK-F MATH CORE]
        KECCAK_ROUND[<b>keccak_round</b><br/>Thuần tổ hợp (Theta, Rho, Pi, Chi, Iota)]:::math
        ROM_RC[(<b>round_constant</b><br/>Bảng ROM 64-bit)]:::memory
    end

    %% --- ĐỊNH TUYẾN DỮ LIỆU (DATA PATH) ---
    iData --> SWAP
    SWAP --> MUX_INJECT
    MUX_INJECT -->|inject_word| XOR_IN
    
    REG_S -.->|S[0] cũ| XOR_IN
    XOR_IN -->|S[0] ^ inject_word| MUX_STATE
    
    MUX_STATE -->|Chế độ Dịch (Shift)| REG_S
    MUX_STATE -->|Chế độ Nạp (Load)| REG_S
    
    REG_S ==>|State_Sponge 1600-bit| KECCAK_ROUND
    KECCAK_ROUND ==>|round_out 1600-bit| MUX_STATE
    
    REG_S -->|Trích xuất S[0]| FORMAT_OUT
    FORMAT_OUT --> oHash

    %% --- ĐỊNH TUYẾN ĐIỀU KHIỂN (CONTROL PATH) ---
    iCtrl --> FSM
    FSM --> oReady
    FSM --> oCtrl
    
    FSM <--> CNT_CYCLE
    FSM <--> CNT_ROUND
    
    CNT_CYCLE --> MUX_INJECT
    FSM -->|shift_active| MUX_STATE
    
    CNT_ROUND --> ROM_RC
    ROM_RC -->|RC 64-bit| KECCAK_ROUND
