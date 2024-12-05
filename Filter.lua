local Filters = {}

function Filters.None(Row)
    local FilteredBytes = {0}
    local Depth = #Row[1]

    for p = 1, #Row, 1 do
        for c = 1, Depth, 1 do
            FilteredBytes[#FilteredBytes+1] = Row[p][c]
        end
    end
    return FilteredBytes
end

function Filters.Sub(Row, BPP)
    local FilteredBytes = {1}

    for p = 1, BPP, 1 do
        FilteredBytes[#FilteredBytes+1] = Row[1][p]
    end

    for p = 2, #Row, 1 do
        for c = 1, BPP, 1 do
            FilteredBytes[#FilteredBytes+1] = (Row[p][c] - Row[p-1][c]) % 256
        end
    end

    return FilteredBytes
end

function Filters.Up(Row, Prior, BPP)
    local FilteredBytes = {2}
    if Prior == nil then return Filters.None(Row) end

    for p = 1, #Row, 1 do
        for c = 1, BPP, 1 do
            FilteredBytes[#FilteredBytes+1] = (Row[p][c] - Prior[p][c]) % 256
        end
    end
    return FilteredBytes
end

function Filters.Average(Row, Prior, BPP)
    local FilteredBytes = {3}
    for p = 1, #Row, 1 do
        for c = 1, BPP, 1 do
            local Above = Prior ~= nil and Prior[p][c] or 0
            local Prev = Row[p-1] ~= nil and Row[p-1][c] or 0

            FilteredBytes[#FilteredBytes+1] = (Row[p][c] - math.floor((Prev + Above)/2)) % 256
        end
    end
    return FilteredBytes
end

local function Paeth(a, b, c) --Paeth algorithm as defined in the PNG spec
    local Estimate = a + b - c
    local ADist = math.abs(Estimate - a)
    local BDist = math.abs(Estimate - b)
    local CDist = math.abs(Estimate - c)
    if ADist <= BDist and ADist <= CDist then return a end
    if BDist <= CDist then return b end
    return c
end

function Filters.Paeth(Row, Prior, BPP)
    local FilteredBytes = {4}
    for p = 1, #Row, 1 do
        for c = 1, BPP, 1 do
            local Prev = Row[p-1] ~= nil and Row[p-1][c] or 0
            local Above = Prior ~= nil and Prior[p][c] or 0
            local PrevAbove = (Prior ~= nil and Prior[p-1] ~= nil) and Prior[p-1][c] or 0

            FilteredBytes[#FilteredBytes+1] = (Row[p][c] - Paeth(Prev, Above, PrevAbove)) % 256
        end
    end
    return FilteredBytes
end

function Filters.Vectorize(Matrix)
	local Vector = {}
	for row, v in pairs(Matrix) do
		for num, _ in pairs(Matrix[row]) do
			Vector[#Vector+1] = Matrix[row][num]
		end
	end
	if type(Vector[1]) == "table" then
		Vector = Filters.Vectorize(Vector)
	end
	return Vector
end

return Filters