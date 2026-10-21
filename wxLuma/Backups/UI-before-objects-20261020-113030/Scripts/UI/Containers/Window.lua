--[[!
@fqxn OpenWar.UI.Window
@desc Reusable dark window surface. Four-pixel border strips stretch only along
      their length; structural corners and separate ornaments keep fixed sizes.
      This component owns its artwork and drawing resources. It does not replace
      the existing UI.Frame skin or impose behavior on other application windows.
!]]
local wx = require("wx");
local Window = {};
local nMargin, nBorder, nOrnament = 12, 18, 52;
local tCorners = {"Upper Left", "Upper Right", "Lower Left", "Lower Right"};
local tEdges = {"Top", "Bottom", "Left", "Right"};

--[[!
@fqxn OpenWar.UI.Window.geometry
@desc Computes client-pixel rectangles. Resizing changes edge lengths and anchor
      positions, never corner/ornament dimensions. Use at least 320 by 240 pixels.
@param number nWidth Surface client width.
@param number nHeight Surface client height.
@ret table tLayout Outer, Content, Corners, Edges and Ornaments rectangles.
!]]
function Window.geometry(nWidth, nHeight)
    assert(nWidth >= 320 and nHeight >= 240, "Window surface requires at least 320 by 240 pixels.");
    local nX, nY = nMargin, nMargin;
    local nW, nH = nWidth - nMargin * 2, nHeight - nMargin * 2;
    local function fRect(x, y, width, height)
        return {x = x, y = y, width = width, height = height};
    end
    return {
        Outer = fRect(nX, nY, nW, nH),
        Content = fRect(nX + 40, nY + 100, nW - 80, nH - 144),
        Corners = {
            fRect(nX, nY, nBorder, nBorder),
            fRect(nX + nW - nBorder, nY, nBorder, nBorder),
            fRect(nX, nY + nH - nBorder, nBorder, nBorder),
            fRect(nX + nW - nBorder, nY + nH - nBorder, nBorder, nBorder),
        },
        Edges = {
            fRect(nX + nBorder, nY, nW - nBorder * 2, nBorder),
            fRect(nX + nBorder, nY + nH - nBorder, nW - nBorder * 2, nBorder),
            fRect(nX, nY + nBorder, nBorder, nH - nBorder * 2),
            fRect(nX + nW - nBorder, nY + nBorder, nBorder, nH - nBorder * 2),
        },
        Ornaments = {
            fRect(nX - 6, nY - 6, nOrnament, nOrnament),
            fRect(nX + nW - nOrnament + 6, nY - 6, nOrnament, nOrnament),
            fRect(nX - 6, nY + nH - nOrnament + 6, nOrnament, nOrnament),
            fRect(nX + nW - nOrnament + 6, nY + nH - nOrnament + 6, nOrnament, nOrnament),
        },
    };
end

--[[!
@fqxn OpenWar.UI.Window.create
@desc Creates a painted wxPanel. Future workbench widgets may parent to Control
      and lay out inside getGeometry().Content. PaintContent receives (DC, Content).
      Call destroy when its owning frame closes; artwork is released exactly once.
@param wxWindow oParent Owning native window.
@param table tOptions Title, Subtitle, optional AssetPath and PaintContent callback.
@ret table tWindow Control, draw, getGeometry and destroy methods.
!]]
function Window.create(oParent, tOptions)
    tOptions = tOptions or {};
    local sRoot = tOptions.AssetPath or APP_PATH .. "/Images/UI/Window/";
    local oControl = wx.wxPanel(oParent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize,
        wx.wxTAB_TRAVERSAL + wx.wxCLIP_CHILDREN);
    oControl:SetBackgroundStyle(wx.wxBG_STYLE_PAINT);
    local tImages, tBitmaps, tEdgeBitmaps = {}, {}, {};
    local bDisposed = false;
    local nLastWidth, nLastHeight;
    local oSurface;
    local nSurfaceWidth, nSurfaceHeight;
    local oTitleFont = wx.wxFont(20, wx.wxFONTFAMILY_ROMAN, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL);
    local oBodyFont = wx.wxFont(10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL);
    local tWindow = {Control = oControl};

    local function fLoad(sName, nSize)
        local oImage = wx.wxImage(sRoot .. sName .. ".png", wx.wxBITMAP_TYPE_PNG);
        assert(oImage:IsOk(), "Unable to load window part: " .. sName);
        tImages[sName] = oImage;
        local oScaled;
        if (nSize) then
            local nScale = nSize / math.max(oImage:GetWidth(), oImage:GetHeight());
            oScaled = oImage:Scale(math.max(1, math.floor(oImage:GetWidth() * nScale)),
                math.max(1, math.floor(oImage:GetHeight() * nScale)), wx.wxIMAGE_QUALITY_HIGH);
        end
        tBitmaps[sName] = wx.wxBitmap(oScaled or oImage);
        if (oScaled) then oScaled:delete(); end
    end
    for _, sCorner in ipairs(tCorners) do
        fLoad("Window Corner " .. sCorner);
        fLoad("Window Ornament " .. sCorner, nOrnament);
    end
    for _, sEdge in ipairs(tEdges) do fLoad("Window Border " .. sEdge); end
    fLoad("Window Grain");

    function tWindow.getGeometry()
        local nWidth, nHeight = oControl:GetClientSizeWH();
        return Window.geometry(nWidth, nHeight);
    end

    local function fDrawSurface(oDC, nWidth, nHeight)
        local tLayout = Window.geometry(nWidth, nHeight);
        local tR = tLayout.Outer;
        local oBackground = wx.wxBrush(wx.wxColour(10, 12, 16));
        oDC:SetBackground(oBackground); oDC:Clear();
        oDC:GradientFillLinear(wx.wxRect(tR.x, tR.y, tR.width, tR.height),
            wx.wxColour(31, 36, 43), wx.wxColour(16, 19, 24), wx.wxSOUTH);
        oDC:SetClippingRegion(tR.x + nBorder, tR.y + nBorder,
            tR.width - nBorder * 2, tR.height - nBorder * 2);
        -- Composite one opaque column, then copy it across the surface. The
        -- gradient and grain retain their original pixel coordinates; expensive
        -- alpha compositing happens once per grain row rather than per tile.
        local oStrip = wx.wxBitmap(64, nHeight);
        local oStripDC = wx.wxMemoryDC(); oStripDC:SelectObject(oStrip);
        oStripDC:GradientFillLinear(wx.wxRect(0, tR.y, 64, tR.height),
            wx.wxColour(31, 36, 43), wx.wxColour(16, 19, 24), wx.wxSOUTH);
        for nY = tR.y + nBorder, tR.y + tR.height, 64 do
            oStripDC:DrawBitmap(tBitmaps["Window Grain"], 0, nY, true);
        end
        for nX = tR.x + nBorder, tR.x + tR.width, 64 do
            oDC:Blit(nX, tR.y + nBorder, 64, tR.height - nBorder * 2,
                oStripDC, 0, tR.y + nBorder, wx.wxCOPY);
        end
        oStripDC:SelectObject(wx.wxNullBitmap); oStripDC:delete(); oStrip:delete();
        oDC:DestroyClippingRegion();
        if (nWidth ~= nLastWidth or nHeight ~= nLastHeight) then
            for nIndex, sEdge in ipairs(tEdges) do
                if (tEdgeBitmaps[nIndex]) then tEdgeBitmaps[nIndex]:delete(); end
                local tEdge = tLayout.Edges[nIndex];
                local oScaled = tImages["Window Border " .. sEdge]:Scale(
                    tEdge.width, tEdge.height, wx.wxIMAGE_QUALITY_HIGH);
                tEdgeBitmaps[nIndex] = wx.wxBitmap(oScaled); oScaled:delete();
            end
            nLastWidth, nLastHeight = nWidth, nHeight;
        end
        for nIndex, tEdge in ipairs(tLayout.Edges) do
            oDC:DrawBitmap(tEdgeBitmaps[nIndex], tEdge.x, tEdge.y, true);
        end
        for nIndex, sCorner in ipairs(tCorners) do
            local tCorner = tLayout.Corners[nIndex];
            local tOrnament = tLayout.Ornaments[nIndex];
            oDC:DrawBitmap(tBitmaps["Window Corner " .. sCorner], tCorner.x, tCorner.y, true);
            local oBitmap = tBitmaps["Window Ornament " .. sCorner];
            oDC:DrawBitmap(oBitmap, tOrnament.x + math.floor((nOrnament - oBitmap:GetWidth()) / 2),
                tOrnament.y + math.floor((nOrnament - oBitmap:GetHeight()) / 2), true);
        end
        oDC:SetBackgroundMode(wx.wxTRANSPARENT);
        oDC:SetFont(oTitleFont); oDC:SetTextForeground(wx.wxColour(211, 214, 219));
        oDC:DrawText(tOptions.Title or "UI TEST", tR.x + 62, tR.y + 27);
        oDC:SetFont(oBodyFont); oDC:SetTextForeground(wx.wxColour(133, 144, 158));
        oDC:DrawText(tOptions.Subtitle or "", tR.x + 64, tR.y + 59);
        local oRule = wx.wxPen(wx.wxColour(62, 68, 77), 1, wx.wxPENSTYLE_SOLID);
        oDC:SetPen(oRule);
        oDC:DrawLine(tR.x + 40, tR.y + 87, tR.x + tR.width - 40, tR.y + 87);
        oRule:delete(); oBackground:delete();
    end

    -- Keep static artwork cached; content remains live on every paint.
    -- Draw is also usable with a memory DC for isolated native render verification.
    function tWindow.draw(oDC, nWidth, nHeight)
        if (bDisposed) then return; end
        if (not oSurface or nWidth ~= nSurfaceWidth or nHeight ~= nSurfaceHeight) then
            if (oSurface) then oSurface:delete(); end
            oSurface = wx.wxBitmap(nWidth, nHeight);
            local oMemory = wx.wxMemoryDC(); oMemory:SelectObject(oSurface);
            fDrawSurface(oMemory, nWidth, nHeight);
            oMemory:SelectObject(wx.wxNullBitmap); oMemory:delete();
            nSurfaceWidth, nSurfaceHeight = nWidth, nHeight;
        end
        oDC:DrawBitmap(oSurface, 0, 0, false);
        if (tOptions.PaintContent) then tOptions.PaintContent(oDC, Window.geometry(nWidth, nHeight).Content); end
    end
    function tWindow.destroy()
        if (bDisposed) then return; end
        bDisposed = true;
        if (oSurface) then oSurface:delete(); oSurface = nil; end
        for _, oBitmap in pairs(tEdgeBitmaps) do oBitmap:delete(); end
        for _, oBitmap in pairs(tBitmaps) do oBitmap:delete(); end
        for _, oImage in pairs(tImages) do oImage:delete(); end
        oTitleFont:delete(); oBodyFont:delete();
    end
    oControl:Connect(wx.wxEVT_PAINT, function()
        local nWidth, nHeight = oControl:GetClientSizeWH();
        -- draw already builds an opaque cached surface before copying it. Avoid
        -- a second client-sized buffering bitmap; native clipping skips children.
        local oDC = wx.wxPaintDC(oControl);
        if (not bDisposed and nWidth >= 320 and nHeight >= 240) then tWindow.draw(oDC, nWidth, nHeight); end
        oDC:delete();
    end);
    oControl:Connect(wx.wxEVT_SIZE, function(oEvent)
        if (not bDisposed) then oControl:Refresh(false); end
        oEvent:Skip();
    end);
    return tWindow;
end
return Window;
