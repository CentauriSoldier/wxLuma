local _wx             = require("wx");
local _ControlSurface = require("UI.Core.ControlSurface");
local _ControlEvents  = require("UI.Core.ControlEvents");
local _finite         = require("UI.Core.ControlNumeric").finite;
local CircularProgress = {};

--[[!
@fqxn wxLuma.UI.CircularProgress.create
@desc Creates a determinate ring starting at twelve o'clock. Direction may change
    without changing progress. The parent owns the native control; no timer runs.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Min, Max, Value; optional Direction (CW or CCW, default
    CW), Thickness (positive pixels, default 12), Text (%v/current, %m/max), Colour
    ({R,G,B}), Enabled, OnChange and standard containment options.
@ret table oComponent An independent public object with shared surface/events API.
!]]
function CircularProgress.create(oParent, tOptions)
    assert(_finite(tOptions.Min) and _finite(tOptions.Max)
        and tOptions.Max > tOptions.Min, "Invalid circular progress range.");
    assert(_finite(tOptions.Value), "Circular progress value must be finite.");
    local sDirection = tOptions.Direction or "CW";
    local nThickness = tOptions.Thickness or 12;
    local sText      = tOptions.Text or "%v / %m";
    local tColour    = tOptions.Colour or {R = 88, G = 120, B = 148};
    assert(sDirection == "CW" or sDirection == "CCW", "Direction must be CW or CCW.");
    assert(_finite(nThickness) and nThickness > 0, "Thickness must be positive and finite.");
    assert(type(sText) == "string", "Circular progress Text must be a string.");

    for _, sChannel in ipairs({"R", "G", "B"}) do
        assert(_finite(tColour[sChannel]) and tColour[sChannel] >= 0
            and tColour[sChannel] <= 255, "Colour channels must be between 0 and 255.");
    end

    local oComponent = _ControlSurface.create(oParent, tOptions, "CircularProgress");
    local tEvents    = _ControlEvents.attach(oComponent, nil, {"directionChanged"});
    local oBackground = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    local oTrack      = _wx.wxBrush(_wx.wxColour(43, 50, 59));
    local oFill       = _wx.wxBrush(_wx.wxColour(tColour.R, tColour.G, tColour.B));
    local oDisabled   = _wx.wxBrush(_wx.wxColour(61, 67, 73));
    local tPoints     = {};
    local nCachedWidth, nCachedHeight, nCachedFraction, sCachedDirection;
    oComponent.Min   = tOptions.Min;
    oComponent.Max   = tOptions.Max;
    oComponent.Value = math.max(tOptions.Min, math.min(tOptions.Max, tOptions.Value));

    -- Release cached native points only when the shape changes or is disposed.
    local function fClearPoints()
        for _, oPoint in ipairs(tPoints) do
            oPoint:delete();
        end

        tPoints = {};
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.setValue
    @desc Clamps finite progress to the creation range. Effective changes redraw;
        notifications are opt-in and unchanged values remain silent.
    @param number nValue The requested progress.
    @param boolean|nil bNotify Emit OnChange(value, component) and valueChanged.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(_finite(nValue), "Circular progress value must be finite.");
        nValue = math.max(oComponent.Min, math.min(oComponent.Max, nValue));

        if (not oComponent.Disposed and nValue ~= oComponent.Value) then
            local nOldValue = oComponent.Value;
            oComponent.Value = nValue;
            oComponent.refresh();

            if (bNotify) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(nValue, oComponent);
                end

                tEvents.emit("valueChanged", {Value = nValue, OldValue = nOldValue});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.getDirection
    @desc Returns the current fill direction, CW or CCW.
    @ret string sDirection The current direction.
    !]]
    function oComponent.getDirection()
        return sDirection;
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.setDirection
    @desc Changes fill direction at runtime, preserving progress and geometry.
    @param string sNewDirection CW or CCW, starting at twelve o'clock.
    @param boolean|nil bNotify Emit directionChanged on an effective change.
    @ret table oComponent This component.
    !]]
    function oComponent.setDirection(sNewDirection, bNotify)
        assert(sNewDirection == "CW" or sNewDirection == "CCW", "Direction must be CW or CCW.");

        if (not oComponent.Disposed and sNewDirection ~= sDirection) then
            local sOldDirection = sDirection;
            sDirection = sNewDirection;
            oComponent.refresh();

            if (bNotify) then
                tEvents.emit("directionChanged", {Direction = sDirection, OldDirection = sOldDirection});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.draw
    @desc Paints a centered circle in a borrowed DC. Cached sector points avoid
        rebuilding native geometry on unchanged frames. The hole clips center text.
    @param wxDC oDC The borrowed destination.
    @param number nWidth Available width.
    @param number nHeight Available height.
    !]]
    function oComponent.draw(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end

        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, math.max(1, nWidth), math.max(1, nHeight)));
        oDC:SetBackground(oBackground);
        oDC:Clear();
        oDC:SetPen(_wx.wxTRANSPARENT_PEN);
        local nRadius = math.floor(math.min(nWidth, nHeight) / 2) - 2;
        local nX      = math.floor(nWidth / 2);
        local nY      = math.floor(nHeight / 2);
        local nFraction = (oComponent.Value - oComponent.Min) / (oComponent.Max - oComponent.Min);

        if (nRadius > 0) then
            oDC:SetBrush(oTrack);
            oDC:DrawCircle(nX, nY, nRadius);
            oDC:SetBrush(oComponent.isEnabled() and oFill or oDisabled);

            if (nFraction >= 1) then
                oDC:DrawCircle(nX, nY, nRadius);
            elseif (nFraction > 0) then
                if (nCachedWidth ~= nWidth or nCachedHeight ~= nHeight
                    or nCachedFraction ~= nFraction or sCachedDirection ~= sDirection) then
                    fClearPoints();
                    nCachedWidth, nCachedHeight = nWidth, nHeight;
                    nCachedFraction, sCachedDirection = nFraction, sDirection;
                    tPoints[1] = _wx.wxPoint(nX, nY);
                    local nSegments = math.max(1, math.ceil(360 * nFraction));
                    local nSign = sDirection == "CW" and 1 or -1;

                    -- Screen Y increases downward, so positive angles fill clockwise.
                    for nIndex = 0, nSegments do
                        local nAngle = -math.pi / 2 + nSign * math.pi * 2 * nFraction * nIndex / nSegments;
                        tPoints[#tPoints + 1] = _wx.wxPoint(
                            math.floor(nX + math.cos(nAngle) * nRadius + 0.5),
                            math.floor(nY + math.sin(nAngle) * nRadius + 0.5));
                    end
                end

                oDC:DrawPolygon(tPoints);
            end

            -- Keep a circle under rectangular layouts. Very small controls can
            -- consume the hole entirely, but never produce a negative radius.
            local nInner = math.max(0, math.floor(nRadius - nThickness));

            if (nInner > 0) then
                oDC:SetBrush(oBackground);
                oDC:DrawCircle(nX, nY, nInner);
                local nTextHalf = math.floor(nInner / math.sqrt(2));
                local oTextClip = _wx.wxDCClipper(oDC,
                    _wx.wxRect(nX - nTextHalf, nY - nTextHalf, math.max(1, nTextHalf * 2), math.max(1, nTextHalf * 2)));
                local sDisplay = sText:gsub("%%v", tostring(oComponent.Value)):gsub("%%m", tostring(oComponent.Max));
                oDC:SetFont(oComponent.Skin.Font);
                local nTextWidth, nTextHeight = oDC:GetTextExtent(sDisplay);
                oComponent.Skin.text(oDC, sDisplay, nX - nTextWidth / 2,
                    nY - nTextHeight / 2, oComponent.isEnabled());
                oTextClip:delete();
            end
        end

        oClip:delete();
    end

    -- The surface owns the paint DC; this component owns only brushes and points.
    oComponent.onDestroy = function()
        fClearPoints();
        oBackground:delete();
        oTrack:delete();
        oFill:delete();
        oDisabled:delete();
    end;
    return oComponent;
end

return CircularProgress;