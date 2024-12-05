local Stream = {}

local ReversedBytes = {}

Stream.__index = Stream

for i = 0, 255, 1 do
    local Num = i
    Num = ((Num << 4) & 0xF0) | ((Num >> 4) & 0xF)
    Num = ((Num << 2) & 0xCC) | ((Num >> 2) & 0x33)
    Num = ((Num << 1) & 0xAA) | ((Num >> 1) & 0x55)
    ReversedBytes[i] = Num
end

function Stream.New()
    local NewStream = {}
    NewStream.__index = NewStream
    NewStream.Bytes = {}
    NewStream.CurrentByte = 0
    NewStream.BitIndex = 0

    function NewStream:PushBit(Bit)
        self.CurrentByte = self.CurrentByte << 1 | Bit

        self.BitIndex = self.BitIndex + 1
        if self.BitIndex == 8 then
            self.Bytes[#self.Bytes+1] = ReversedBytes[self.CurrentByte]
            self.BitIndex = 0
            self.CurrentByte = 0
        end
    end

    function NewStream:PushBits(Num, Bits)
        for i = Bits-1, 0, -1 do
            --print((Num >> i) & 1)
            self:PushBit((Num >> i) & 1)
        end
    end

    function NewStream:PushNumber(Num, Bits)
        for i = 0, Bits-1, 1 do
            self:PushBit((Num >> i) & 1)
        end
    end

    return NewStream
end

return Stream