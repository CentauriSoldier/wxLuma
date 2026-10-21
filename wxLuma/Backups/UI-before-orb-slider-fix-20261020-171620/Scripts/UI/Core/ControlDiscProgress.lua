local _Reserve = require("UI.Core.ControlProgressReserve");
local _wx             = require("wx");
local _ControlSurface = require("UI.Core.ControlSurface");
local _ControlEvents  = require("UI.Core.ControlEvents");
local _finite         = require("UI.Core.ControlNumeric").finite;
local ControlDiscProgress = {};

--[[!
@fqxn wxLuma.UI.ControlDiscProgress.create
@desc Shared composition engine for GlobeProgress and RadialProgress. Each call
    creates one independent actual/decoy/metatable surface with its public kind.
    The globe advances a straight boundary through a disc; radial progress changes
    a concentric radius. Cached four-times supersampling smooths every boundary.
@param wxWindow oParent Native parent, which owns the control.
@param table tOptions Common progress options, Reserved (capacity units, default 0),
    ReserveOrigin for globe or ReserveDirection for radial. Radial also accepts
    InnerRadius/OuterRadius percentages. Omitted reserve geometry is automatic.
@param string sKind GlobeProgress or RadialProgress.
@ret table oComponent Independent public component with shared input/containment API.
!]]
function ControlDiscProgress.create(oParent, tOptions, sKind)
    assert(sKind == "GlobeProgress" or sKind == "RadialProgress", "Invalid disc progress kind.");
    assert(type(tOptions) == "table", "Progress options must be a table.");
    assert(_finite(tOptions.Min) and _finite(tOptions.Max) and tOptions.Max > tOptions.Min
        and _finite(tOptions.Max - tOptions.Min), "Invalid disc progress range.");
    assert(_finite(tOptions.Value), "Progress value must be finite.");
    local bGlobe      = sKind == "GlobeProgress";
    local sAppearance = tOptions.Appearance;
    local sArtwork    = tOptions.Artwork;
    local sText       = tOptions.Text;
    local sOrigin     = tOptions.Origin;
    local sOrientation = tOptions.Orientation;
    local sDirection   = tOptions.Direction;
    local tColour      = tOptions.Colour or {R = 77, G = 120, B = 169};

    if (sAppearance == nil) then
        sAppearance = tOptions.Colour and "colour" or "skin";
    end

    if (sArtwork == nil) then
        sArtwork = bGlobe and "Globe Progress" or "Radial Progress";
    end

    if (sText == nil) then
        sText = "%v / %m";
    end

    assert(sAppearance == "skin" or sAppearance == "colour", "Appearance must be skin or colour.");
    assert(type(sArtwork) == "string" and sArtwork:find("%S"), "Artwork must be a material prefix.");
    assert(type(sText) == "string", "Progress Text must be a string.");
    assert(type(tColour) == "table", "Colour must contain R, G and B.");
    local tFillColour = {};

    for _, sChannel in ipairs({"R", "G", "B"}) do
        local nChannel = tColour[sChannel];
        assert(_finite(nChannel) and nChannel >= 0 and nChannel <= 255,
            "Colour channels must be between 0 and 255.");
        tFillColour[sChannel] = nChannel;
    end

    if (bGlobe) then
        if (sOrientation == nil) then
            sOrientation = (sOrigin == "left" or sOrigin == "right") and "horizontal" or "vertical";
        end

        assert(sOrientation == "horizontal" or sOrientation == "vertical", "Invalid globe orientation.");

        if (sOrigin == nil) then
            sOrigin = sOrientation == "vertical" and "bottom" or "left";
        end

        assert(sOrigin == "left" or sOrigin == "right" or sOrigin == "top" or sOrigin == "bottom",
            "Invalid globe origin.");
        assert((sOrientation == "horizontal") == (sOrigin == "left" or sOrigin == "right"),
            "Globe Origin conflicts with Orientation.");
    else
        if (sDirection == nil) then
            sDirection = "outward";
        end

        assert(sDirection == "outward" or sDirection == "inward", "Direction must be outward or inward.");
    end

    _Reserve.validate(tOptions, sKind);
    local oComponent = _ControlSurface.create(oParent, tOptions, sKind);
    local tExtraEvents = bGlobe and {"appearanceChanged", "orientationChanged", "originChanged"}
        or {"appearanceChanged", "directionChanged"};
    for _, sEvent in ipairs(_Reserve.Events) do
        tExtraEvents[#tExtraEvents + 1] = sEvent;
    end

    local tEvents = _ControlEvents.attach(oComponent, nil, tExtraEvents);
    local oBackground = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    local oRaster;
    local sCachedRaster;
    oComponent.Min   = tOptions.Min;
    oComponent.Max   = tOptions.Max;
    oComponent.Value = math.max(tOptions.Min, math.min(tOptions.Max, tOptions.Value));
    local tReserve = _Reserve.attach(oComponent, tOptions, tEvents, sKind);

    --[[!
    @fqxn wxLuma.UI.ControlDiscProgress.setValue
    @desc Clamps finite progress to the creation range. Effective changes repaint;
        notifications retain OnChange(value, component) and valueChanged semantics.
    @param number nValue Requested progress value.
    @param boolean|nil bNotify Emit changed-only notifications; default silent.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(_finite(nValue), "Progress value must be finite.");
        nValue = math.max(oComponent.Min, math.min(oComponent.Max, nValue));

        if (not oComponent.Disposed and oComponent.Value ~= nValue) then
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
    @fqxn wxLuma.UI.ControlDiscProgress.getAppearance
    @desc Returns the current skin/material or solid-colour rendering mode.
    @ret string sAppearance skin or colour.
    !]]
    function oComponent.getAppearance()
        return sAppearance;
    end

    --[[!
    @fqxn wxLuma.UI.ControlDiscProgress.setAppearance
    @desc Changes appearance without changing progress, geometry or native size.
    @param string sMode skin or colour.
    @param boolean|nil bNotify Emit appearanceChanged after an effective change.
    @ret table oComponent This component.
    !]]
    function oComponent.setAppearance(sMode, bNotify)
        assert(sMode == "skin" or sMode == "colour", "Appearance must be skin or colour.");

        if (not oComponent.Disposed and sAppearance ~= sMode) then
            local sOld = sAppearance;
            sAppearance = sMode;
            oComponent.refresh();

            if (bNotify) then
                tEvents.emit("appearanceChanged", {Appearance = sMode, OldAppearance = sOld});
            end
        end

        return oComponent;
    end

    if (bGlobe) then
        -- Commit both related settings before notifying so observers never see
        -- an origin paired with an incompatible axis.
        local function fGeometry(sNewOrientation, sNewOrigin, bNotify)
            if (oComponent.Disposed) then
                return oComponent;
            end

            local sOldOrientation, sOldOrigin = sOrientation, sOrigin;
            sOrientation, sOrigin = sNewOrientation, sNewOrigin;

            if (sOrientation ~= sOldOrientation or sOrigin ~= sOldOrigin) then
                oComponent.refresh();

                if (bNotify) then
                    if (sOrientation ~= sOldOrientation) then
                        tEvents.emit("orientationChanged", {
                            Orientation = sOrientation, OldOrientation = sOldOrientation
                        });
                    end

                    if (sOrigin ~= sOldOrigin) then
                        tEvents.emit("originChanged", {Origin = sOrigin, OldOrigin = sOldOrigin});
                    end
                end
            end

            return oComponent;
        end

        --[[!
        @fqxn wxLuma.UI.GlobeProgress.getOrientation
        @desc Returns the axis along which the straight fill boundary advances.
        @ret string sOrientation horizontal or vertical.
        !]]
        function oComponent.getOrientation()
            return sOrientation;
        end

        --[[!
        @fqxn wxLuma.UI.GlobeProgress.setOrientation
        @desc Changes axis, mapping forward origins left/bottom and reverse right/top.
            The globe stays circular and its native dimensions remain unchanged.
        @param string sValue horizontal or vertical.
        @param boolean|nil bNotify Emit orientationChanged/originChanged as needed.
        @ret table oComponent This component.
        !]]
        function oComponent.setOrientation(sValue, bNotify)
            assert(sValue == "horizontal" or sValue == "vertical", "Invalid globe orientation.");
            local bReverse = sOrigin == "right" or sOrigin == "top";
            local sNewOrigin = sValue == "vertical" and (bReverse and "top" or "bottom")
                or (bReverse and "right" or "left");
            return fGeometry(sValue, sNewOrigin, bNotify);
        end

        --[[!
        @fqxn wxLuma.UI.GlobeProgress.getOrigin
        @desc Returns the side from which the globe's linear level grows.
        @ret string sOrigin bottom, top, left or right.
        !]]
        function oComponent.getOrigin()
            return sOrigin;
        end

        --[[!
        @fqxn wxLuma.UI.GlobeProgress.setOrigin
        @desc Changes fill origin and matching orientation atomically at runtime.
        @param string sValue bottom, top, left or right.
        @param boolean|nil bNotify Emit originChanged/orientationChanged as needed.
        @ret table oComponent This component.
        !]]
        function oComponent.setOrigin(sValue, bNotify)
            assert(sValue == "bottom" or sValue == "top" or sValue == "left" or sValue == "right",
                "Invalid globe origin.");
            local sNewOrientation = (sValue == "left" or sValue == "right") and "horizontal" or "vertical";
            return fGeometry(sNewOrientation, sValue, bNotify);
        end
    else
        --[[!
        @fqxn wxLuma.UI.RadialProgress.getDirection
        @desc Returns whether fill grows from the center or from the outer rim.
        @ret string sDirection outward or inward.
        !]]
        function oComponent.getDirection()
            return sDirection;
        end

        --[[!
        @fqxn wxLuma.UI.RadialProgress.setDirection
        @desc Changes radial growth direction without changing progress or size.
        @param string sValue outward (center to rim) or inward (rim to center).
        @param boolean|nil bNotify Emit directionChanged after an effective change.
        @ret table oComponent This component.
        !]]
        function oComponent.setDirection(sValue, bNotify)
            assert(sValue == "outward" or sValue == "inward", "Direction must be outward or inward.");

            if (not oComponent.Disposed and sDirection ~= sValue) then
                local sOld = sDirection;
                sDirection = sValue;
                oComponent.refresh();

                if (bNotify) then
                    tEvents.emit("directionChanged", {Direction = sValue, OldDirection = sOld});
                end
            end

            return oComponent;
        end
    end

    -- Rebuild only on visual state changes. Bitmap materials stay aligned with
    -- the complete disc as its fill changes; the control owns no skin bitmaps.
    local function fRaster(nDiameter, nFraction, bEnabled)
        local sPolicy = bGlobe and sOrigin or sDirection;
        local sKey = table.concat({nDiameter, nFraction, sPolicy, sAppearance,
            bEnabled and "enabled" or "disabled", tReserve.Reserved,
            tReserve.ReserveOrigin or "auto", tReserve.ReserveDirection or "auto",
            tReserve.InnerRadius or 0, tReserve.OuterRadius or 100}, ":");

        if (sKey == sCachedRaster) then
            return;
        end

        local nScale  = 4;
        local nSize   = nDiameter * nScale;
        local nCenter = math.floor(nDiameter / 2) * nScale;
        local nRadius = (math.floor(nDiameter / 2) - 2) * nScale;
        local oTrack, oFill, oReserved;

        if (sAppearance == "skin") then
            local sState = bEnabled and "Normal" or "Disabled";
            local oTrackBitmap = oComponent.Skin.getBitmap(sArtwork.." Track "..sState, nSize, nSize);
            local oFillBitmap  = oComponent.Skin.getBitmap(sArtwork.." Fill "..sState, nSize, nSize);
            oTrack = _wx.wxBrush(oTrackBitmap);
            oFill  = _wx.wxBrush(oFillBitmap);

            if (tReserve.Reserved > 0) then
                oReserved = _wx.wxBrush(oComponent.Skin.getBitmap(sArtwork.." Reserve "..sState, nSize, nSize));
            end
        else
            oTrack = _wx.wxBrush(_wx.wxColour(43, 50, 59));
            oFill = _wx.wxBrush(bEnabled and _wx.wxColour(tFillColour.R, tFillColour.G, tFillColour.B)
                or _wx.wxColour(61, 67, 73));
        end

        if (tReserve.Reserved > 0 and not oReserved) then
            oReserved = _wx.wxBrush(bEnabled and _wx.wxColour(142, 99, 164) or _wx.wxColour(72, 65, 78));
        end

        local oBitmap = _wx.wxBitmap(nSize, nSize);
        local oMemory = _wx.wxMemoryDC();
        oMemory:SelectObject(oBitmap);
        oMemory:SetBackground(oBackground);
        oMemory:Clear();
        oMemory:SetPen(_wx.wxTRANSPARENT_PEN);
        oMemory:SetBrush(oTrack);
        oMemory:DrawCircle(nCenter, nCenter, nRadius);
        oMemory:SetBrush(oFill);

        if (tReserve.Reserved > 0 or tReserve.InnerRadius ~= nil or tReserve.OuterRadius ~= nil) then
            oMemory:Clear();
            local nInner = nRadius * (tReserve.InnerRadius or 0) / 100;
            local nOuter = nRadius * (tReserve.OuterRadius or 100) / 100;
            local nReserved = tReserve.Reserved / (oComponent.Max - oComponent.Min);
            local tOpposite = {left = "right", right = "left", top = "bottom", bottom = "top"};
            local sReserveOrigin = tReserve.ReserveOrigin or tOpposite[sOrigin];
            local sReserveDirection = tReserve.ReserveDirection or (sDirection == "outward" and "inward" or "outward");

            --[[!
            @fqxn wxLuma.UI.ControlDiscProgress.raster.linearCoordinate
            @desc Measures distance from a chosen edge across the disc diameter.
                The reserve edge is independent of the current fill axis.
            !]]
            local function fLinear(sEdge, nX, nY)
                if (sEdge == "left") then
                    return (nX - nCenter + nRadius) / (2 * nRadius);
                elseif (sEdge == "right") then
                    return (nCenter + nRadius - nX) / (2 * nRadius);
                elseif (sEdge == "top") then
                    return (nY - nCenter + nRadius) / (2 * nRadius);
                end

                return (nCenter + nRadius - nY) / (2 * nRadius);
            end

            --[[!
            @fqxn wxLuma.UI.ControlDiscProgress.raster.coordinates
            @desc Rejects points outside the radial band, then returns independent
                current/reserve coordinates at supersampled pixel centers.
            !]]
            local function fCoordinates(nX, nY)
                nX, nY = nX + 0.5, nY + 0.5;
                local nDistance = math.sqrt((nX - nCenter)^2 + (nY - nCenter)^2);

                if (nDistance < nInner or nDistance >= nOuter) then
                    return nil;
                end

                if (bGlobe) then
                    return fLinear(sOrigin, nX, nY), fLinear(sReserveOrigin, nX, nY);
                end

                local nRadial = (nDistance - nInner) / (nOuter - nInner);
                return sDirection == "outward" and nRadial or 1 - nRadial,
                    sReserveDirection == "outward" and nRadial or 1 - nRadial;
            end

            -- With no reserve retain the original distance-based radial fill.
            -- Reserved shapes use the remaining path so perpendicular policies
            -- cannot overlap current or prevent a completely full usable region.
            if (nReserved == 0) then
                oMemory:SetBrush(oBackground);
                oMemory:Clear();
                local nFillOuter = sDirection == "outward" and nInner + (nOuter - nInner) * nFraction or nOuter;
                local nFillInner = sDirection == "inward" and nOuter - (nOuter - nInner) * nFraction or nInner;
                oMemory:SetBrush(oTrack);
                oMemory:DrawCircle(nCenter, nCenter, math.floor(nOuter));
                if (nFraction > 0) then
                    oMemory:SetBrush(oFill);
                    oMemory:DrawCircle(nCenter, nCenter, math.floor(nFillOuter));
                end

                if (nFillInner > 0) then
                    oMemory:SetBrush(oTrack);
                    oMemory:DrawCircle(nCenter, nCenter, math.floor(nFillInner));
                end

                if (nInner > 0) then
                    oMemory:SetBrush(oBackground);
                    oMemory:DrawCircle(nCenter, nCenter, math.floor(nInner));
                end
            else
                _Reserve.drawMask(oMemory, nSize, nSize, fCoordinates, nReserved,
                    nReserved < 1 and nFraction / (1 - nReserved) or 0,
                    {Track = oTrack, Fill = oFill, Reserve = oReserved},
                    {Kind = bGlobe and "globe" or "radial", Center = nCenter, Radius = nOuter,
                        Inner = nInner, Direction = sDirection, Origin = sOrigin,
                        ReserveOrigin = sReserveOrigin, ReserveDirection = sReserveDirection});
            end
        elseif (nFraction >= 1) then
            oMemory:DrawCircle(nCenter, nCenter, nRadius);
        elseif (nFraction > 0 and bGlobe) then
            local bVertical = sOrientation == "vertical";
            local nLength = math.floor(2 * nRadius * nFraction + 0.5);
            local nX, nY = nCenter - nRadius, nCenter - nRadius;
            local nWidth  = bVertical and 2 * nRadius + 1 or nLength;
            local nHeight = bVertical and nLength or 2 * nRadius + 1;

            if (sOrigin == "bottom") then
                nY = nCenter + nRadius - nLength;
            elseif (sOrigin == "right") then
                nX = nCenter + nRadius - nLength;
            end

            if (nWidth > 0 and nHeight > 0) then
                -- The straight level is clipped before drawing the full circle,
                -- retaining both its round silhouette and stationary material.
                local oClip = _wx.wxDCClipper(oMemory, _wx.wxRect(nX, nY, nWidth, nHeight));
                oMemory:DrawCircle(nCenter, nCenter, nRadius);
                oClip:delete();
            end
        elseif (nFraction > 0 and sDirection == "outward") then
            local nFillRadius = math.floor(nRadius * nFraction + 0.5);

            if (nFillRadius > 0) then
                oMemory:DrawCircle(nCenter, nCenter, nFillRadius);
            end
        elseif (nFraction > 0) then
            -- Inward progress fills a ring while leaving a shrinking track disc.
            -- At maximum the center is filled too; minimum draws only the track.
            oMemory:DrawCircle(nCenter, nCenter, nRadius);
            local nHole = math.floor(nRadius * (1 - nFraction) + 0.5);

            if (nHole > 0) then
                oMemory:SetBrush(oTrack);
                oMemory:DrawCircle(nCenter, nCenter, nHole);
            end
        end

        oMemory:SelectObject(_wx.wxNullBitmap);
        oMemory:delete();
        oTrack:delete();
        oFill:delete();

        if (oReserved) then
            oReserved:delete();
        end
        local oImage = oBitmap:ConvertToImage();
        local oScaled = oImage:Scale(nDiameter, nDiameter, _wx.wxIMAGE_QUALITY_HIGH);
        local oNewRaster = _wx.wxBitmap(oScaled);
        oScaled:delete();
        oImage:delete();
        oBitmap:delete();

        if (oRaster) then
            oRaster:delete();
        end

        oRaster = oNewRaster;
        sCachedRaster = sKey;
    end

    --[[!
    @fqxn wxLuma.UI.ControlDiscProgress.draw
    @desc Draws the centered cached disc into a borrowed DC. Non-square layouts
        preserve its circle. Horizontal text clips to a square inside the disc.
    @param wxDC oDC Borrowed destination.
    @param number nWidth Available width in pixels.
    @param number nHeight Available height in pixels.
    !]]
    function oComponent.draw(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end

        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, math.max(1, nWidth), math.max(1, nHeight)));
        oDC:SetBackground(oBackground);
        oDC:Clear();
        local nDiameter = math.floor(math.min(nWidth, nHeight));
        local nRadius = math.floor(nDiameter / 2) - 2;

        if (nRadius > 0) then
            local nOffsetX = math.floor((nWidth - nDiameter) / 2);
            local nOffsetY = math.floor((nHeight - nDiameter) / 2);
            local nFraction = (oComponent.Value - oComponent.Min) / (oComponent.Max - oComponent.Min);
            fRaster(nDiameter, nFraction, oComponent.isEnabled());
            oDC:DrawBitmap(oRaster, nOffsetX, nOffsetY, false);
            local nX = nOffsetX + math.floor(nDiameter / 2);
            local nY = nOffsetY + math.floor(nDiameter / 2);
            local nTextHalf = math.floor(nRadius / math.sqrt(2));
            local oTextClip = _wx.wxDCClipper(oDC, _wx.wxRect(nX - nTextHalf, nY - nTextHalf,
                math.max(1, nTextHalf * 2), math.max(1, nTextHalf * 2)));
            local sDisplay = sText:gsub("%%v", tostring(oComponent.Value)):gsub("%%m", tostring(oComponent.Max));
            oDC:SetFont(oComponent.Skin.Font);
            local nTextWidth, nTextHeight = oDC:GetTextExtent(sDisplay);
            oComponent.Skin.text(oDC, sDisplay, nX - nTextWidth / 2,
                nY - nTextHeight / 2, oComponent.isEnabled());
            oTextClip:delete();
        end

        oClip:delete();
    end

    -- Public destroy is composed by the surface, events and containment helpers.
    -- Dispose owned raster/brush resources once; the native parent owns the control.
    oComponent.onDestroy = function()
        if (oRaster) then
            oRaster:delete();
            oRaster = nil;
        end

        oBackground:delete();
    end;
    return oComponent;
end

return ControlDiscProgress;