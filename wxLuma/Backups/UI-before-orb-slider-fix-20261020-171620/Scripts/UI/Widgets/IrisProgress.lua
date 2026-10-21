local _wx       = require("wx");
local _Surface  = require("UI.Core.ControlSurface");
local _Events   = require("UI.Core.ControlEvents");
local _Reserve  = require("UI.Core.ControlProgressReserve");
local _Artwork  = require("UI.Core.ControlArtwork");
local _finite   = require("UI.Core.ControlNumeric").finite;
local IrisProgress = {};

--[[!
@fqxn wxLuma.UI.IrisProgress.loadImage
@desc Decodes an owned replacement before any live state changes. Nil clears it.
@param string|nil pPath Image path supported by the installed wx image handlers.
@ret wxImage|nil oImage Owned decoded image.
!]]
local function loadImage(pPath)
    assert(pPath == nil or type(pPath) == "string", "BackgroundImage must be a path or nil.");

    if (pPath == nil) then
        return nil;
    end

    local hFile = io.open(pPath, "rb");
    assert(hFile, "Cannot open iris background image: "..pPath);
    hFile:close();
    local oImage = _wx.wxImage(pPath, _wx.wxBITMAP_TYPE_ANY);

    if (not oImage:IsOk()) then
        oImage:delete();
        error("Cannot decode iris background image: "..pPath);
    end

    return oImage;
end

--[[!
@fqxn wxLuma.UI.IrisProgress.create
@desc Creates a camera-iris progress globe with layered blades and a polygonal
    opening. Opening grows with value by default; closing grows blade coverage.
    Maximum opening uncovers the entire disc. All boundaries are antialiased.
@param wxWindow oParent Native parent, which owns the control.
@param table tOptions Skin, Min, Max, Value; optional BladeCount (3..32, default 6),
    Rotation (clock-face degrees, default 0), Direction (opening/closing), Text,
    Appearance (skin/colour), Colour ({R,G,B}), Artwork (Iris Progress), Reserved,
    ReserveDirection (inward/outward), BackgroundImage (optional path),
    BackgroundImageFit (cover/contain/stretch, default cover), Enabled, OnChange
    and standard containment. Background image is always clipped by globe/blades.
@ret table oComponent Independent IrisProgress proxy with standard progress events.
!]]
function IrisProgress.create(oParent, tOptions)
    assert(type(tOptions) == "table" and _finite(tOptions.Min) and _finite(tOptions.Max)
        and tOptions.Max > tOptions.Min and _finite(tOptions.Max - tOptions.Min), "Invalid iris range.");
    assert(_finite(tOptions.Value), "Iris value must be finite.");
    _Reserve.validate(tOptions, "IrisProgress");
    local tSettings = {
        BladeCount = tOptions.BladeCount or 6,
        Rotation = tOptions.Rotation or 0,
        Direction = tOptions.Direction or "opening",
        Appearance = tOptions.Appearance or (tOptions.Colour and "colour" or "skin"),
        BackgroundImageFit = tOptions.BackgroundImageFit or "cover"
    };
    local tValidators = {
        BladeCount = function(nValue)
            return _finite(nValue) and nValue % 1 == 0 and nValue >= 3 and nValue <= 32;
        end,
        Rotation = _finite,
        Direction = function(sValue)
            return sValue == "opening" or sValue == "closing";
        end,
        Appearance = function(sValue)
            return sValue == "skin" or sValue == "colour";
        end,
        BackgroundImageFit = function(sValue)
            return sValue == "cover" or sValue == "contain" or sValue == "stretch";
        end
    };

    for sName, fValidate in pairs(tValidators) do
        assert(fValidate(tSettings[sName]), "Invalid iris "..sName..".");
    end

    tSettings.Rotation = tSettings.Rotation % 360;
    local sText = tOptions.Text or "%v / %m";
    local sArtwork = tOptions.Artwork or "Iris Progress";
    local tColour = tOptions.Colour or {R = 80, G = 145, B = 190};
    assert(type(sText) == "string" and type(sArtwork) == "string" and sArtwork:find("%S"), "Invalid iris text/artwork.");
    local tRGB = {};

    for _, sChannel in ipairs({"R", "G", "B"}) do
        assert(type(tColour) == "table" and _finite(tColour[sChannel])
            and tColour[sChannel] >= 0 and tColour[sChannel] <= 255, "Invalid iris colour.");
        tRGB[sChannel] = tColour[sChannel];
    end

    assert(tOptions.Skin, "IrisProgress requires a Skin.");
    local oImage = loadImage(tOptions.BackgroundImage);
    local pImage = tOptions.BackgroundImage;
    local oComponent = _Surface.create(oParent, tOptions, "IrisProgress");
    local tExtraEvents = {"bladeCountChanged", "rotationChanged", "directionChanged", "appearanceChanged",
        "backgroundImageChanged", "backgroundImageFitChanged"};

    for _, sName in ipairs(_Reserve.Events) do
        tExtraEvents[#tExtraEvents + 1] = sName;
    end

    local tEvents = _Events.attach(oComponent, nil, tExtraEvents);
    oComponent.Min   = tOptions.Min;
    oComponent.Max   = tOptions.Max;
    oComponent.Value = math.max(tOptions.Min, math.min(tOptions.Max, tOptions.Value));
    local tReserve = _Reserve.attach(oComponent, tOptions, tEvents, "IrisProgress");
    local tArt = _Artwork.create(oComponent.Skin, sArtwork);
    local oRaster;
    local sRasterKey;

    --[[!
    @fqxn wxLuma.UI.IrisProgress.geometryAccessors
    @desc Installs get/setBladeCount, Rotation, Direction, Appearance and
        BackgroundImageFit. Setters validate before mutation, are silent by
        default, and notify only effective changes with old/new property values.
        Angles normalize modulo 360. Settings preserve value and native layout.
    !]]
    local function fAccessors(sName, fValidate)
        local sEvent = sName:sub(1, 1):lower()..sName:sub(2).."Changed";
        oComponent["get"..sName] = function()
            return tSettings[sName];
        end;
        oComponent["set"..sName] = function(vValue, bNotify)
            assert(fValidate(vValue), "Invalid iris "..sName..".");

            if (sName == "Rotation") then
                vValue = vValue % 360;
            end

            if (not oComponent.Disposed and tSettings[sName] ~= vValue) then
                local vOld = tSettings[sName];
                tSettings[sName] = vValue;
                oComponent.refresh();

                if (bNotify) then
                    tEvents.emit(sEvent, {[sName] = vValue, ["Old"..sName] = vOld});
                end
            end

            return oComponent;
        end;
    end

    for sName, fValidate in pairs(tValidators) do
        fAccessors(sName, fValidate);
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.setValue
    @desc Clamps finite values to the creation range. Reserve limits drawing,
        while retaining the supplied current value. Unchanged values are silent.
    @param number nValue Requested progress value.
    @param boolean|nil bNotify Emit OnChange(value, component) and valueChanged.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(_finite(nValue), "Iris value must be finite.");
        nValue = math.max(oComponent.Min, math.min(oComponent.Max, nValue));

        if (not oComponent.Disposed and oComponent.Value ~= nValue) then
            local nOld = oComponent.Value;
            oComponent.Value = nValue;
            oComponent.refresh();

            if (bNotify) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(nValue, oComponent);
                end

                tEvents.emit("valueChanged", {Value = nValue, OldValue = nOld});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.getBackgroundImage
    @desc Returns the source path, or nil when no image is configured.
    @ret string|nil pPath Current background image path.
    !]]
    function oComponent.getBackgroundImage()
        return pImage;
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.setBackgroundImage
    @desc Loads a replacement atomically. Nil clears it; failed loads preserve
        the image and raster. The picture never paints outside the globe or over
        blades. Reusing the current path is a no-op.
    @param string|nil pPath Image path or nil.
    @param boolean|nil bNotify Emit backgroundImageChanged and imageLoaded on load.
    @ret table oComponent This component.
    !]]
    function oComponent.setBackgroundImage(pPath, bNotify)
        if (oComponent.Disposed or pPath == pImage) then
            return oComponent;
        end

        local oReplacement = loadImage(pPath);
        local pOld = pImage;

        if (oImage) then
            oImage:delete();
        end

        oImage, pImage = oReplacement, pPath;
        sRasterKey = nil;
        oComponent.refresh();

        if (bNotify) then
            tEvents.emit("backgroundImageChanged", {BackgroundImage = pPath, OldBackgroundImage = pOld});

            if (oImage) then
                tEvents.emit("imageLoaded", {Path = pPath, Width = oImage:GetWidth(), Height = oImage:GetHeight()});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.raster
    @desc Builds one four-times supersampled globe. Layered blade polygons form
        the aperture; analytic scanline masks clip both picture and reserve to
        the circle and opening. Cached results are reused until visual state changes.
    !]]
    local function fRaster(nDiameter)
        local bEnabled = oComponent.isEnabled();
        local sState = bEnabled and "Normal" or "Disabled";
        local sKey = table.concat({nDiameter, oComponent.Value, tReserve.Reserved,
            tReserve.ReserveDirection or "auto", tSettings.BladeCount, tSettings.Rotation,
            tSettings.Direction, tSettings.Appearance, tSettings.BackgroundImageFit, sState}, ":");

        if (sKey == sRasterKey) then
            return;
        end

        local nSize = nDiameter * 4;
        local nCenter = math.floor(nDiameter / 2) * 4;
        local nRadius = (math.floor(nDiameter / 2) - 2) * 4;
        local nBlades = tSettings.BladeCount;
        local nStep = 2 * math.pi / nBlades;
        local nRotation = math.rad(tSettings.Rotation - 90);
        local nReserved = tReserve.Reserved / (oComponent.Max - oComponent.Min);
        local nCurrent = math.max(0, math.min(1 - nReserved,
            (oComponent.Value - oComponent.Min) / (oComponent.Max - oComponent.Min)));
        local bOpening = tSettings.Direction == "opening";
        local sReserveDirection = tReserve.ReserveDirection or (bOpening and "inward" or "outward");
        local bSame = bOpening == (sReserveDirection == "outward");
        local nThreshold = (bSame and nReserved or 0) + nCurrent;
        local nOpen = bOpening and nThreshold or 1 - nThreshold;
        local tBrushes = {};
        local tPalette = {
            Background = {24, 29, 36}, Track = {33, 42, 54},
            Fill = {tRGB.R, tRGB.G, tRGB.B}, Blade = {75, 91, 109},
            ["Blade Alternate"] = {58, 73, 92}, Reserve = {142, 99, 164}
        };

        for sPart, tChannels in pairs(tPalette) do
            if (tSettings.Appearance == "skin") then
                tBrushes[sPart] = _wx.wxBrush(oComponent.Skin.getBitmap(sArtwork.." "..sPart.." "..sState, nSize, nSize));
            else
                local nShade = bEnabled and 1 or 0.5;
                tBrushes[sPart] = _wx.wxBrush(_wx.wxColour(math.floor(tChannels[1] * nShade),
                    math.floor(tChannels[2] * nShade), math.floor(tChannels[3] * nShade)));
            end
        end

        local oBitmap = _wx.wxBitmap(nSize, nSize);
        local oDC = _wx.wxMemoryDC();
        oDC:SelectObject(oBitmap);
        oDC:SetBackground(tBrushes.Background);
        oDC:Clear();
        oDC:SetPen(_wx.wxTRANSPARENT_PEN);
        oDC:SetBrush(tBrushes.Track);
        oDC:DrawCircle(nCenter, nCenter, nRadius);
        local oPicture;

        if (oImage) then
            -- Composite alpha and fit into a stationary square before clipping.
            local nWidth, nHeight = oImage:GetWidth(), oImage:GetHeight();
            local nScale = tSettings.BackgroundImageFit == "contain" and nSize / math.max(nWidth, nHeight)
                or nSize / math.min(nWidth, nHeight);
            local nDrawWidth = tSettings.BackgroundImageFit == "stretch" and nSize or math.max(1, math.floor(nWidth * nScale));
            local nDrawHeight = tSettings.BackgroundImageFit == "stretch" and nSize or math.max(1, math.floor(nHeight * nScale));
            local oScaled = oImage:Scale(nDrawWidth, nDrawHeight, _wx.wxIMAGE_QUALITY_HIGH);
            local oScaledBitmap = _wx.wxBitmap(oScaled);
            oPicture = _wx.wxBitmap(nSize, nSize);
            local oPictureDC = _wx.wxMemoryDC();
            oPictureDC:SelectObject(oPicture);
            oPictureDC:SetBackground(tBrushes.Track);
            oPictureDC:Clear();
            oPictureDC:DrawBitmap(oScaledBitmap, math.floor((nSize - nDrawWidth) / 2),
                math.floor((nSize - nDrawHeight) / 2), true);
            oPictureDC:SelectObject(_wx.wxNullBitmap);
            oPictureDC:delete();
            oScaledBitmap:delete();
            oScaled:delete();
        end

        local oPictureBrush = oPicture and _wx.wxBrush(oPicture);
        local oSeam = _wx.wxPen(tArt.color("Seam "..sState), 3, _wx.wxPENSTYLE_SOLID);
        oDC:SetPen(oSeam);
        local nVertexRadius = nOpen * nRadius / math.cos(nStep / 2);
        local nTwist = (1 - nOpen) * nStep * 0.7;

        -- Each leaf shares the aperture edge and overlaps its neighbor toward
        -- the outer rim. Alternating materials and seams make the overlap clear.
        for nBlade = 0, nBlades - 1 do
            local nAngle = nRotation + (nBlade - 0.5) * nStep;
            local tPoints = {};

            for _, nInnerAngle in ipairs({nAngle, nAngle + nStep}) do
                tPoints[#tPoints + 1] = _wx.wxPoint(math.floor(nCenter + math.cos(nInnerAngle) * nVertexRadius),
                    math.floor(nCenter + math.sin(nInnerAngle) * nVertexRadius));
            end

            for nIndex = 12, 0, -1 do
                local nOuterAngle = nAngle + nTwist + nStep * nIndex / 12;
                tPoints[#tPoints + 1] = _wx.wxPoint(math.floor(nCenter + math.cos(nOuterAngle) * (nRadius + 8)),
                    math.floor(nCenter + math.sin(nOuterAngle) * (nRadius + 8)));
            end

            oDC:SetBrush(bOpening and tBrushes[nBlade % 2 == 0 and "Blade" or "Blade Alternate"] or tBrushes.Fill);
            oDC:DrawPolygon(tPoints);

            for _, oPoint in ipairs(tPoints) do
                oPoint:delete();
            end
        end

        oDC:SetPen(_wx.wxTRANSPARENT_PEN);
        local tNormals = {};

        for nBlade = 0, nBlades - 1 do
            local nAngle = nRotation + nBlade * nStep;
            tNormals[#tNormals + 1] = {math.cos(nAngle), math.sin(nAngle)};
        end

        -- Polygon half-planes give exact opening/reserve boundaries. Scanline
        -- runs overwrite aperture/reserve only, preserving the blade artwork.
        for nY = 0, nSize - 1 do
            local nDY = nY + 0.5 - nCenter;
            local tBreaks = {0, nSize};

            if (math.abs(nDY) < nRadius) then
                local nDX = math.sqrt(nRadius^2 - nDY^2);
                tBreaks[#tBreaks + 1] = math.ceil(nCenter - nDX - 0.5);
                tBreaks[#tBreaks + 1] = math.ceil(nCenter + nDX - 0.5);
            end

            for _, tNormal in ipairs(tNormals) do
                if (math.abs(tNormal[1]) > 0.0000001) then
                    for _, nBoundary in ipairs({nOpen, sReserveDirection == "outward" and nReserved or 1 - nReserved}) do
                        local nX = nCenter + (nBoundary * nRadius - tNormal[2] * nDY) / tNormal[1];
                        tBreaks[#tBreaks + 1] = math.max(0, math.min(nSize, math.ceil(nX - 0.5)));
                    end
                end
            end

            table.sort(tBreaks);

            for nIndex = 1, #tBreaks - 1 do
                local nStart, nEnd = tBreaks[nIndex], tBreaks[nIndex + 1];

                if (nEnd > nStart) then
                    local nDX = (nStart + nEnd) / 2 - nCenter;
                    local oBrush;

                    if (nDX^2 + nDY^2 >= nRadius^2) then
                        oBrush = tBrushes.Background;
                    else
                        local nPosition = 0;

                        for _, tNormal in ipairs(tNormals) do
                            nPosition = math.max(nPosition, (nDX * tNormal[1] + nDY * tNormal[2]) / nRadius);
                        end

                        local nReservePosition = sReserveDirection == "outward" and nPosition or 1 - nPosition;

                        if (nReserved >= 1 or nReservePosition < nReserved) then
                            oBrush = tBrushes.Reserve;
                        elseif (nPosition < nOpen or nOpen >= 1) then
                            oBrush = oPictureBrush or (bOpening and nCurrent > 0 and tBrushes.Fill or tBrushes.Track);
                        end
                    end

                    if (oBrush) then
                        oDC:SetBrush(oBrush);
                        oDC:DrawRectangle(nStart, nY, nEnd - nStart, 1);
                    end
                end
            end
        end

        oDC:SelectObject(_wx.wxNullBitmap);
        oDC:delete();
        oSeam:delete();

        if (oPictureBrush) then
            oPictureBrush:delete();
            oPicture:delete();
        end

        for _, oBrush in pairs(tBrushes) do
            oBrush:delete();
        end

        local oLarge = oBitmap:ConvertToImage();
        local oSmall = oLarge:Scale(nDiameter, nDiameter, _wx.wxIMAGE_QUALITY_HIGH);
        local oReplacement = _wx.wxBitmap(oSmall);
        oSmall:delete();
        oLarge:delete();
        oBitmap:delete();

        if (oRaster) then
            oRaster:delete();
        end

        oRaster, sRasterKey = oReplacement, sKey;
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.draw
    @desc Draws the centered cached iris and skinned caption into a borrowed DC.
        Non-square layouts preserve the circle; clipping includes the whole object.
    @param wxDC oDC Borrowed destination.
    @param number nWidth Available width.
    @param number nHeight Available height.
    !]]
    function oComponent.draw(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end

        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, math.max(1, nWidth), math.max(1, nHeight)));
        tArt.part(oDC, "Background "..(oComponent.isEnabled() and "Normal" or "Disabled"), 0, 0, nWidth, nHeight);
        local nDiameter = math.floor(math.min(nWidth, nHeight));

        if (nDiameter > 4) then
            fRaster(nDiameter);
            local nX, nY = math.floor((nWidth - nDiameter) / 2), math.floor((nHeight - nDiameter) / 2);
            oDC:DrawBitmap(oRaster, nX, nY, false);
            local nHalf = math.floor((nDiameter / 2 - 2) / math.sqrt(2));
            local oTextClip = _wx.wxDCClipper(oDC, _wx.wxRect(nX + nDiameter / 2 - nHalf,
                nY + nDiameter / 2 - nHalf, math.max(1, nHalf * 2), math.max(1, nHalf * 2)));
            local sDisplay = sText:gsub("%%v", tostring(oComponent.Value)):gsub("%%m", tostring(oComponent.Max));
            oDC:SetFont(oComponent.Skin.Font);
            local nTextWidth, nTextHeight = oDC:GetTextExtent(sDisplay);
            tArt.text(oDC, sDisplay, nX + (nDiameter - nTextWidth) / 2,
                nY + (nDiameter - nTextHeight) / 2, oComponent.isEnabled());
            oTextClip:delete();
        end

        oClip:delete();
    end

    -- The parent owns the native window; this object owns decoded/cached images.
    oComponent.onDestroy = function()
        if (oRaster) then
            oRaster:delete();
            oRaster = nil;
        end

        if (oImage) then
            oImage:delete();
            oImage = nil;
        end

        tArt.destroy();
    end;
    return oComponent;
end

return IrisProgress;
