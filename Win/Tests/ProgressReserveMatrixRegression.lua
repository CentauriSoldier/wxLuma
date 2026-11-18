local _Geometry = require("wxLuma.Core.ProgressShapeGeometry");
local _Reserve = require("wxLuma.Core.ControlProgressReserve");
local Matrix = {};
local _Opposite = {left = "right", right = "left", top = "bottom", bottom = "top"};
local _Rectangle = {{X = 0, Y = 0}, {X = 1, Y = 0}, {X = 1, Y = 1}, {X = 0, Y = 1}};
local _Hexagon = {{X = 0.5, Y = 0}, {X = 1, Y = 0.28}, {X = 0.86, Y = 1},
    {X = 0.14, Y = 1}, {X = 0, Y = 0.28}};
local _Concave = {{X = 0, Y = 0}, {X = 1, Y = 0.08}, {X = 0.57, Y = 0.47},
    {X = 0.94, Y = 1}, {X = 0.06, Y = 0.91}, {X = 0.31, Y = 0.43}};

--[[!
@fqxn wxLuma.Tests.ProgressReserveMatrixRegression.reference
@desc Independent per-pixel reference. Uses winding containment and a bisection
    measure of usable angular intervals rather than production scanline splitting.
!]]
local function reference(tShape, nMode, nSize, tSettings)
    local tPoints = {};
    local bBar = tShape.Name == "rectangle" and nMode == 0;
    local nInset = bBar and 0 or 2;
    local tVertices = tShape.Vertices or _Rectangle;
    for i, p in ipairs(tVertices) do tPoints[i] = {X = nInset + p.X * (nSize - nInset * 2), Y = nInset + p.Y * (nSize - nInset * 2)}; end
    local nCX, nCY, nRadius = nSize / 2, nSize / 2, 0;
    local nMinX, nMinY, nMaxX, nMaxY = math.huge, math.huge, -math.huge, -math.huge;
    for _, p in ipairs(tPoints) do nMinX, nMinY, nMaxX, nMaxY = math.min(nMinX, p.X), math.min(nMinY, p.Y), math.max(nMaxX, p.X), math.max(nMaxY, p.Y); end
    nCX, nCY = (nMinX + nMaxX) / 2, (nMinY + nMaxY) / 2;
    if (tShape.Name == "circle") then nRadius = nSize / 2 - 2;
    else for _, p in ipairs(tPoints) do nRadius = math.max(nRadius, math.sqrt((p.X - nCX)^2 + (p.Y - nCY)^2)); end end
    local nOuter = nRadius * (tSettings.OuterRadius or 100) / 100;
    local nInner = tSettings.InnerRadius and nRadius * tSettings.InnerRadius / 100
        or nMode == 2 and tSettings.Thickness and math.max(0, nOuter - tSettings.Thickness) or 0;

    --[[!
    @fqxn wxLuma.Tests.ProgressReserveMatrixRegression.reference.linear
    @desc Computes each cardinal coordinate explicitly from the independent bounds.
    !]]
    local function fLinear(sOrigin, x, y)
        if (sOrigin == "left") then return (x - nMinX) / (nMaxX - nMinX);
        elseif (sOrigin == "right") then return (nMaxX - x) / (nMaxX - nMinX);
        elseif (sOrigin == "top") then return (y - nMinY) / (nMaxY - nMinY); end
        return (nMaxY - y) / (nMaxY - nMinY);
    end

    --[[!
    @fqxn wxLuma.Tests.ProgressReserveMatrixRegression.reference.coordinates
    @desc Tests the silhouette with winding number, then evaluates distance or angle.
    !]]
    local function fCoordinates(x, y)
        local nDX, nDY = x - nCX, y - nCY;
        local nDistance = math.sqrt(nDX * nDX + nDY * nDY);
        if (tShape.Name == "circle") then
            if (nDistance >= nRadius) then return nil; end
        else
            local nWinding = 0;
            for i, a in ipairs(tPoints) do
                local b = tPoints[i % #tPoints + 1];
                local nSide = (b.X - a.X) * (y - a.Y) - (x - a.X) * (b.Y - a.Y);
                if (a.Y <= y and b.Y > y and nSide > 0) then nWinding = nWinding + 1;
                elseif (a.Y > y and b.Y <= y and nSide < 0) then nWinding = nWinding - 1; end
            end
            if (nWinding == 0) then return nil; end
        end
        if (nMode == 0) then return fLinear(tSettings.Origin, x, y), fLinear(tSettings.ReserveOrigin, x, y); end
        if (nDistance < nInner or nDistance >= nOuter or nOuter <= nInner) then return nil; end
        if (nMode == 1) then
            local u = (nDistance - nInner) / (nOuter - nInner);
            return tSettings.Direction == "outward" and u or 1 - u, tSettings.ReserveDirection == "outward" and u or 1 - u;
        end
        local nAngle = math.deg(math.atan(nDY, nDX)) + 90;
        return (tSettings.Direction == "CW" and nAngle - tSettings.StartAngle or tSettings.StartAngle - nAngle) % 360 / 360,
            (tSettings.ReserveDirection == "CW" and nAngle - tSettings.ReserveStartAngle or tSettings.ReserveStartAngle - nAngle) % 360 / 360;
    end

    --[[!
    @fqxn wxLuma.Tests.ProgressReserveMatrixRegression.reference.threshold
    @desc Computes expected usable-path cutoff using clipping or independent
        overlap integration; continuous boundary ties are reported separately.
    !]]
    local function fThreshold(r, current)
        if (nMode == 0 and tSettings.Origin ~= tSettings.ReserveOrigin and _Opposite[tSettings.Origin] ~= tSettings.ReserveOrigin) then
            if (tShape.Name == "circle") then
                local e = r > 0.5 and math.sqrt(math.max(0, 1 - (2 * r - 1)^2)) or 1;
                return (1 - e) / 2 + current * e;
            end
            local tClipped = {};
            local a = tPoints[#tPoints]; local nA = fLinear(tSettings.ReserveOrigin, a.X, a.Y);
            for _, b in ipairs(tPoints) do
                local nB = fLinear(tSettings.ReserveOrigin, b.X, b.Y);
                if ((nA >= r) ~= (nB >= r)) then
                    local t = (r - nA) / (nB - nA);
                    tClipped[#tClipped + 1] = {X = a.X + (b.X - a.X) * t, Y = a.Y + (b.Y - a.Y) * t};
                end
                if (nB >= r) then tClipped[#tClipped + 1] = b; end
                a, nA = b, nB;
            end
            local low, high = math.huge, -math.huge;
            for _, p in ipairs(tClipped) do local u = fLinear(tSettings.Origin, p.X, p.Y); low, high = math.min(low, u), math.max(high, u); end
            return low <= high and low + current * (high - low) or 0;
        elseif (nMode ~= 2) then
            local bSame = nMode == 0 and tSettings.Origin == tSettings.ReserveOrigin or nMode == 1 and tSettings.Direction == tSettings.ReserveDirection;
            return bSame and r + current * (1 - r) or current * (1 - r);
        end
        local nOffset = ((tSettings.ReserveStartAngle - tSettings.StartAngle) * (tSettings.Direction == "CW" and 1 or -1)) % 360 / 360;
        local low = tSettings.Direction == tSettings.ReserveDirection and nOffset or nOffset - r;
        local high = low + r;
        local a, b = 0, 1;
        local nTarget = current * (1 - r);
        for _ = 1, 48 do
            local mid, nExcluded = (a + b) / 2, 0;
            for turn = -2, 2 do nExcluded = nExcluded + math.max(0, math.min(mid, high + turn) - math.max(0, low + turn)); end
            if (mid - nExcluded < nTarget) then a = mid; else b = mid; end
        end
        return (a + b) / 2;
    end
    return {coordinates = fCoordinates, threshold = fThreshold, Center = nCX, Radius = nRadius, Inner = nInner, Outer = nOuter};
end

--[[!
@fqxn wxLuma.Tests.ProgressReserveMatrixRegression.run
@desc Exhausts the declared direction/automatic-reserve/band/angle/state grid for
    rectangle, circle, convex and concave polygons. Production span painters write
    a software collector; every non-boundary sample is compared with the independent
    pixel reference. This tests actual mask output without millions of native GDI allocations.
!]]
function Matrix.run()
    local nSamples, nBoundaryTies, nMasks, nGeometries, nCachedSamples = 0, 0, 0, 0, 0;
    local nSize = 20;
    local tShapes = {{Name = "rectangle", Vertices = _Rectangle}, {Name = "circle"},
        {Name = "convex", Vertices = _Hexagon}, {Name = "concave", Vertices = _Concave}};
    local tAngles = {0, 45, 90, 180, 270, 359};
    local tBands = {{InnerRadius = 0, OuterRadius = 100}, {InnerRadius = 25, OuterRadius = 90},
        {InnerRadius = 60, OuterRadius = 100}, {Thickness = 3}};
    local tBrushes = {Track = 1, Fill = 2, Reserve = 3};
    local tPixels, nBrush, bOverlay = {}, 0, false;
    local oCollector = {};
    function oCollector:SetBrush(nPart) nBrush = nPart; end
    function oCollector:DrawRectangle(x, y, width, height)
        assert(height == 1 and x >= 0 and y >= 0 and x + width <= nSize and y < nSize, "Mask span escaped the raster.");
        for nX = x, x + width - 1 do
            local i = y * nSize + nX + 1;
            assert(tPixels[i] == nil or bOverlay and nBrush == 2 and tPixels[i] == 1,
                "Fill/reserve mask spans overlap or cached fill touched reserved pixels."); tPixels[i] = nBrush;
        end
    end

    --[[!
    @fqxn wxLuma.Tests.ProgressReserveMatrixRegression.run.case
    @desc Runs every reserve/current combination against one geometry and direction pairing.
    !]]
    local function fCase(tShape, nMode, tSettings)
        nGeometries = nGeometries + 1;
        local tReference = reference(tShape, nMode, nSize, tSettings);
        local tProduction;
        local bLegacy = tShape.Name == "circle" or tShape.Name == "rectangle" and nMode == 0;
        if (not bLegacy) then tProduction = _Geometry.prepare(tShape.Vertices, nSize, nSize, 1, nMode, tSettings); end
        local tExpectedCoordinates = {};
        for y = 0, nSize - 1 do for x = 0, nSize - 1 do
            local u, v = tReference.coordinates(x + 0.5, y + 0.5);
            if (u) then tExpectedCoordinates[y * nSize + x + 1] = {u, v}; end
        end end
        local tNative = {Kind = nMode == 2 and "circular" or nMode == 1 and "radial" or tShape.Name == "circle" and "globe" or "bar",
            Center = tReference.Center, Radius = tReference.Outer, Inner = tReference.Inner,
            Origin = tSettings.Origin, ReserveOrigin = tSettings.ReserveOrigin, Direction = tSettings.Direction,
            ReserveDirection = tSettings.ReserveDirection, StartAngle = tSettings.StartAngle, ReserveStartAngle = tSettings.ReserveStartAngle};
        local function fLegacyCoordinates(x, y) return tReference.coordinates(x + 0.5, y + 0.5); end
        for _, r in ipairs({0, 0.25, 0.5, 0.75, 1}) do
            local tPlan = not bLegacy and tProduction.reservePlan(r);
            for _, current in ipairs({0, 0.23, 0.5, 0.77, 1}) do
                -- With no usable capacity, stored current is Min regardless of request.
                if (r == 1) then current = 0; end
                tPixels = {}; nMasks = nMasks + 1;
                if (bLegacy) then _Reserve.drawMask(oCollector, nSize, nSize, fLegacyCoordinates, r, current, tBrushes, tNative);
                else tProduction.paint(oCollector, r, current, tBrushes); end
                if (tPlan) then
                    local tOriginal = tPixels; tPixels = {};
                    tProduction.paintBase(oCollector, tPlan, tBrushes);
                    bOverlay = true; tProduction.paintFill(oCollector, tPlan, current, tBrushes.Fill); bOverlay = false;
                    for i = 1, nSize * nSize do
                        nCachedSamples = nCachedSamples + 1;
                        if (tPixels[i] ~= tOriginal[i]) then error(string.format(
                            "Cached parity: shape=%s mode=%d direction=%s reserve=%s angle=%s reserveAngle=%s r=%g current=%g pixel=%d old=%s new=%s",
                            tShape.Name, nMode, tostring(tSettings.Direction or tSettings.Origin), tostring(tSettings.ReserveDirection or tSettings.ReserveOrigin),
                            tostring(tSettings.StartAngle), tostring(tSettings.ReserveStartAngle), r, current, i, tostring(tOriginal[i]), tostring(tPixels[i]))); end
                    end
                end
                local threshold = tReference.threshold(r, current);
                for i = 1, nSize * nSize do
                    local p, nExpected = tExpectedCoordinates[i], 0;
                    if (p) then nExpected = (r >= 1 or p[2] < r) and 3 or current > 0 and (current >= 1 or p[1] < threshold) and 2 or 1; end
                    local actual = tPixels[i] or 0;
                    if (p) then
                        assert(actual >= 1 and actual <= 3, "The shape contains an unpainted hole.");
                        assert(current ~= 0 or actual ~= 2, "An empty usable path contains fill.");
                        assert(r ~= 0 or actual ~= 3, "A zero-reserve mask contains reserved pixels.");
                        assert(r ~= 1 or actual == 3, "A fully reserved mask contains usable pixels.");
                        assert(current ~= 1 or r ~= 0 or actual == 2, "A full unreserved shape contains unfilled pixels.");
                    end
                    local bTie = p and (math.abs(p[2] - r) < 1e-10 or math.abs(p[1] - threshold) < 1e-10
                        or nMode == 2 and (math.min(p[1], 1 - p[1]) < 1e-10 or math.min(p[2], 1 - p[2]) < 1e-10));
                    if (bTie) then nBoundaryTies = nBoundaryTies + 1;
                    else
                        nSamples = nSamples + 1;
                        if ((tPixels[i] or 0) ~= nExpected) then error(string.format(
                            "Reserve mask mismatch shape=%s mode=%d origin=%s reserveOrigin=%s direction=%s reserveDirection=%s angle=%s reserveAngle=%s r=%g current=%g pixel=%d expected=%d actual=%d",
                            tShape.Name, nMode, tostring(tSettings.Origin), tostring(tSettings.ReserveOrigin), tostring(tSettings.Direction),
                            tostring(tSettings.ReserveDirection), tostring(tSettings.StartAngle), tostring(tSettings.ReserveStartAngle), r, current, i, nExpected, tPixels[i] or 0)); end
                    end
                end
            end
        end
    end
    for _, tShape in ipairs(tShapes) do
        for _, origin in ipairs({"left", "right", "top", "bottom"}) do
            for _, reserve in ipairs({"auto", "left", "right", "top", "bottom"}) do
                fCase(tShape, 0, {Origin = origin, ReserveOrigin = reserve == "auto" and _Opposite[origin] or reserve});
            end
        end
        for _, direction in ipairs({"outward", "inward"}) do
            for _, reserve in ipairs({"auto", "outward", "inward"}) do
                for i = 1, 3 do
                    local tBand = tBands[i];
                    fCase(tShape, 1, {Direction = direction, ReserveDirection = reserve == "auto" and (direction == "outward" and "inward" or "outward") or reserve,
                        InnerRadius = tBand.InnerRadius, OuterRadius = tBand.OuterRadius});
                end
            end
        end
        for _, direction in ipairs({"CW", "CCW"}) do
            for _, reserve in ipairs({"auto", "CW", "CCW"}) do
                for _, angle in ipairs(tAngles) do
                    for _, reserveAngle in ipairs({"auto", 0, 45, 90, 180, 270, 359}) do
                        for _, band in ipairs(tBands) do
                            fCase(tShape, 2, {Direction = direction, ReserveDirection = reserve == "auto" and (direction == "CW" and "CCW" or "CW") or reserve,
                                StartAngle = angle, ReserveStartAngle = reserveAngle == "auto" and angle or reserveAngle,
                                InnerRadius = band.InnerRadius, OuterRadius = band.OuterRadius, Thickness = band.Thickness});
                        end
                    end
                end
            end
        end
    end
    print(string.format("Reserve matrix: %d geometries, %d masks, %d exact samples passed (%d floating boundary ties excluded).",
        nGeometries, nMasks, nSamples, nBoundaryTies));
    print("Cached fill parity: "..nCachedSamples.." pixel comparisons passed, including boundary pixels.");
    return {Geometries = nGeometries, Masks = nMasks, Samples = nSamples, BoundaryTies = nBoundaryTies, CachedSamples = nCachedSamples};
end

return Matrix;
