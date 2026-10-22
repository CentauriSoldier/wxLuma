local _wx = require("wx");
local PyramidCanvas = {};
local _tVertices = {{X = -1, Y = -0.75, Z = -1}, {X = 1, Y = -0.75, Z = -1},
    {X = 1, Y = -0.75, Z = 1}, {X = -1, Y = -0.75, Z = 1}, {X = 0, Y = 1.25, Z = 0}};
local _tFaces = {{1, 5, 2}, {2, 5, 3}, {3, 5, 4}, {4, 5, 1}};
local _tEdges = {{1, 2}, {2, 3}, {3, 4}, {4, 1}, {1, 5}, {2, 5}, {3, 5}, {4, 5}};
local _tFaceColors = {{R = 65, G = 170, B = 245, A = 44}, {R = 240, G = 155, B = 65, A = 44},
    {R = 180, G = 110, B = 240, A = 44}, {R = 65, G = 210, B = 155, A = 44}};
local _tVertexColors = {{R = 70, G = 190, B = 255, A = 185}, {R = 255, G = 170, B = 75, A = 185},
    {R = 200, G = 125, B = 255, A = 185}, {R = 80, G = 225, B = 165, A = 185}, {R = 255, G = 100, B = 145, A = 200}};

--[[!
@fqxn Custom.PyramidCanvas.number
@desc Validates finite numeric input before it reaches projection or native APIs.
!]]
local function number(nValue)
    assert(type(nValue) == "number" and nValue == nValue and math.abs(nValue) < math.huge, "Expected a finite number.");
    return nValue;
end

--[[!
@fqxn Custom.PyramidCanvas.copy
@desc Copies the small plain geometry, style and event records owned by this object.
!]]
local function copy(vValue)
    if (type(vValue) ~= "table") then return vValue; end
    local tResult = {}; for vKey, vItem in pairs(vValue) do tResult[vKey] = copy(vItem); end; return tResult;
end

--[[!
@fqxn Custom.PyramidCanvas.array
@desc Copies a fixed-length dense list of names or RGBA colors atomically.
!]]
local function array(tSource, nCount, bColors)
    assert(type(tSource) == "table" and #tSource == nCount, "Incorrect item count.");
    local nKeys = 0;
    for nKey in pairs(tSource) do
        assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= nCount, "Use a dense array."); nKeys = nKeys + 1;
    end
    assert(nKeys == nCount, "Use a dense array.");
    local tResult = {};
    for nIndex = 1, nCount do
        local vItem = tSource[nIndex];
        if (bColors) then
            assert(type(vItem) == "table", "Color must contain R/G/B and optional A.");
            local tColor = {};
            for _, sChannel in ipairs({"R", "G", "B", "A"}) do
                local nValue = vItem[sChannel]; if (sChannel == "A" and nValue == nil) then nValue = 255; end
                number(nValue); assert(nValue % 1 == 0 and nValue >= 0 and nValue <= 255, "Color channels must be bytes.");
                tColor[sChannel] = nValue;
            end
            tResult[nIndex] = tColor;
        else
            assert(type(vItem) == "string", "Names must be strings."); tResult[nIndex] = vItem;
        end
    end
    return tResult;
end

--[[!
@fqxn Custom.PyramidCanvas.create
@desc Creates a standalone square-based 3D pyramid canvas, independent of wxLuma.
    Exactly four side faces and five vertices are named and colored. The base
    is open; eight edges connect neighboring vertices. Translucent faces and
    markers reveal the structure behind them. Drag rotates; wheel zooms; arrows
    rotate; +/- zoom; Home or double-click resets. Geometry is projected from
    true 3D coordinates onto a supersampled wx canvas; OpenGL is not required.
@param wxWindow oParent Native owner.
@param table|nil tOptions FaceNames[4], VertexNames[5], FaceColors[4],
    VertexColors[5] (RGBA bytes), Rotation={Yaw,Pitch,Roll} in degrees,
    Zoom (0.6-1.65), FacesVisible (true), Font (borrowed wxFont),
    Background (RGBA, alpha ignored). Defaults are independent for each instance.
@ret table oCanvas Control, layout, draw, getGeometry, get/setRotation,
    get/setZoom, get/setFaceNames, get/setVertexNames, get/setFaceColors,
    get/setVertexColors, get/setFacesVisible, resetView, on, off, destroy.
    Events: viewChanged, itemClicked, enter, leave, leftClick, rightClick.
    Item records contain Kind (face/vertex), Index, Name and Color.
!]]
function PyramidCanvas.create(oParent, tOptions)
    tOptions = tOptions or {};
    local tFaceNames = array(tOptions.FaceNames or {"Side 1", "Side 2", "Side 3", "Side 4"}, 4);
    local tVertexNames = array(tOptions.VertexNames or {"Vertex 1", "Vertex 2", "Vertex 3", "Vertex 4", "Apex"}, 5);
    local tFaceColors = array(tOptions.FaceColors or _tFaceColors, 4, true);
    local tVertexColors = array(tOptions.VertexColors or _tVertexColors, 5, true);
    local tBackground = array({tOptions.Background or {R = 18, G = 24, B = 34}}, 1, true)[1];
    local bFacesVisible = tOptions.FacesVisible ~= false;
    assert(tOptions.FacesVisible == nil or type(tOptions.FacesVisible) == "boolean", "FacesVisible must be boolean.");
    local tRotation = {Yaw = 32, Pitch = 20, Roll = 0};
    local nZoom = 1;
    if (tOptions.Rotation ~= nil) then
        assert(type(tOptions.Rotation) == "table", "Rotation must contain Yaw/Pitch/Roll.");
        for _, sAxis in ipairs({"Yaw", "Pitch", "Roll"}) do tRotation[sAxis] = (number(tOptions.Rotation[sAxis]) + 180) % 360 - 180; end
    end
    if (tOptions.Zoom ~= nil) then nZoom = math.max(0.6, math.min(1.65, number(tOptions.Zoom))); end
    local tInitialRotation, nInitialZoom = copy(tRotation), nZoom;
    local tListeners, tLabels = {}, {};
    local tCache, tDrag;
    local bDisposed = false;
    local oControl = _wx.wxPanel(oParent, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _wx.wxBORDER_NONE + _wx.wxWANTS_CHARS);
    oControl:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    local bOwnFont = tOptions.Font == nil;
    local oFont = tOptions.Font or _wx.wxFont(10, _wx.wxFONTFAMILY_SWISS, _wx.wxFONTSTYLE_NORMAL, _wx.wxFONTWEIGHT_NORMAL);
    local oCanvas = {Control = oControl};

    --[[!
    @fqxn Custom.PyramidCanvas.create.invalidate
    @desc Releases cached pixels immediately and requests an erase-free repaint.
    !]]
    local function fInvalidate()
        assert(not bDisposed, "PyramidCanvas is disposed.");
        if (tCache) then tCache.Bitmap:delete(); tCache = nil; end
        tLabels = {}; oControl:Refresh(false);
    end

    --[[!
    @fqxn Custom.PyramidCanvas.create.emit
    @desc Delivers independent event data to a snapshot of current listeners.
    !]]
    local function fEmit(sEvent, tData)
        local tCallbacks = {}; for _, fCallback in ipairs(tListeners[sEvent] or {}) do tCallbacks[#tCallbacks + 1] = fCallback; end
        for _, fCallback in ipairs(tCallbacks) do fCallback(copy(tData or {}), oCanvas); end
    end

    --[[!
    @fqxn Custom.PyramidCanvas.on
    @desc Subscribes a callback; returns it for later removal with off(event,callback).
    !]]
    function oCanvas.on(sEvent, fCallback)
        assert(not bDisposed and type(sEvent) == "string" and type(fCallback) == "function", "Invalid event subscription.");
        tListeners[sEvent] = tListeners[sEvent] or {}; table.insert(tListeners[sEvent], fCallback); return fCallback;
    end

    --[[!
    @fqxn Custom.PyramidCanvas.off
    @desc Removes one matching callback without changing any other subscriptions.
    !]]
    function oCanvas.off(sEvent, fCallback)
        for nIndex, fItem in ipairs(tListeners[sEvent] or {}) do
            if (fItem == fCallback) then table.remove(tListeners[sEvent], nIndex); break; end
        end
        return oCanvas;
    end

    --[[!
    @fqxn Custom.PyramidCanvas.rotation
    @desc Gets a detached degree rotation, or sets finite Yaw/Pitch/Roll atomically.
        Angles wrap to [-180,180); optional notification reports the committed view.
    !]]
    function oCanvas.getRotation() return copy(tRotation); end
    function oCanvas.setRotation(tValue, bNotify)
        assert(type(tValue) == "table", "Rotation must contain Yaw/Pitch/Roll.");
        local tNext = {};
        for _, sAxis in ipairs({"Yaw", "Pitch", "Roll"}) do tNext[sAxis] = (number(tValue[sAxis]) + 180) % 360 - 180; end
        if (tNext.Yaw ~= tRotation.Yaw or tNext.Pitch ~= tRotation.Pitch or tNext.Roll ~= tRotation.Roll) then
            fInvalidate(); tRotation = tNext;
            if (bNotify) then fEmit("viewChanged", {Rotation = tRotation, Zoom = nZoom}); end
        else assert(not bDisposed, "PyramidCanvas is disposed."); end
        return oCanvas;
    end

    --[[!
    @fqxn Custom.PyramidCanvas.zoom
    @desc Gets zoom or clamps a finite requested zoom to 0.6-1.65. Only actual
        changes repaint and optionally emit viewChanged; zero/negative values clamp.
    !]]
    function oCanvas.getZoom() return nZoom; end
    function oCanvas.setZoom(nValue, bNotify)
        local nNext = math.max(0.6, math.min(1.65, number(nValue)));
        assert(not bDisposed, "PyramidCanvas is disposed.");
        if (nNext ~= nZoom) then fInvalidate(); nZoom = nNext; if (bNotify) then fEmit("viewChanged", {Rotation = tRotation, Zoom = nZoom}); end end
        return oCanvas;
    end

    --[[!
    @fqxn Custom.PyramidCanvas.itemProperties
    @desc Gets detached item names/colors or atomically replaces their fixed-size
        arrays. Colors include individual translucency; setters never retain inputs.
    !]]
    function oCanvas.getFaceNames() return copy(tFaceNames); end
    function oCanvas.setFaceNames(tValue) local tNext = array(tValue, 4); fInvalidate(); tFaceNames = tNext; return oCanvas; end
    function oCanvas.getVertexNames() return copy(tVertexNames); end
    function oCanvas.setVertexNames(tValue) local tNext = array(tValue, 5); fInvalidate(); tVertexNames = tNext; return oCanvas; end
    function oCanvas.getFaceColors() return copy(tFaceColors); end
    function oCanvas.setFaceColors(tValue) local tNext = array(tValue, 4, true); fInvalidate(); tFaceColors = tNext; return oCanvas; end
    function oCanvas.getVertexColors() return copy(tVertexColors); end
    function oCanvas.setVertexColors(tValue) local tNext = array(tValue, 5, true); fInvalidate(); tVertexColors = tNext; return oCanvas; end

    --[[!
    @fqxn Custom.PyramidCanvas.facesVisible
    @desc Gets/sets whether translucent side panels are shown. Edges, names and
        colored vertex markers remain available in the open wireframe view.
    !]]
    function oCanvas.getFacesVisible() return bFacesVisible; end
    function oCanvas.setFacesVisible(bValue)
        assert(type(bValue) == "boolean", "FacesVisible must be boolean."); fInvalidate(); bFacesVisible = bValue; return oCanvas;
    end

    --[[!
    @fqxn Custom.PyramidCanvas.resetView
    @desc Restores the initial orientation and zoom in one changed-only operation.
    !]]
    function oCanvas.resetView(bNotify)
        assert(not bDisposed, "PyramidCanvas is disposed.");
        local bChanged = tRotation.Yaw ~= tInitialRotation.Yaw or tRotation.Pitch ~= tInitialRotation.Pitch
            or tRotation.Roll ~= tInitialRotation.Roll or nZoom ~= nInitialZoom;
        if (bChanged) then
            fInvalidate(); tRotation, nZoom = copy(tInitialRotation), nInitialZoom;
            if (bNotify) then fEmit("viewChanged", {Rotation = tRotation, Zoom = nZoom}); end
        end
        return oCanvas;
    end

    --[[!
    @fqxn Custom.PyramidCanvas.getGeometry
    @desc Returns projected vertices, face centroids/depths and all eight unique
        edges for explicit viewport dimensions (or current client size). Projection
        keeps the camera outside the rotation-invariant model bounding sphere.
    !]]
    function oCanvas.getGeometry(nWidth, nHeight)
        assert(not bDisposed, "PyramidCanvas is disposed.");
        if (nWidth == nil) then nWidth, nHeight = oControl:GetClientSizeWH(); end
        number(nWidth); number(nHeight);
        local nScale = math.max(1, math.min(nWidth * 0.55, nHeight * 0.72)) * 0.32 * nZoom;
        local nYaw, nPitch, nRoll = math.rad(tRotation.Yaw), math.rad(tRotation.Pitch), math.rad(tRotation.Roll);
        local tPoints = {};
        for nIndex, tPoint in ipairs(_tVertices) do
            local nX, nY, nZ = tPoint.X * math.cos(nYaw) + tPoint.Z * math.sin(nYaw), tPoint.Y,
                -tPoint.X * math.sin(nYaw) + tPoint.Z * math.cos(nYaw);
            nY, nZ = nY * math.cos(nPitch) - nZ * math.sin(nPitch), nY * math.sin(nPitch) + nZ * math.cos(nPitch);
            nX, nY = nX * math.cos(nRoll) - nY * math.sin(nRoll), nX * math.sin(nRoll) + nY * math.cos(nRoll);
            local nPerspective = 4.8 / (4.8 - nZ);
            tPoints[nIndex] = {X = nWidth / 2 + nX * nScale * nPerspective, Y = nHeight / 2 - nY * nScale * nPerspective,
                Z = nZ, Name = tVertexNames[nIndex], Color = copy(tVertexColors[nIndex])};
        end
        local tFaces = {};
        for nIndex, tFace in ipairs(_tFaces) do
            local tA, tB, tC = tPoints[tFace[1]], tPoints[tFace[2]], tPoints[tFace[3]];
            tFaces[nIndex] = {Index = nIndex, Vertices = copy(tFace), X = (tA.X + tB.X + tC.X) / 3,
                Y = (tA.Y + tB.Y + tC.Y) / 3, Z = (tA.Z + tB.Z + tC.Z) / 3,
                Name = tFaceNames[nIndex], Color = copy(tFaceColors[nIndex])};
        end
        return {Vertices = tPoints, Faces = tFaces, Edges = copy(_tEdges)};
    end

    --[[!
    @fqxn Custom.PyramidCanvas.create.blend
    @desc Draws binary native coverage into a cropped mask and composites true
        RGBA over a small destination copy. Supersampling filters the final edges.
        Cropping avoids a full-canvas alpha readback for every face/vertex.
    !]]
    local function fBlend(oDC, tColor, nLeft, nTop, nRight, nBottom, fDraw)
        if (tColor.A == 0) then return; end
        local nDCW, nDCH = oDC:GetSize();
        nLeft, nTop = math.max(0, math.floor(nLeft)), math.max(0, math.floor(nTop));
        local nWidth, nHeight = math.min(nDCW, math.ceil(nRight)) - nLeft, math.min(nDCH, math.ceil(nBottom)) - nTop;
        if (nWidth < 1 or nHeight < 1) then return; end
        local oMask = _wx.wxBitmap(nWidth, nHeight); local oMaskDC = _wx.wxMemoryDC(); oMaskDC:SelectObject(oMask);
        oMaskDC:SetBackground(_wx.wxBLACK_BRUSH); oMaskDC:Clear(); oMaskDC:SetPen(_wx.wxTRANSPARENT_PEN); oMaskDC:SetBrush(_wx.wxWHITE_BRUSH);
        oMaskDC:SetDeviceOrigin(-nLeft, -nTop); fDraw(oMaskDC);
        oMaskDC:SelectObject(_wx.wxNullBitmap); oMaskDC:delete();
        local oImage = oMask:ConvertToImage(); oMask:delete(); oImage:SetMaskColour(0, 0, 0); oImage:InitAlpha();
        local sAlpha = oImage:GetAlpha():gsub("\255+", function(sRun) return string.rep(string.char(tColor.A), #sRun); end);
        oImage:SetMask(false); oImage:SetData(string.rep(string.char(tColor.R, tColor.G, tColor.B), nWidth * nHeight)); oImage:SetAlpha(sAlpha);
        local oFill = _wx.wxBitmap(oImage); oImage:delete();
        local oPatch = _wx.wxBitmap(nWidth, nHeight); local oPatchDC = _wx.wxMemoryDC(); oPatchDC:SelectObject(oPatch);
        oPatchDC:Blit(0, 0, nWidth, nHeight, oDC, nLeft, nTop, _wx.wxCOPY); oPatchDC:DrawBitmap(oFill, 0, 0, true);
        oDC:Blit(nLeft, nTop, nWidth, nHeight, oPatchDC, 0, 0, _wx.wxCOPY);
        oPatchDC:SelectObject(_wx.wxNullBitmap); oPatchDC:delete(); oPatch:delete(); oFill:delete();
    end

    --[[!
    @fqxn Custom.PyramidCanvas.create.render
    @desc Caches a supersampled structural view. Side panels blend far to near;
        bright connecting edges and independently colored translucent nodes follow.
    !]]
    local function fRender(nWidth, nHeight, tGeometry)
        local nScale = 2;
        local oBitmap = _wx.wxBitmap(nWidth * nScale, nHeight * nScale); local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
        local oBackground = _wx.wxColour(tBackground.R, tBackground.G, tBackground.B); local oBrush = _wx.wxBrush(oBackground);
        oDC:SetBackground(oBrush); oDC:Clear();
        local tSorted = {}; for _, tFace in ipairs(tGeometry.Faces) do tSorted[#tSorted + 1] = tFace; end
        table.sort(tSorted, function(tA, tB) return tA.Z < tB.Z; end);
        if (bFacesVisible) then for _, tFace in ipairs(tSorted) do
            local tPolygon, nLeft, nTop, nRight, nBottom = {}, math.huge, math.huge, -math.huge, -math.huge;
            for _, nVertex in ipairs(tFace.Vertices) do
                local tPoint = tGeometry.Vertices[nVertex]; local nX, nY = math.floor(tPoint.X * nScale), math.floor(tPoint.Y * nScale);
                tPolygon[#tPolygon + 1] = _wx.wxPoint(nX, nY);
                nLeft, nTop, nRight, nBottom = math.min(nLeft, nX), math.min(nTop, nY), math.max(nRight, nX), math.max(nBottom, nY);
            end
            fBlend(oDC, tFace.Color, nLeft, nTop, nRight + 1, nBottom + 1, function(oMaskDC) oMaskDC:DrawPolygon(tPolygon); end);
            for _, oPoint in ipairs(tPolygon) do oPoint:delete(); end
        end end
        for _, tEdge in ipairs(_tEdges) do
            local tA, tB = tGeometry.Vertices[tEdge[1]], tGeometry.Vertices[tEdge[2]];
            local oColor = _wx.wxColour(math.floor((tA.Color.R + tB.Color.R) / 2), math.floor((tA.Color.G + tB.Color.G) / 2), math.floor((tA.Color.B + tB.Color.B) / 2));
            local oPen = _wx.wxPen(oColor, 2 * nScale, _wx.wxPENSTYLE_SOLID); oDC:SetPen(oPen);
            oDC:DrawLine(tA.X * nScale, tA.Y * nScale, tB.X * nScale, tB.Y * nScale); oPen:delete(); oColor:delete();
        end
        for _, tPoint in ipairs(tGeometry.Vertices) do
            local nX, nY, nRadius = math.floor(tPoint.X * nScale), math.floor(tPoint.Y * nScale), 7 * nScale;
            fBlend(oDC, tPoint.Color, nX - nRadius, nY - nRadius, nX + nRadius + 1, nY + nRadius + 1,
                function(oMaskDC) oMaskDC:DrawCircle(nX, nY, nRadius); end);
        end
        oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBrush:delete(); oBackground:delete();
        local oImage = oBitmap:ConvertToImage(); oBitmap:delete(); local oScaled = oImage:Scale(nWidth, nHeight, _wx.wxIMAGE_QUALITY_HIGH); oImage:delete();
        if (tCache) then tCache.Bitmap:delete(); end
        tCache = {Width = nWidth, Height = nHeight, Geometry = tGeometry, Bitmap = _wx.wxBitmap(oScaled)}; oScaled:delete();
    end

    --[[!
    @fqxn Custom.PyramidCanvas.draw
    @desc Draws cached geometry and native-resolution labels. Side names use
        separate left/right callouts; vertex names sit near each colored node.
        Label hit rectangles are retained for itemClicked event delivery.
    !]]
    function oCanvas.draw(oDC, nWidth, nHeight)
        if (bDisposed or nWidth < 1 or nHeight < 1) then return; end
        nWidth, nHeight = math.floor(nWidth), math.floor(nHeight);
        if (not tCache or tCache.Width ~= nWidth or tCache.Height ~= nHeight) then fRender(nWidth, nHeight, oCanvas.getGeometry(nWidth, nHeight)); end
        oDC:DrawBitmap(tCache.Bitmap, 0, 0, false); oDC:SetFont(oFont); oDC:SetBackgroundMode(_wx.wxTRANSPARENT); tLabels = {};
        --[[!
        @fqxn Custom.PyramidCanvas.draw.label
        @desc Draws one colored label with a dark backing and a leader to its
            actual 3D anchor. Records the visible label for mouse selection.
        !]]
        local function fLabel(tItem, sKind, nIndex, nX, nY)
            if (tItem.Name == "") then return; end
            local nTextW, nTextH = oDC:GetTextExtent(tItem.Name);
            nX, nY = math.max(4, math.min(nWidth - nTextW - 8, nX)), math.max(4, math.min(nHeight - nTextH - 8, nY));
            local oColor = _wx.wxColour(tItem.Color.R, tItem.Color.G, tItem.Color.B);
            local oPen = _wx.wxPen(oColor, 1, _wx.wxPENSTYLE_SOLID); oDC:SetPen(oPen);
            oDC:DrawLine(tItem.X, tItem.Y, math.max(nX, math.min(nX + nTextW, tItem.X)), nY + nTextH / 2);
            local oBack = _wx.wxColour(tBackground.R, tBackground.G, tBackground.B); local oBrush = _wx.wxBrush(oBack);
            oDC:SetPen(_wx.wxTRANSPARENT_PEN); oDC:SetBrush(oBrush); oDC:DrawRectangle(nX - 3, nY - 2, nTextW + 6, nTextH + 4);
            oDC:SetTextForeground(oColor); oDC:DrawText(tItem.Name, nX, nY);
            tLabels[#tLabels + 1] = {Kind = sKind, Index = nIndex, Name = tItem.Name, Color = copy(tItem.Color),
                X = nX - 3, Y = nY - 2, Width = nTextW + 6, Height = nTextH + 4};
            oPen:delete(); oColor:delete(); oBrush:delete(); oBack:delete();
        end
        local tLeft, tRight = {}, {};
        for _, tFace in ipairs(tCache.Geometry.Faces) do
            local tSide = tFace.X < nWidth / 2 and tLeft or tRight; tSide[#tSide + 1] = tFace;
        end
        for _, tSide in ipairs({tLeft, tRight}) do
            table.sort(tSide, function(tA, tB) return tA.Y < tB.Y; end);
            local nPrevious = 16;
            for _, tFace in ipairs(tSide) do
                local nTextW, nTextH = oDC:GetTextExtent(tFace.Name);
                local nY = math.max(nPrevious, tFace.Y - nTextH / 2); nPrevious = nY + nTextH + 16;
                fLabel(tFace, "face", tFace.Index, tSide == tLeft and 20 or nWidth - nTextW - 20, nY);
            end
        end
        for nIndex, tPoint in ipairs(tCache.Geometry.Vertices) do
            local nTextW, nTextH = oDC:GetTextExtent(tPoint.Name);
            fLabel(tPoint, "vertex", nIndex, tPoint.X < nWidth / 2 and tPoint.X - nTextW - 15 or tPoint.X + 15,
                tPoint.Y < nHeight / 2 and tPoint.Y - nTextH - 14 or tPoint.Y + 14);
        end
    end

    --[[!
    @fqxn Custom.PyramidCanvas.layout
    @desc Applies native bounds; paints rebuild their cached geometry on size change.
    !]]
    function oCanvas.layout(nX, nY, nWidth, nHeight)
        assert(not bDisposed, "PyramidCanvas is disposed."); oControl:SetSize(nX, nY, nWidth, nHeight); return oCanvas;
    end

    --[[!
    @fqxn Custom.PyramidCanvas.create.cancel
    @desc Clears a drag and releases capture on focus loss, cancellation or disposal.
    !]]
    local function fCancel()
        tDrag = nil; if (oControl:HasCapture()) then oControl:ReleaseMouse(); end
    end

    --[[!
    @fqxn Custom.PyramidCanvas.destroy
    @desc Releases owned raster/font resources once. Native window lifetime
        remains with its parent; later paints are harmless and mutations reject.
    !]]
    function oCanvas.destroy()
        if (bDisposed) then return; end
        fCancel(); bDisposed = true;
        if (tCache) then tCache.Bitmap:delete(); tCache = nil; end
        if (bOwnFont) then oFont:delete(); end
        tListeners, tLabels = {}, {};
    end

    oControl:Connect(_wx.wxEVT_PAINT, function()
        local oDC = _wx.wxAutoBufferedPaintDC(oControl); oCanvas.draw(oDC, oControl:GetClientSizeWH()); oDC:delete();
    end);
    oControl:Connect(_wx.wxEVT_SIZE, function(oEvent) if (not bDisposed) then oControl:Refresh(false); end; oEvent:Skip(); end);
    oControl:Connect(_wx.wxEVT_LEFT_DOWN, function(oEvent)
        if (bDisposed) then return; end
        oControl:SetFocus(); tDrag = {X = oEvent:GetX(), Y = oEvent:GetY(), Rotation = copy(tRotation), Moved = false};
        if (not oControl:HasCapture()) then oControl:CaptureMouse(); end
    end);
    oControl:Connect(_wx.wxEVT_MOTION, function(oEvent)
        if (bDisposed or not tDrag) then return; end
        local nDX, nDY = oEvent:GetX() - tDrag.X, oEvent:GetY() - tDrag.Y;
        if (math.abs(nDX) + math.abs(nDY) > 3) then tDrag.Moved = true; end
        if (tDrag.Moved) then oCanvas.setRotation({Yaw = tDrag.Rotation.Yaw + nDX * 0.45,
            Pitch = tDrag.Rotation.Pitch + nDY * 0.45, Roll = tDrag.Rotation.Roll}, true); end
    end);
    oControl:Connect(_wx.wxEVT_LEFT_UP, function(oEvent)
        if (bDisposed or not tDrag) then return; end
        local bClick = not tDrag.Moved; fCancel();
        if (bClick) then
            local nX, nY = oEvent:GetX(), oEvent:GetY(); fEmit("leftClick", {X = nX, Y = nY});
            for nIndex = #tLabels, 1, -1 do
                local tLabel = tLabels[nIndex];
                if (nX >= tLabel.X and nX < tLabel.X + tLabel.Width and nY >= tLabel.Y and nY < tLabel.Y + tLabel.Height) then
                    fEmit("itemClicked", {Kind = tLabel.Kind, Index = tLabel.Index, Name = tLabel.Name, Color = tLabel.Color}); break;
                end
            end
        end
    end);
    oControl:Connect(_wx.wxEVT_RIGHT_UP, function(oEvent) if (not bDisposed) then fEmit("rightClick", {X = oEvent:GetX(), Y = oEvent:GetY()}); end end);
    oControl:Connect(_wx.wxEVT_LEFT_DCLICK, function() if (not bDisposed) then fCancel(); oCanvas.resetView(true); end end);
    oControl:Connect(_wx.wxEVT_MOUSEWHEEL, function(oEvent)
        if (bDisposed) then return; end
        local nDelta = oEvent:GetWheelDelta(); if (nDelta ~= 0) then oCanvas.setZoom(nZoom * 1.12 ^ (oEvent:GetWheelRotation() / nDelta), true); end
    end);
    oControl:Connect(_wx.wxEVT_KEY_DOWN, function(oEvent)
        if (bDisposed) then return; end
        local nKey = oEvent:GetKeyCode(); local tNext = copy(tRotation);
        if (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_RIGHT) then tNext.Yaw = tNext.Yaw + (nKey == _wx.WXK_LEFT and -5 or 5); oCanvas.setRotation(tNext, true);
        elseif (nKey == _wx.WXK_UP or nKey == _wx.WXK_DOWN) then tNext.Pitch = tNext.Pitch + (nKey == _wx.WXK_UP and -5 or 5); oCanvas.setRotation(tNext, true);
        elseif (nKey == _wx.WXK_ADD or nKey == 43 or nKey == 61) then oCanvas.setZoom(nZoom * 1.12, true);
        elseif (nKey == _wx.WXK_SUBTRACT or nKey == 45) then oCanvas.setZoom(nZoom / 1.12, true);
        elseif (nKey == _wx.WXK_HOME) then fCancel(); oCanvas.resetView(true);
        elseif (nKey == _wx.WXK_ESCAPE) then fCancel(); else oEvent:Skip(); end
    end);
    oControl:Connect(_wx.wxEVT_KILL_FOCUS, function(oEvent) fCancel(); oEvent:Skip(); end);
    oControl:Connect(_wx.wxEVT_MOUSE_CAPTURE_LOST, function() tDrag = nil; end);
    oControl:Connect(_wx.wxEVT_ENTER_WINDOW, function(oEvent) if (not bDisposed) then fEmit("enter"); end; oEvent:Skip(); end);
    oControl:Connect(_wx.wxEVT_LEAVE_WINDOW, function(oEvent) if (not bDisposed) then fEmit("leave"); end; oEvent:Skip(); end);
    local nControlId = oControl:GetId();
    oControl:Connect(_wx.wxEVT_DESTROY, function(oEvent) if (oEvent:GetId() == nControlId) then oCanvas.destroy(); end; oEvent:Skip(); end);
    return oCanvas;
end

return PyramidCanvas;
