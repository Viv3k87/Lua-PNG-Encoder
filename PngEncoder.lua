local Stream = require("Stream")
local Filters = require("Filter")
local CRC32_Divisor = 4374732215 --CRC32 polynomial coefficents in decimal 4374732215
local WindowSize = 16384 -- Max Deflate Window size for LZ77 is 32768
local HashPrimes = {
3401963, 8034287, 9866071, 8987161, 2283571, 3562579, 104179, 629171, 1960789, 8242777, 513257, 9585769,
5199437, 8368433, 5819503, 6581321, 9861821, 9742217, 4044431, 9499669, 6340687, 1716241, 5263861, 420977, 394369, 3937537,
5556821, 3985243, 2307247, 1916279, 2093653, 6172577, 9951299, 9290329, 5454877, 758729, 8464133, 3400993, 1497347, 1715243,
9889849, 631471, 1221793, 1545179, 2839789, 5816047, 8199001, 6862727, 5928617, 9878929, 9351557, 6518657, 4504559, 875683,
2871049, 3684641, 8920943, 1262419, 1645691, 5939903, 1505737, 4718531, 9423277, 9868889, 3956647, 1617689, 6704377, 1126387,
5973571, 4302359, 6548947, 8009, 1427039, 5935393, 301153, 9189529, 2296363, 3353579, 3387691, 5152333, 7533793, 6834551, 7234753,
5569301, 7577279, 3170747, 6549727, 3215819, 5796487, 6569971, 4529957, 242419, 2574959, 7296301, 5485499, 5953939, 6158041, 8050873,
1770493, 4936951, 5865061, 3084451, 6086123, 1919881, 4622707, 8225201, 5648761, 2000753, 3916921, 8413519, 4252111, 8561909, 1081229,
6744139, 7749799, 5267173, 7913777, 1219487, 1653167, 218857, 1147043, 3011369, 1597157, 7615187, 1509961, 9868913, 7790477, 2968037, 4250591,
3406811, 3274841, 1350961, 3298579, 1256267, 2105969, 925697, 9698851, 1140239, 104651, 9670351, 5739821, 6623297, 6193799, 3054001, 2924827,
8540563, 6290497, 2286257, 1158569, 4884029, 237563, 7738457, 5409977, 7462277, 3698257, 3456863, 407503, 23929, 7025969, 4926941, 2593439, 9422927,
6764753, 4200769, 451667, 7167361, 2598971, 5236061, 8540237, 4198703, 5650769, 6816493, 8362649, 9495341, 3891383, 1370533, 4784687, 5674511, 87359,
5933467, 3833197, 6794539, 8717131, 6684089, 1753597, 4013197, 8171, 3120317, 7334441, 1125391, 840473, 7173863, 3005291, 316697, 3069421, 2634131, 3823319,
3069791, 8166317, 6201571, 2154707, 1545391, 4620101, 7707907, 4961531, 4624457, 2858393, 7834051, 6143519, 6676261, 4358531, 7572661, 7124977, 747839, 9957581,
7953107, 6957497, 3720877, 1660723, 6520223, 8838043, 6660391, 6869857, 8573207, 4806001, 6687463, 7846063, 3614041, 1978349, 4654217, 1213357, 778417, 494927,
2343329, 1581653, 1447217, 836317, 8163401, 9220847, 4251847, 34519, 7478717, 9845777, 6608737, 1789217, 405407, 6430799, 7344269, 5286839, 3699337, 715699,
4607593, 3542369, 1095541, 7886911, 28309
}
local CLCodeAlpabetOrder = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15}
local CLCodeExtraBits = {
    [16] = {3, 2}, --min length, extrabits
    [17] = {3, 3},
    [18] = {11, 7}
}
local LengthCodes = {
    --[[
    the index is the code, the first value in table is the extra bits to read and add 
    onto the second value; the second value refers to the minimum length
    ]]
    [257] = {0, 3},
    [258] = {0, 4},
    [259] = {0, 5},
    [260] = {0, 6},
    [261] = {0, 7},
    [262] = {0, 8},
    [263] = {0, 9},
    [264] = {0, 10},
    [265] = {1, 11},
    [266] = {1, 13},
    [267] = {1, 15},
    [268] = {1, 17},
    [269] = {2, 19},
    [270] = {2, 23},
    [271] = {2, 27},
    [272] = {2, 31},
    [273] = {3, 35},
    [274] = {3, 43},
    [275] = {3, 51},
    [276] = {3, 59},
    [277] = {4, 67},
    [278] = {4, 83},
    [279] = {4, 99},
    [280] = {4, 115},
    [281] = {5, 131},
    [282] = {5, 163},
    [283] = {5, 195},
    [284] = {5, 227},
    [285] = {0, 258}
}
local DistanceCodes = {
    [0] = {0, 1},
    [1] = {0, 2},
    [2] = {0, 3},
    [3] = {0, 4},
    [4] = {1, 5},
    [5] = {1, 7},
    [6] = {2, 9},
    [7] = {2, 13},
    [8] = {3, 17},
    [9] = {3, 25},
    [10] = {4, 33},
    [11] = {4, 49},
    [12] = {5, 65},
    [13] = {5, 97},
    [14] = {6, 129},
    [15] = {6, 193},
    [16] = {7, 257},
    [17] = {7, 385},
    [18] = {8, 513},
    [19] = {8, 769},
    [20] = {9, 1025},
    [21] = {9, 1537},
    [22] = {10, 2049},
    [23] = {10, 3073},
    [24] = {11, 4097},
    [25] = {11, 6145},
    [26] = {12, 8193},
    [27] = {12, 12289},
    [28] = {13, 16385},
    [29] = {13, 24577},
}

function GetCRC32(Bytes)
    local Register = 0xFFFFFFFF --register is initialized to all 1s

    --extra bytes in place of final CRC
    Bytes[#Bytes+1] = 0
    Bytes[#Bytes+1] = 0
    Bytes[#Bytes+1] = 0
    Bytes[#Bytes+1] = 0

    --need to XOR in first 4 bytes since register doesn't start with all 0s
    Register = Register ~ (Reverse8(Bytes[1]) << 24 | Reverse8(Bytes[2]) << 16 | Reverse8(Bytes[3]) << 8 | Reverse8(Bytes[4]))

    local CurrentByte = 5
    local CurrentBit = 0

    while CurrentByte <= #Bytes or (Register >> 32) & 1 == 1 do
        if (Register >> 32) & 1 == 1 then
            Register = Register ~ CRC32_Divisor
        else
            Register = Register << 1 | ((Bytes[CurrentByte] >> CurrentBit) & 1)
            CurrentBit = CurrentBit + 1

            if CurrentBit > 7 then
                CurrentBit = 0
                CurrentByte = CurrentByte + 1
            end
        end
    end

    return Reverse32(Register ~ 0xFFFFFFFF) -- Register's ones complement is taken and flipped for final CRC
end

function SwitchEndian16(Bytes)
    return ((Bytes << 8) & 0xFF00) | ((Bytes >> 8) & 0xFF)
end

function Reverse32(Num) -- reverses a 32 bit unsigned integer
    Num = ((Num << 16) & 0xFFFF0000) | ((Num >> 16) & 0xFFFF)
    Num = ((Num << 8) & 0xFF00FF00) | ((Num >> 8) & 0xFF00FF)
    Num = ((Num << 4) & 0xF0F0F0F0) | ((Num >> 4) & 0xF0F0F0F)
    Num = ((Num << 2) & 0xCCCCCCCC) | ((Num >> 2) & 0x33333333)
    Num = ((Num << 1) & 0xAAAAAAAA) | ((Num >> 1) & 0x55555555)
    return Num
end

function Reverse8(Num)
    Num = ((Num << 4) & 0xF0) | ((Num >> 4) & 0xF)
    Num = ((Num << 2) & 0xCC) | ((Num >> 2) & 0x33)
    Num = ((Num << 1) & 0xAA) | ((Num >> 1) & 0x55)
    return Num
end

function GetLenDistSymbols(Len, Dist)
    local LenCode = nil
    local DistCode = nil

    for i = 257, 285, 1 do
        if Len >= LengthCodes[i][2] and (LengthCodes[i+1] == nil or Len < LengthCodes[i+1][2]) then
            LenCode = i
            break
        end
    end

    for i = 0, 29, 1 do
        if Dist >= DistanceCodes[i][2] and (DistanceCodes[i+1] == nil or Dist < DistanceCodes[i+1][2]) then
            DistCode = i
            break
        end
    end

    return LenCode, Len - LengthCodes[LenCode][2], DistCode, Dist - DistanceCodes[DistCode][2]
end

function GetAdler32(Bytes) --Checksum for Zlib footer as defined in the RFC 1950 spec
    local s1 = 1
    local s2 = 0
    for i, byte in pairs(Bytes) do
        s1 = (s1 + byte) % 65521
        s2 = (s2 + s1) % 65521
    end
    return s2 * 65536 + s1
end

function GenerateFixedCodes()
    local PrefixCodes = {}

    for i = 0, 143, 1 do
        PrefixCodes[i] = {48 + i, 8}
    end
    for i = 144, 255, 1 do
        PrefixCodes[i] = {400 + (i-144), 9}
    end
    for i = 256, 279, 1 do
        PrefixCodes[i] = {i - 256, 7}
    end
    for i = 280, 287, 1 do
        PrefixCodes[i] = {192 + (i-280), 8}
    end

    return PrefixCodes
end

function Hash(n1, n2, n3, mod)
    return (((n1+n3) * HashPrimes[(n3 & 0xFF) + 1]) - (n2 * HashPrimes[((n1-n3) & 0xFF) + 1]) + (n3 * HashPrimes[(n1 & 0xFF) + 1])) % mod
end

function GenerateHashTable(ByteStream)
    local HashTable = {}
    local TableSize = #ByteStream * 5

    for i = 1, #ByteStream - 2, 1 do
        local HashValue = Hash(ByteStream[i], ByteStream[i+1], ByteStream[i+2], TableSize)
        if HashTable[HashValue] == nil then
            HashTable[HashValue] = {i}
        else
            HashTable[HashValue][#HashTable[HashValue]+1] = i
        end
    end

    return HashTable
end

function GetBounds(Indexes, Min, Max)
    --doesnt converage exactly, off by 1-2 indexes

    local L1 = 1
    local L2 = (#Indexes+1)//2
    local L3 = #Indexes
    local U1 = 1
    local U2 = (#Indexes+1)//2
    local U3 = #Indexes

    while (L3 - L2 > 1) or (U3 - U2 > 1) do
        if Min > Indexes[L2] then
            L1 = L2
            L2 = (L1 + L3)//2
        else
            L3 = L2
            L2 = (L1 + L3)//2
        end

        if Max > Indexes[U2] then
            U1 = U2
            U2 = (U1 + U3)//2
        else
            U3 = U2
            U2 = (U1 + U3)//2
        end
    end

    return L1, U3
end

function ChooseMatch(ByteStream, StartIdx, PossibleIndexes)
    local LongestMatch = 0
    local MatchIdx = nil
    local Min, Max = GetBounds(PossibleIndexes, StartIdx - WindowSize, StartIdx)
    local MaxSearchDepth = 140

    for i = Max, Min, -1 do
        local PossibleMatch = PossibleIndexes[i]
        if PossibleMatch < StartIdx and StartIdx - WindowSize < PossibleMatch then
            local MatchLen = 0 --starting at 0 incase of collisions in hashmap
            while MatchLen < 258 do
                if ByteStream[PossibleMatch + MatchLen] == ByteStream[StartIdx + MatchLen] then
                    MatchLen = MatchLen + 1
                else
                    break
                end
            end

            if MatchLen > LongestMatch and MatchLen >= 3 then
                LongestMatch = MatchLen
                MatchIdx = i
            end

            if Max - i > MaxSearchDepth then break end --give up search after checking some possible matches

        end
    end

    return MatchIdx, LongestMatch
end

function LZ77(ByteStream)
    local CompressedStream = {}
    local HashTable = GenerateHashTable(ByteStream)
    local HashMod = #ByteStream * 5
    local CurrentIdx = 2 - WindowSize

    CompressedStream[1] = ByteStream[1]

    while CurrentIdx <= #ByteStream - WindowSize - 2 do
        local StartIdx = CurrentIdx + WindowSize
        local PossibleMatches = HashTable[Hash(ByteStream[StartIdx], ByteStream[StartIdx+1], ByteStream[StartIdx+2], HashMod)]
        local BestMatch, Len = ChooseMatch(ByteStream, StartIdx, PossibleMatches)

        if ByteStream[StartIdx+3] ~= nil then
            local NextPossibleMatches = HashTable[Hash(ByteStream[StartIdx+1], ByteStream[StartIdx+2], ByteStream[StartIdx+3], HashMod)]
            local NextBestMatch, NextLen = ChooseMatch(ByteStream, StartIdx+1, NextPossibleMatches)
            if NextLen - 1 > Len then
                CompressedStream[#CompressedStream+1] = ByteStream[StartIdx]
                BestMatch, Len = NextBestMatch, NextLen
                PossibleMatches = NextPossibleMatches
                StartIdx = StartIdx + 1
                CurrentIdx = CurrentIdx + 1
            end
        end

        CurrentIdx = CurrentIdx + Len + 1

        if Len ~= 0 then
            CompressedStream[#CompressedStream+1] = {GetLenDistSymbols(Len, StartIdx - PossibleMatches[BestMatch])}
            CurrentIdx = CurrentIdx - 1
        else
            CompressedStream[#CompressedStream+1] = ByteStream[StartIdx]
        end
    end

    for i = CurrentIdx + WindowSize, #ByteStream, 1 do
        CompressedStream[#CompressedStream+1] = ByteStream[i]
    end

    return CompressedStream
end

function GetLiteralDistFrequencies(Symbols)
    local Frequencies = {}
    local DistFrequencies = {}

    for i, v in pairs(Symbols) do
        if type(v) == "table" then
            local LengthSymbol = v[1]
            local DistSymbol = v[3]
            if Frequencies[LengthSymbol] == nil then Frequencies[LengthSymbol] = 0 end
            if DistFrequencies[DistSymbol] == nil then DistFrequencies[DistSymbol] = 0 end

            Frequencies[LengthSymbol] = Frequencies[LengthSymbol] + 1
            DistFrequencies[DistSymbol] = DistFrequencies[DistSymbol] + 1
        else
            if Frequencies[v] == nil then Frequencies[v] = 0 end
            Frequencies[v] = Frequencies[v] + 1
        end
    end

    return Frequencies, DistFrequencies
end

function GetCLSymbolFrequncies(Symbols)
    local Frequencies = {}

    for i, v in pairs(Symbols) do
        if type(v) == "table" then
            local Symbol = v[1]
            if Frequencies[Symbol] == nil then Frequencies[Symbol] = 0 end
            Frequencies[Symbol] = Frequencies[Symbol] + 1
        else
            if Frequencies[v] == nil then Frequencies[v] = 0 end
            Frequencies[v] = Frequencies[v] + 1
        end
    end

    return Frequencies
end

function SortProbabilities(Probabilities) --radix sort to sort frequencies
    local SortedProbabilities = {}
    local BitDepth = 1

    local Bin0 = {}
    local Bin1 = {}

    SortedProbabilities[1] = Bin0
    SortedProbabilities[2] = Bin1

    for i, v in pairs(Probabilities) do
        if v[2] & 1 == 0 then
            Bin0[#Bin0+1] = v
        else
            Bin1[#Bin1+1] = v
        end
    end

    while #Bin0 ~= #Probabilities do
        local UpdatedBin0 = {}
        local UpdatedBin1 = {}

        for j = 1, 2, 1 do
            for i, v in pairs(SortedProbabilities[j]) do
                if v[2] >> BitDepth & 1 == 0 then
                    UpdatedBin0[#UpdatedBin0+1] = v
                else
                    UpdatedBin1[#UpdatedBin1+1] = v
                end
            end
        end

        Bin0 = UpdatedBin0
        Bin1 = UpdatedBin1
        SortedProbabilities = {Bin0, Bin1}
        BitDepth = BitDepth + 1

    end

    SortedProbabilities = Bin0

    return SortedProbabilities
end

function MergeSorted(Table1, Table2)
    local MergedTable = {}
    local P1 = 1
    local P2 = 1

    while #MergedTable ~= #Table1 + #Table2 do
        if Table2[P2] == nil or (Table1[P1] ~= nil and Table1[P1][2] < Table2[P2][2])  then
            MergedTable[#MergedTable+1] = Table1[P1]
            P1 = P1 + 1
        else
            MergedTable[#MergedTable+1] = Table2[P2]
            P2 = P2 + 1
        end
    end

    return MergedTable
end

function FlattenTable(Table)
    local FlatTable = {}

    for i, v in pairs(Table) do
        if type(v) == "table" then
            local Items = FlattenTable(v)
            for _, k in pairs(Items) do
                FlatTable[#FlatTable+1] = k
            end
        else
            FlatTable[#FlatTable+1] = v
        end
    end

    return FlatTable
end

function GetCodeLengths(Frequencies) --package merge algorithim for limited length huffman coding
    local Probabilities = {}
    local CodeLengths = {}
    local TotalSymbols = 0

    for i, v in pairs(Frequencies) do
        TotalSymbols = TotalSymbols + 1
        Probabilities[#Probabilities+1] = {i, v}
        CodeLengths[i] = 0
    end

    Probabilities = SortProbabilities(Probabilities)
    local MaxLen = math.ceil(math.log(TotalSymbols, 2))
    local OriginalProbabilties = Probabilities

    for i = 1, MaxLen-1, 1 do
        local MergedSymbols = {}
        for j = 1, #Probabilities//2, 1 do
            local Item1 = Probabilities[(j-1)*2 + 1]
            local Item2 = Probabilities[(j-1)*2 + 2]

            MergedSymbols[#MergedSymbols+1] = {{Item1[1], Item2[1]}, Item1[2] + Item2[2]}
        end
        Probabilities = MergeSorted(OriginalProbabilties, MergedSymbols)
    end

    local LenFrequencies = {}

    for i = 1, 2 * TotalSymbols - 2, 1 do
        LenFrequencies[#LenFrequencies+1] = Probabilities[i][1]
    end

    for i, v in pairs(FlattenTable(LenFrequencies)) do
        CodeLengths[v] = CodeLengths[v] + 1
    end

    local sum = 0

    for i, v in pairs(CodeLengths) do
        sum = sum + 2^(-v)
    end

    if sum > 1 then print("Error: Prefix code generation broke") return end

    return CodeLengths
end

function GenerateCodesFromLengths(Lengths)
    local LengthFrequencies = {}
    local CurrentCodeAtLen = {}
    local FinalCodes = {}
    local MinLen = 16
    local MaxLen = -1
    local MaxSymbol = -1

    for i, v in pairs(Lengths) do
        LengthFrequencies[v] = LengthFrequencies[v] ~= nil and LengthFrequencies[v] + 1 or 1
        if v > MaxLen then MaxLen = v end
        if v < MinLen then MinLen = v end
        if i > MaxSymbol then MaxSymbol = i end
    end

    CurrentCodeAtLen[MinLen] = 0
    local PrevLen = MinLen

    for i = MinLen + 1, MaxLen, 1 do
        if LengthFrequencies[i] ~= nil then
            CurrentCodeAtLen[i] = (CurrentCodeAtLen[PrevLen] + LengthFrequencies[PrevLen]) << (i - PrevLen)
            PrevLen = i
        end
    end

    for i = 0, MaxSymbol, 1 do --codes of same length are assigned in order
        local Len = Lengths[i]
        if Len ~= nil then
            FinalCodes[i] = {CurrentCodeAtLen[Len], Len}
            CurrentCodeAtLen[Len] = CurrentCodeAtLen[Len] + 1
        else
            FinalCodes[i] = {nil, 0} --symbol was not used
        end
    end

    return FinalCodes
end

function FindRunLength(Table, Idx)
    local InitalValue = Table[Idx]

    for i = Idx + 1, #Table, 1 do
        if Table[i] ~= InitalValue then
            return i - Idx
        end
    end

    return #Table - Idx
end

function GetPrefixCodes(Freqencies)
    local CodeLengths = GetCodeLengths(Freqencies)
    local PrefixCodes = GenerateCodesFromLengths(CodeLengths)
    return PrefixCodes
end

function CompressHuffmanLengths(LLCodes, DistCodes)
    local AllLengths = {} --The literal-length codes' lengths can continue into the distance codes' lengths
    local CompressedLengths = {}

    for i = 0, #LLCodes, 1 do
        AllLengths[#AllLengths+1] = LLCodes[i][2]
    end

    for i = 0, #DistCodes, 1 do
        AllLengths[#AllLengths+1] = DistCodes[i][2]
    end

    local i = 1

    while i <= #AllLengths do
        local RunLength = FindRunLength(AllLengths, i)

        if RunLength >= 4 then
            local ExtraBits

            if AllLengths[i] ~= 0 then
                ExtraBits = math.min(6, RunLength - 1)
                CompressedLengths[#CompressedLengths+1] = AllLengths[i]
                CompressedLengths[#CompressedLengths+1] = {16, ExtraBits}
                i = i + 1 --adding one since we pushed a length and symbol here
            elseif RunLength <= 10 then
                --Symbols 17 and 18 represent only 0s
                ExtraBits = math.min(10, RunLength)
                CompressedLengths[#CompressedLengths+1] = {17, ExtraBits}
            else
                ExtraBits = math.min(138, RunLength)
                CompressedLengths[#CompressedLengths+1] = {18, ExtraBits}
            end
            i = i + ExtraBits
        else
            CompressedLengths[#CompressedLengths+1] = AllLengths[i]
            i = i + 1
        end
    end

    return CompressedLengths
end

function WriteRawData(Bytes, ByteStream, Final)

    if #Bytes > 0xFFFF then print("Block type 0 can only have 2^16 - 1 Bytes") return end

    local LEN = #Bytes
    local NLEN = LEN ~ 0xFFFF

    ByteStream:PushBits(Final and 1 or 0, 1)
    ByteStream:PushBits(0, 2)
    ByteStream:PushBits(0, ByteStream.BitIndex ~= 0 and 8 - ByteStream.BitIndex or 0) -- padding until next byte

    ByteStream:PushNumber(LEN, 16)
    ByteStream:PushNumber(NLEN, 16)

    for i, Byte in pairs(Bytes) do
        ByteStream:PushNumber(Byte, 8)
    end
end

function CompressFixedDeflateBlock(Bytes, ByteStream, Final)
    local PrefixCodes = GenerateFixedCodes()

    ByteStream:PushBits(Final and 1 or 0, 1)
    ByteStream:PushNumber(1, 2)

    Bytes[#Bytes+1] = 256 --End of Block marker 

    for i, Byte in pairs(Bytes) do
        if type(Byte) == "number" then
            local CodeInfo = PrefixCodes[Byte]
            ByteStream:PushBits(CodeInfo[1], CodeInfo[2])
        else
            local LenBits = LengthCodes[Byte[1]][1]
            local DistBits = DistanceCodes[Byte[3]][1]
            local LenCodeInfo = PrefixCodes[Byte[1]]

            --distances have their own prefix codes!!! (the codes turn out to be just the number as 5 bits, but still pushed as a code)

            ByteStream:PushBits(LenCodeInfo[1], LenCodeInfo[2])
            ByteStream:PushNumber(Byte[2], LenBits)
            ByteStream:PushBits(Byte[3], 5)
            ByteStream:PushNumber(Byte[4], DistBits)
        end
    end

end

function CompressDynamicDeflateBlock(Bytes, ByteStream, Final)

    ByteStream:PushBits(Final and 1 or 0, 1)
    ByteStream:PushNumber(2, 2)

    Bytes[#Bytes+1] = 256

    --Generating all the huffman tables
    local LLFreq, DistFreq = GetLiteralDistFrequencies(Bytes)
    local LLCodes, DistCodes = GetPrefixCodes(LLFreq), GetPrefixCodes(DistFreq)
    if DistCodes[0] == nil then DistCodes[0] = {nil, 0} end --need to push a single distance code in case distances arent used since HDIST is 5 bits (0-32) and we encode HDIST - 1 so decoder expects at least 1 distance code
    local CompressedHuffmanLengths = CompressHuffmanLengths(LLCodes, DistCodes)
    local CLCodeFreq = GetCLSymbolFrequncies(CompressedHuffmanLengths)
    local CLCodePrefixCodes = GetPrefixCodes(CLCodeFreq)

    local CLCodesOrder = {}
    local HCLEN = 0 --HCLEN is calculated from where the lengths appear in the weird order

    for i, v in pairs(CLCodeAlpabetOrder) do
        if CLCodePrefixCodes[v] == nil then CLCodePrefixCodes[v] = {nil, 0} end
        CLCodesOrder[i] = CLCodePrefixCodes[v]
        if CLCodePrefixCodes[v][2] ~= 0 then
            HCLEN = i
        end
    end

    local HLIT = #LLCodes - 257 + 1 -- note: # operator in Lua returns length from 1 to last non-nil element in order in a table, so +1 for code 0
    local HDIST = #DistCodes - 1 + 1
    HCLEN = HCLEN - 4

    ByteStream:PushNumber(HLIT, 5)
    ByteStream:PushNumber(HDIST, 5)
    ByteStream:PushNumber(HCLEN, 4)

    for i = 1, HCLEN + 4, 1 do
        ByteStream:PushNumber(CLCodesOrder[i][2], 3)
    end

    for i, v in pairs(CompressedHuffmanLengths) do
        if type(v) == "table" then
            local PrefixCodeInfo = CLCodePrefixCodes[v[1]]
            local ExtraBitInfo = CLCodeExtraBits[v[1]]
            ByteStream:PushBits(PrefixCodeInfo[1], PrefixCodeInfo[2])
            ByteStream:PushNumber(v[2] - ExtraBitInfo[1], ExtraBitInfo[2])
        else
            local PrefixCodeInfo = CLCodePrefixCodes[v]
            ByteStream:PushBits(PrefixCodeInfo[1], PrefixCodeInfo[2])
        end
    end

    for i, Byte in pairs(Bytes) do
        if type(Byte) == "number" then
            local CodeInfo = LLCodes[Byte]
            ByteStream:PushBits(CodeInfo[1], CodeInfo[2])
        else
            local LenBits = LengthCodes[Byte[1]][1]
            local DistBits = DistanceCodes[Byte[3]][1]
            local LenCodeInfo = LLCodes[Byte[1]]
            local DistCodeInfo = DistCodes[Byte[3]]

            ByteStream:PushBits(LenCodeInfo[1], LenCodeInfo[2])
            ByteStream:PushNumber(Byte[2], LenBits)
            ByteStream:PushBits(DistCodeInfo[1], DistCodeInfo[2])
            ByteStream:PushNumber(Byte[4], DistBits)
        end
    end

end

function SplitIntoBlocks(Data) --Splitting into Deflate blocks of size 16384, this can be optimzed for better compression
    local Blocks = {}

    for i = 1, math.ceil(#Data/16384), 1 do
        Blocks[i] = {}
        local Idx = (i-1) * 16384 + 1

        for j = 1, 16384, 1 do
            Blocks[i][j] = Data[Idx]
            Idx = Idx + 1
        end
    end

    return Blocks
end

function Deflate(Data)
    --Zlib header
    local ByteStream = Stream.New()
    local CMF = "00001000" --Compression Method (DEFLATE) and flags
    local FLG = "00011101" --Compression and weird checksum such that (CMF * 256 + FLG) % 31 = 0

    ByteStream:PushNumber(tonumber(CMF, 2), 8) --I flippled the CMF and FLG so pushing reversed (like a number)
    ByteStream:PushNumber(tonumber(FLG, 2), 8)

    local SqueezedData = LZ77(Data)
    local Blocks = SplitIntoBlocks(SqueezedData)

    for i, Block in pairs(Blocks) do
        if #Block > 8192 then
            CompressDynamicDeflateBlock(Block, ByteStream, i == #Blocks)
        else
            CompressFixedDeflateBlock(Block, ByteStream, i == #Blocks)
        end
    end

    if ByteStream.BitIndex ~= 0 then --Stream padding to byte align is added before the adler32
        ByteStream:PushBits(0, 8 - ByteStream.BitIndex)
    end

    local Adler32 = GetAdler32(Data)

    ByteStream:PushNumber((Adler32 >> 24) & 0xFF, 8)
    ByteStream:PushNumber((Adler32 >> 16) & 0xFF, 8)
    ByteStream:PushNumber((Adler32 >> 8) & 0xFF, 8)
    ByteStream:PushNumber(Adler32 & 0xFF, 8)

    return ByteStream.Bytes
end

function AbsDiff(Data)
    local Sum = 0

    for i, v in pairs(Data) do
        Sum = Sum + (v < 128 and v or 256 - v)
    end

    return math.abs(Sum)
end

function FilterBytes(Bytes, BPP, FilterOn) --BPP (Bytes Per Pixel)
    local FilteredBytes = {}

    if not FilterOn then
        for i, row in pairs(Bytes) do
            FilteredBytes[i] = Filters.None(row)
        end
        return FilteredBytes
    end

    for i, row in pairs(Bytes) do
        local MinSum = 999999999999999999

        local NoneResult = Filters.None(row)
        local SubResult = Filters.Sub(row, BPP)
        local UpResult = Filters.Up(row, Bytes[i-1], BPP)
        local AvgResult = Filters.Average(row, Bytes[i-1], BPP)
        local PaethResult = Filters.Paeth(row, Bytes[i-1], BPP)
        local Results = {NoneResult, SubResult, UpResult, AvgResult, PaethResult}

        for j, v in pairs(Results) do
            local RowSum = AbsDiff(v)
            if RowSum < MinSum then
                MinSum = RowSum
                FilteredBytes[i] = v
            end
        end
    end

    return FilteredBytes
end

function EncodePNG(FileName, Width, Height, Pixels, ColorType, FilterOn)
    local Image = io.open(FileName, "wb")
    local BinaryInfo = {}

    if not (ColorType == 2 or ColorType == 6) then print("Currently only colortypes 2 and 6 are valid") return end

    --PNG File Header bytes in decimal
    BinaryInfo[1] = string.pack(">I1", 137)
    BinaryInfo[2] = string.pack(">I1", 80)
    BinaryInfo[3] = string.pack(">I1", 78)
    BinaryInfo[4] = string.pack(">I1", 71)
    BinaryInfo[5] = string.pack(">I1", 13)
    BinaryInfo[6] = string.pack(">I1", 10)
    BinaryInfo[7] = string.pack(">I1", 26)
    BinaryInfo[8] = string.pack(">I1", 10)

    --IHDR Chunk
    BinaryInfo[9] = string.pack(">I4", 13) -- chunk length

    local IHDR = {}
    IHDR[1] = string.pack(">I4",  1229472850) -- chunk type
    IHDR[2] = string.pack(">I4", Width)
    IHDR[3] = string.pack(">I4", Height)
    IHDR[4] = string.pack(">I1", 8) -- fixing bit depth at 8
    IHDR[5] = string.pack(">I1", ColorType)
    IHDR[6] = string.pack(">I1", 0) -- compression method is DEFLATE
    IHDR[7] = string.pack(">I1", 0) -- filter method (only method 0 is defined)
    IHDR[8] = string.pack(">I1", 0) -- interlace method 0 (no interlace), may implement later if needed
    IHDR[9] = string.pack(">I4", GetCRC32({string.byte(table.concat(IHDR), 1, 17)})) -- IHDR CRC

    BinaryInfo[10] = table.concat(IHDR)

    Pixels = FilterBytes(Pixels, ColorType == 2 and 3 or 4, FilterOn)
    Pixels = Filters.Vectorize(Pixels)

    local CompressedByteStream = Deflate(Pixels)

    local IDATChunks = math.ceil(#CompressedByteStream/65536)

    for i = 1, IDATChunks, 1 do
        local ByteIdx = (i-1)*65536
        local ChunkLen = math.min(65536, #CompressedByteStream - (i-1)*65536)
        BinaryInfo[#BinaryInfo+1] = string.pack(">I4", ChunkLen)

        local IDATChunk = {}
        IDATChunk[1] = string.pack(">I1", 0x49)
        IDATChunk[2] = string.pack(">I1", 0x44)
        IDATChunk[3] = string.pack(">I1", 0x41)
        IDATChunk[4] = string.pack(">I1", 0x54)

        for j = 1, ChunkLen, 1 do
            IDATChunk[j + 4] = string.pack(">I1", CompressedByteStream[ByteIdx + j])
        end

        IDATChunk[#IDATChunk+1] = string.pack(">I4", GetCRC32({string.byte(table.concat(IDATChunk), 1, #IDATChunk + 3)}))
        BinaryInfo[#BinaryInfo+1] = table.concat(IDATChunk)
    end

    BinaryInfo[#BinaryInfo+1] = string.pack(">I4", 0)

    local IEND = {}
    IEND[1] = string.pack(">I1", 73)
    IEND[2] = string.pack(">I1", 69)
    IEND[3] = string.pack(">I1", 78)
    IEND[4] = string.pack(">I1", 68)
    IEND[5] = string.pack(">I4", GetCRC32({string.byte(table.concat(IEND), 1, 4)}))

    BinaryInfo[#BinaryInfo+1] = table.concat(IEND)
    Image:write(table.concat(BinaryInfo))
    io.close(Image)
end

return EncodePNG
