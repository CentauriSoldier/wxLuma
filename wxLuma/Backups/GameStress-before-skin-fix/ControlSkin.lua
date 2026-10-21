local _ControlObject = require("UI.Core.ControlObject");
local _wx            = require("wx");
local ControlSkin    = {};

--[[!
@fqxn wxLuma.UI.ControlSkin.load
@param string|nil pRoot Artwork directory; defaults to application Images/UI/Controls/.
@ret table oSkin Shared image cache with draw, text and destroy methods. Dispose after its controls.
!]]
function ControlSkin.load(pRoot)
    pRoot = pRoot or APP_PATH .."/Images/UI/Controls/";
    local tImages, tBitmaps, tScaled, tOpaque = {}, {}, {}, {};
    local tOpaqueOrder                        = {};
    local bDisposed                           = false;
    local oFont                               = _wx.wxFont(11, _wx.wxFONTFAMILY_DEFAULT,
        _wx.wxFONTSTYLE_NORMAL, _wx.wxFONTWEIGHT_NORMAL);
    local oSkin                               = _ControlObject.create({
        Font = oFont
    }, "wxLuma.UI.ControlSkin");

    --[[!
    @fqxn wxLuma.UI.ControlSkin.draw
    @desc Lazily loads and alpha-draws artwork, caching the latest scaled size per image and orientation.
    @param wxDC oDC The destination drawing context.
    @param string sName The artwork name.
    @param number nX The horizontal client coordinate.
    @param number nY The vertical client coordinate.
    @param number nWidth The width in pixels.
    @param number nHeight The height in pixels.
    @param boolean bVertical Whether to rotate artwork for vertical drawing.
    !]]
    function oSkin.draw(oDC, sName, nX, nY, nWidth, nHeight, bVertical)
        assert(not bDisposed, "Control skin is disposed.");
        if (not tImages[sName]) then
            local oImage = _wx.wxImage(pRoot .."Control " .. sName ..".png", _wx.wxBITMAP_TYPE_PNG);
            assert(oImage:IsOk(), "Missing control artwork: " .. sName);
            tImages[sName], tBitmaps[sName] = oImage, _wx.wxBitmap(oImage);
        end
        local oBitmap = tBitmaps[sName];
        if (nWidth or bVertical) then
            local sKey   = sName .. (bVertical and ":vertical" or ":horizontal");
            local tEntry = tScaled[sKey];
            nWidth, nHeight = math.floor(nWidth), math.floor(nHeight);
            if (not tEntry or tEntry.Width ~= nWidth or tEntry.Height ~= nHeight) then
                if (tEntry) then
                    tEntry.Bitmap:delete();
                end
                local oRotated = bVertical and tImages[sName]:Rotate90(true) or nil;
                local oScaled  = (oRotated or tImages[sName]):Scale(nWidth, nHeight, _wx.wxIMAGE_QUALITY_HIGH);
                tEntry = {
                    Width  = nWidth,
                    Height = nHeight,
                    Bitmap = _wx.wxBitmap(oScaled)
                };
                tScaled[sKey] = tEntry;
                oScaled:delete();
                if (oRotated) then
                    oRotated:delete();
                end
            end
            oBitmap = tEntry.Bitmap;
        end
        oDC:DrawBitmap(oBitmap, math.floor(nX), math.floor(nY), true);
    end

    -- Default control backgrounds are opaque charcoal. Composite variable-length
    -- artwork once per size/state, then use inexpensive opaque copies. Custom
    -- Background callbacks continue using alpha-aware draw without flattening.

    --[[!
    @fqxn wxLuma.UI.ControlSkin.drawOpaque
    @desc Draws cached artwork flattened over charcoal, retaining at most 96 size and state variants.
    @param wxDC oDC The destination drawing context.
    @param string sName The artwork name.
    @param number nX The horizontal client coordinate.
    @param number nY The vertical client coordinate.
    @param number nWidth The width in pixels.
    @param number nHeight The height in pixels.
    @param boolean bVertical Whether to rotate artwork for vertical drawing.
    !]]
    function oSkin.drawOpaque(oDC, sName, nX, nY, nWidth, nHeight, bVertical)
        assert(not bDisposed, "Control skin is disposed.");
        local sKey   = sName .. (bVertical and ":vertical"
            or ":horizontal") ..":" .. tostring(nWidth) ..":" .. tostring(nHeight);
        local tEntry = tOpaque[sKey];
        if (not tEntry or tEntry.Width ~= nWidth or tEntry.Height ~= nHeight) then
            if (tEntry) then
                tEntry.Bitmap:delete();
            end
            if (not tImages[sName]) then
                local oImage = _wx.wxImage(pRoot .."Control " .. sName ..".png", _wx.wxBITMAP_TYPE_PNG);
                assert(oImage:IsOk(), "Missing control artwork: " .. sName);
                tImages[sName], tBitmaps[sName] = oImage, _wx.wxBitmap(oImage);
            end
            local nWidth  = nWidth or tBitmaps[sName]:GetWidth();
            local nHeight = nHeight or tBitmaps[sName]:GetHeight();
            local oBitmap = _wx.wxBitmap(nWidth, nHeight);
            local oMemory = _wx.wxMemoryDC();
            oMemory:SelectObject(oBitmap);
            local oBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
            oMemory:SetBackground(oBrush);
            oMemory:Clear();
            oSkin.draw(oMemory, sName, 0, 0, nWidth, nHeight, bVertical);
            oMemory:SelectObject(_wx.wxNullBitmap);
            oMemory:delete();
            oBrush:delete();
            tEntry = {
                Width  = nWidth,
                Height = nHeight,
                Bitmap = oBitmap
            };
            tOpaque[sKey] = tEntry;
            tOpaqueOrder[#tOpaqueOrder + 1] = sKey;
            if (#tOpaqueOrder > 96) then
                local sOld = table.remove(tOpaqueOrder, 1);
                tOpaque[sOld].Bitmap:delete();
                tOpaque[sOld] = nil;
            end
        end
        oDC:DrawBitmap(tEntry.Bitmap, math.floor(nX), math.floor(nY), false);
    end

    --[[!
    @fqxn wxLuma.UI.ControlSkin.text
    @desc Draws text with the shared font, transparent background and enabled or disabled colour.
    @param wxDC oDC The destination drawing context.
    @param string sText The displayed text.
    @param number nX The horizontal client coordinate.
    @param number nY The vertical client coordinate.
    @param boolean bEnabled Whether the component is enabled.
    !]]
    function oSkin.text(oDC, sText, nX, nY, bEnabled)
        oDC:SetFont(oFont);
        oDC:SetBackgroundMode(_wx.wxTRANSPARENT);
        oDC:SetTextForeground(bEnabled == false and _wx.wxColour(114, 126, 139) or _wx.wxColour(208, 218, 230));
        oDC:DrawText(sText, math.floor(nX), math.floor(nY));
    end

    --[[!
    @fqxn wxLuma.UI.ControlSkin.destroy
    @desc Deletes all cached bitmaps, images and the shared font once; call after its controls are disposed.
    !]]
    function oSkin.destroy()
        if (bDisposed) then
            return;
        end
        bDisposed = true;
        for _, tEntry in pairs(tScaled) do
            tEntry.Bitmap:delete();
        end
        for _, tEntry in pairs(tOpaque) do
            tEntry.Bitmap:delete();
        end
        for _, oBitmap in pairs(tBitmaps) do
            oBitmap:delete();
        end
        for _, oImage in pairs(tImages) do
            oImage:delete();
        end
        oFont:delete();
    end
    return oSkin;
end

return ControlSkin;
