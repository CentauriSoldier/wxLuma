local _wx     = require("wx");
local _finite = require("UI.Core.ControlNumeric").finite;
local ControlProgressReserve = {};

ControlProgressReserve.Events = {
    "reservedChanged", "reserveOriginChanged", "reserveDirectionChanged",
    "reserveStartAngleChanged", "radiiChanged"
};

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.validate
@desc Validates optional reserve and radius settings before creating native resources.
@param table tOptions Progress creation options.
@param string sKind Progress, GlobeProgress, RadialProgress, CircularProgress or IrisProgress.
!]]
function ControlProgressReserve.validate(tOptions, sKind)
    local nReserved = tOptions.Reserved or 0;
    assert(_finite(nReserved) and nReserved >= 0 and nReserved <= tOptions.Max - tOptions.Min,
        "Reserved must be finite and within the progress range.");
    local sOrigin = tOptions.ReserveOrigin;
    assert(sOrigin == nil or ((sKind == "Progress" or sKind == "GlobeProgress")
        and (sOrigin == "left" or sOrigin == "right" or sOrigin == "top" or sOrigin == "bottom")),
        "ReserveOrigin requires a linear progress control and a valid edge.");
    local sDirection = tOptions.ReserveDirection;
    assert(sDirection == nil or (sKind == "CircularProgress" and (sDirection == "CW" or sDirection == "CCW"))
        or ((sKind == "RadialProgress" or sKind == "IrisProgress") and (sDirection == "inward" or sDirection == "outward")),
        "Invalid reserve direction for this progress control.");
    assert(tOptions.ReserveStartAngle == nil or (sKind == "CircularProgress"
        and _finite(tOptions.ReserveStartAngle)), "ReserveStartAngle requires circular progress and finite degrees.");
    local nInner = tOptions.InnerRadius;
    local nOuter = tOptions.OuterRadius;
    assert((nInner == nil and nOuter == nil) or sKind == "CircularProgress" or sKind == "RadialProgress",
        "Radius settings require circular or radial progress.");
    nInner, nOuter = nInner or 0, nOuter or 100;
    assert(_finite(nInner) and _finite(nOuter) and nInner >= 0 and nInner < nOuter and nOuter <= 100,
        "Radii must satisfy 0 <= inner < outer <= 100.");
end

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.attach
@desc Composes general resource reservations independently of any resource model.
    Current values remain unchanged when capacity is reserved; drawing saturates
    at effective maximum. Nil reserve geometry follows the full end of the fill.
@param table oComponent Public progress object.
@param table tOptions Validated creation settings.
@param table tEvents Component event dispatcher.
@param string sKind Public progress kind.
@ret table tPolicy Private geometry and rendering settings.
!]]
function ControlProgressReserve.attach(oComponent, tOptions, tEvents, sKind)
    local tPolicy = {
        Reserved = tOptions.Reserved or 0,
        ReserveOrigin = tOptions.ReserveOrigin,
        ReserveDirection = tOptions.ReserveDirection,
        ReserveStartAngle = tOptions.ReserveStartAngle and tOptions.ReserveStartAngle % 360,
        InnerRadius = tOptions.InnerRadius,
        OuterRadius = tOptions.OuterRadius
    };

    if (tPolicy.InnerRadius ~= nil or tPolicy.OuterRadius ~= nil) then
        tPolicy.InnerRadius = tPolicy.InnerRadius or 0;
        tPolicy.OuterRadius = tPolicy.OuterRadius or 100;
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.getReserved
    @desc Returns capacity excluded from normal progress, in value units.
    @ret number nReserved Reserved amount; zero by default.
    !]]
    function oComponent.getReserved()
        return tPolicy.Reserved;
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.getEffectiveMax
    @desc Returns Max minus reserved capacity, including a nonzero Min offset.
    @ret number nMaximum Value considered full.
    !]]
    function oComponent.getEffectiveMax()
        return oComponent.Max - tPolicy.Reserved;
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.isFull
    @desc Tests current against usable capacity. An entirely reserved range has
        no usable capacity and is full at Min. No value is modified.
    @ret boolean bFull Whether current reaches the effective maximum.
    !]]
    function oComponent.isFull()
        return oComponent.Value >= oComponent.getEffectiveMax();
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.setReserved
    @desc Changes excluded capacity without changing current. Repeated values do
        not repaint or notify. Invalid values preserve the previous state.
    @param number nValue Capacity in [0, Max - Min].
    @param boolean|nil bNotify Emit reservedChanged with old/new amounts and effective maximum.
    @ret table oComponent This component.
    !]]
    function oComponent.setReserved(nValue, bNotify)
        assert(_finite(nValue) and nValue >= 0 and nValue <= oComponent.Max - oComponent.Min,
            "Reserved must be finite and within the progress range.");

        if (not oComponent.Disposed and tPolicy.Reserved ~= nValue) then
            local nOld = tPolicy.Reserved;
            tPolicy.Reserved = nValue;
            oComponent.refresh();

            if (bNotify) then
                tEvents.emit("reservedChanged", {Reserved = nValue, OldReserved = nOld,
                    EffectiveMax = oComponent.getEffectiveMax()});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.geometryAccessors
    @desc Installs matching get/set methods for each applicable reserve geometry
        property. Getters return nil for automatic placement; setters accept nil
        to restore it. Optional notifications contain the old and new settings.
    !]]
    local function fGeometryAccessors(sName, sEvent, fValidate)
        oComponent["get"..sName] = function()
            return tPolicy[sName];
        end;
        oComponent["set"..sName] = function(vValue, bNotify)
            assert(vValue == nil or fValidate(vValue), "Invalid "..sName..".");

            if (sName == "ReserveStartAngle" and vValue ~= nil) then
                vValue = vValue % 360;
            end

            if (not oComponent.Disposed and tPolicy[sName] ~= vValue) then
                local vOld = tPolicy[sName];
                tPolicy[sName] = vValue;
                oComponent.refresh();

                if (bNotify) then
                    tEvents.emit(sEvent, {[sName] = vValue, ["Old"..sName] = vOld});
                end
            end

            return oComponent;
        end;
    end

    if (sKind == "Progress" or sKind == "GlobeProgress") then
        fGeometryAccessors("ReserveOrigin", "reserveOriginChanged", function(sValue)
            return sValue == "left" or sValue == "right" or sValue == "top" or sValue == "bottom";
        end);
    else
        fGeometryAccessors("ReserveDirection", "reserveDirectionChanged", function(sValue)
            return sKind == "CircularProgress" and (sValue == "CW" or sValue == "CCW")
                or (sKind == "RadialProgress" or sKind == "IrisProgress") and (sValue == "inward" or sValue == "outward");
        end);
    end

    if (sKind == "CircularProgress") then
        fGeometryAccessors("ReserveStartAngle", "reserveStartAngleChanged", _finite);
    end

    if (sKind == "CircularProgress" or sKind == "RadialProgress") then
        --[[!
        @fqxn wxLuma.UI.ControlProgressReserve.getRadii
        @desc Returns explicit inner/outer percentages. Nil inner on a circular
            control denotes its legacy pixel Thickness; radial defaults to zero.
        @ret number|nil nInner Inner percentage or legacy thickness mode.
        @ret number nOuter Outer percentage, default 100.
        !]]
        function oComponent.getRadii()
            local nInner = tPolicy.InnerRadius;

            if (nInner == nil and sKind == "RadialProgress") then
                nInner = 0;
            end

            return nInner, tPolicy.OuterRadius or 100;
        end

        --[[!
        @fqxn wxLuma.UI.ControlProgressReserve.setRadii
        @desc Atomically sets a radial band in percentages of the available radius.
            Inner zero enables a solid pie; nil/nil restores original geometry.
        @param number|nil nInner Inner percentage; defaults to zero when outer supplied.
        @param number|nil nOuter Outer percentage; defaults to 100 when inner supplied.
        @param boolean|nil bNotify Emit radiiChanged after an effective change.
        @ret table oComponent This component.
        !]]
        function oComponent.setRadii(nInner, nOuter, bNotify)
            if (nInner ~= nil or nOuter ~= nil) then
                nInner, nOuter = nInner or 0, nOuter or 100;
                assert(_finite(nInner) and _finite(nOuter) and nInner >= 0
                    and nInner < nOuter and nOuter <= 100, "Invalid radius percentages.");
            end

            if (not oComponent.Disposed and (nInner ~= tPolicy.InnerRadius or nOuter ~= tPolicy.OuterRadius)) then
                local nOldInner, nOldOuter = tPolicy.InnerRadius, tPolicy.OuterRadius;
                tPolicy.InnerRadius, tPolicy.OuterRadius = nInner, nOuter;
                oComponent.refresh();

                if (bNotify) then
                    tEvents.emit("radiiChanged", {InnerRadius = nInner, OuterRadius = nOuter,
                        OldInnerRadius = nOldInner, OldOuterRadius = nOldOuter});
                end
            end

            return oComponent;
        end
    end

    return tPolicy;
end

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.drawMask
@desc Draws disjoint current/track/reserve spans using analytic intersections.
    Only shape boundaries are evaluated: work scales with scanlines rather than
    raster area. Brushes remain aligned to the complete control. Fill coordinates
    measure usable path length, preserving linear/angular/radial semantics.
@param wxDC oDC Borrowed destination, already cleared.
@param number nWidth Raster width.
@param number nHeight Raster height.
@param function fCoordinates Returns normal/reserve coordinates, or nil outside shape.
@param number nReserve Reserved capacity fraction.
@param number nCurrent Current fraction of usable capacity.
@param table tBrushes Borrowed Track, Fill and Reserve brushes.
@param table tGeometry Shape, origins, directions, angles and radius boundaries.
!]]
function ControlProgressReserve.drawMask(oDC, nWidth, nHeight, fCoordinates, nReserve, nCurrent, tBrushes, tGeometry)
    local tIntervals = {};
    local bCircular = tGeometry.Kind == "circular";
    local bRadial = tGeometry.Kind == "radial";
    local tOpposite = {left = "right", right = "left", top = "bottom", bottom = "top"};
    nCurrent = math.max(0, math.min(1, nCurrent));

    -- Express a reserve on the normal path. Wrapped angular intervals split at
    -- zero; aligned linear/radial paths have only one excluded interval.
    if (bCircular) then
        local nSign = tGeometry.Direction == "CW" and 1 or -1;
        local nStart = ((tGeometry.ReserveStartAngle - tGeometry.StartAngle) * nSign) % 360 / 360;
        local bSame = tGeometry.Direction == tGeometry.ReserveDirection;
        local nLow = bSame and nStart or nStart - nReserve;
        local nHigh = bSame and nStart + nReserve or nStart;

        for nTurn = -1, 1 do
            local nA, nB = math.max(0, nLow + nTurn), math.min(1, nHigh + nTurn);

            if (nB > nA) then
                tIntervals[#tIntervals + 1] = {nA, nB};
            end
        end
    elseif (bRadial or tGeometry.Origin == tGeometry.ReserveOrigin) then
        local bSame = not bRadial or tGeometry.Direction == tGeometry.ReserveDirection;
        tIntervals[1] = bSame and {0, nReserve} or {1 - nReserve, 1};
    elseif (tOpposite[tGeometry.Origin] == tGeometry.ReserveOrigin) then
        tIntervals[1] = {1 - nReserve, 1};
    end

    table.sort(tIntervals, function(tLeft, tRight)
        return tLeft[1] < tRight[1];
    end);
    local nUsable = 1;

    for _, tInterval in ipairs(tIntervals) do
        nUsable = nUsable - (tInterval[2] - tInterval[1]);
    end

    local nRemaining = nCurrent * math.max(0, nUsable);
    local nCursor, nThreshold = 0, 0;

    for _, tInterval in ipairs(tIntervals) do
        local nGap = tInterval[1] - nCursor;

        if (nRemaining <= nGap) then
            break;
        end

        nRemaining = nRemaining - nGap;
        nCursor = tInterval[2];
    end

    nThreshold = math.min(1, nCursor + nRemaining);

    -- A perpendicular cut through a globe can remove both ends of its normal
    -- path. Its remaining chord determines the usable coordinate range.
    if (tGeometry.Kind == "globe" and #tIntervals == 0 and nReserve > 0.5) then
        local nExtent = math.sqrt(math.max(0, 1 - (2 * nReserve - 1)^2));
        nThreshold = (1 - nExtent) / 2 + nCurrent * nExtent;
    end

    local nCenter = tGeometry.Center;
    local nRadius = tGeometry.Radius;
    local nInner = tGeometry.Inner or 0;
    local tAngles = {};
    local tCircles = {};
    local tVertical = {};

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.drawMask.boundary
    @desc Adds intersections for one linear, angular or radial boundary.
    !]]
    local function fBoundary(sPolicy, nFraction, nAngle)
        if (bCircular) then
            tAngles[#tAngles + 1] = nAngle + (sPolicy == "CW" and 1 or -1) * nFraction * 360;
        elseif (bRadial) then
            tCircles[#tCircles + 1] = sPolicy == "outward"
                and nInner + (nRadius - nInner) * nFraction
                or nRadius - (nRadius - nInner) * nFraction;
        elseif (sPolicy == "left" or sPolicy == "right") then
            local nLength = tGeometry.Kind == "bar" and nWidth or 2 * nRadius;
            local nStart = tGeometry.Kind == "bar" and 0 or nCenter - nRadius;
            tVertical[#tVertical + 1] = nStart + nLength * (sPolicy == "left" and nFraction or 1 - nFraction);
        end
    end

    if (bCircular or bRadial) then
        fBoundary(tGeometry.Direction, 0, tGeometry.StartAngle);
        fBoundary(tGeometry.Direction, nThreshold, tGeometry.StartAngle);
        fBoundary(tGeometry.ReserveDirection, 0, tGeometry.ReserveStartAngle);
        fBoundary(tGeometry.ReserveDirection, nReserve, tGeometry.ReserveStartAngle);
    else
        fBoundary(tGeometry.Origin, nThreshold);
        fBoundary(tGeometry.ReserveOrigin, nReserve);
    end

    if (tGeometry.Kind ~= "bar") then
        tCircles[#tCircles + 1] = nRadius;

        if (nInner > 0) then
            tCircles[#tCircles + 1] = nInner;
        end
    end

    for nY = 0, nHeight - 1 do
        local tBreaks = {0, nWidth};
        local nDY = nCenter and nY + 0.5 - nCenter or 0;

        --[[!
        @fqxn wxLuma.UI.ControlProgressReserve.drawMask.addIntersection
        @desc Converts a geometric boundary into the first pixel center beyond it.
        !]]
        local function fAdd(nX)
            tBreaks[#tBreaks + 1] = math.max(0, math.min(nWidth, math.ceil(nX - 0.5)));
        end

        for _, nX in ipairs(tVertical) do
            fAdd(nX);
        end

        for _, nCircle in ipairs(tCircles) do
            if (math.abs(nDY) < nCircle) then
                local nDX = math.sqrt(nCircle * nCircle - nDY * nDY);
                fAdd(nCenter - nDX);
                fAdd(nCenter + nDX);
            end
        end

        for _, nAngle in ipairs(tAngles) do
            local nRadians = math.rad(nAngle);
            local nCos = math.cos(nRadians);

            if (math.abs(nCos) > 0.000000001) then
                fAdd(nCenter - nDY * math.sin(nRadians) / nCos);
            end
        end

        table.sort(tBreaks);

        for nIndex = 1, #tBreaks - 1 do
            local nStart, nEnd = tBreaks[nIndex], tBreaks[nIndex + 1];

            if (nEnd > nStart) then
                local nFill, nReserved = fCoordinates((nStart + nEnd - 1) / 2, nY);

                if (nFill) then
                    local sState = (nReserve >= 1 or nReserved < nReserve) and "Reserve"
                        or (nCurrent > 0 and (nCurrent >= 1 or nFill < nThreshold) and "Fill" or "Track");
                    oDC:SetBrush(tBrushes[sState]);
                    oDC:DrawRectangle(nStart, nY, nEnd - nStart, 1);
                end
            end
        end
    end
end

return ControlProgressReserve;
