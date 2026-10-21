local wx = require("wx");
local ControlSkin = {};

--[[!
@fqxn OpenWar.UI.ControlSkin.load
@param string|nil sRoot Artwork directory; defaults to application Images/UI/Controls/.
@ret table tSkin Shared image cache with draw, text and destroy methods. Dispose after its controls.
!]]
function ControlSkin.load(sRoot)
    sRoot = sRoot or APP_PATH .. "/Images/UI/Controls/";
    local tImages, tBitmaps, tScaled, tOpaque = {}, {}, {}, {};
    local tOpaqueOrder = {};
    local bDisposed = false;
    local oFont = wx.wxFont(11, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL);
    local tSkin = {Font = oFont};
    function tSkin.draw(oDC, sName, nX, nY, nWidth, nHeight, bVertical)
        assert(not bDisposed, "Control skin is disposed.");
        if (not tImages[sName]) then
            local oImage = wx.wxImage(sRoot .. "Control " .. sName .. ".png", wx.wxBITMAP_TYPE_PNG);
            assert(oImage:IsOk(), "Missing control artwork: " .. sName);
            tImages[sName], tBitmaps[sName] = oImage, wx.wxBitmap(oImage);
        end
        local oBitmap = tBitmaps[sName];
        if (nWidth or bVertical) then
            local sKey = sName .. (bVertical and ":vertical" or ":horizontal");
            local tEntry = tScaled[sKey];
            nWidth, nHeight = math.floor(nWidth), math.floor(nHeight);
            if (not tEntry or tEntry.Width ~= nWidth or tEntry.Height ~= nHeight) then
                if (tEntry) then tEntry.Bitmap:delete(); end
                local oRotated = bVertical and tImages[sName]:Rotate90(true) or nil;
                local oScaled = (oRotated or tImages[sName]):Scale(nWidth, nHeight, wx.wxIMAGE_QUALITY_HIGH);
                tEntry = {Width = nWidth, Height = nHeight, Bitmap = wx.wxBitmap(oScaled)};
                tScaled[sKey] = tEntry;
                oScaled:delete(); if (oRotated) then oRotated:delete(); end
            end
            oBitmap = tEntry.Bitmap;
        end
        oDC:DrawBitmap(oBitmap, math.floor(nX), math.floor(nY), true);
    end
    -- Default control backgrounds are opaque charcoal. Composite variable-length
    -- artwork once per size/state, then use inexpensive opaque copies. Custom
    -- Background callbacks continue using alpha-aware draw without flattening.
    function tSkin.drawOpaque(oDC, sName, nX, nY, nWidth, nHeight, bVertical)
        assert(not bDisposed, "Control skin is disposed.");
        local sKey = sName .. (bVertical and ":vertical" or ":horizontal") .. ":" .. tostring(nWidth) .. ":" .. tostring(nHeight);
        local tEntry = tOpaque[sKey];
        if (not tEntry or tEntry.Width ~= nWidth or tEntry.Height ~= nHeight) then
            if (tEntry) then tEntry.Bitmap:delete(); end
            if (not tImages[sName]) then
                local oImage = wx.wxImage(sRoot .. "Control " .. sName .. ".png", wx.wxBITMAP_TYPE_PNG);
                assert(oImage:IsOk(), "Missing control artwork: " .. sName);
                tImages[sName], tBitmaps[sName] = oImage, wx.wxBitmap(oImage);
            end
            local nW = nWidth or tBitmaps[sName]:GetWidth(); local nH = nHeight or tBitmaps[sName]:GetHeight();
            local oBitmap = wx.wxBitmap(nW, nH); local oMemory = wx.wxMemoryDC(); oMemory:SelectObject(oBitmap);
            local oBrush = wx.wxBrush(wx.wxColour(24, 29, 36)); oMemory:SetBackground(oBrush); oMemory:Clear();
            tSkin.draw(oMemory, sName, 0, 0, nWidth, nHeight, bVertical);
            oMemory:SelectObject(wx.wxNullBitmap); oMemory:delete(); oBrush:delete();
            tEntry = {Width = nWidth, Height = nHeight, Bitmap = oBitmap}; tOpaque[sKey] = tEntry;
            tOpaqueOrder[#tOpaqueOrder + 1] = sKey;
            if (#tOpaqueOrder > 96) then local sOld = table.remove(tOpaqueOrder, 1); tOpaque[sOld].Bitmap:delete(); tOpaque[sOld] = nil; end
        end
        oDC:DrawBitmap(tEntry.Bitmap, math.floor(nX), math.floor(nY), false);
    end
    function tSkin.text(oDC, sText, nX, nY, bEnabled)
        oDC:SetFont(oFont); oDC:SetBackgroundMode(wx.wxTRANSPARENT);
        oDC:SetTextForeground(bEnabled == false and wx.wxColour(114, 126, 139) or wx.wxColour(208, 218, 230));
        oDC:DrawText(sText, math.floor(nX), math.floor(nY));
    end
    function tSkin.destroy()
        if (bDisposed) then return; end
        bDisposed = true;
        for _, tEntry in pairs(tScaled) do tEntry.Bitmap:delete(); end
        for _, tEntry in pairs(tOpaque) do tEntry.Bitmap:delete(); end
        for _, oBitmap in pairs(tBitmaps) do oBitmap:delete(); end
        for _, oImage in pairs(tImages) do oImage:delete(); end
        oFont:delete();
    end
    return tSkin;
end

return ControlSkin;
