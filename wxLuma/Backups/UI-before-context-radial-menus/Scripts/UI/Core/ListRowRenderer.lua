local _wx             = require("wx");
local _finite         = require("UI.Core.ControlNumeric").finite;
local ListRowRenderer = {};

--[[!
@fqxn wxLuma.UI.ListRowRenderer.create
@desc Builds private typed-row policy for List. Columns are copied at creation;
    only visible rows render. Owns at most 64 scaled thumbnail bitmaps, never one
    native child control per cell. Missing/corrupt images draw a placeholder.
@param table tDefinitions Array of Key/Type/Width/Weight/Align/Format definitions.
@param table oSkin The shared skin; it remains owned by the caller.
@ret table tRenderer Private validation, snapshot, text, drawing and disposal helpers.
!]]
function ListRowRenderer.create(tDefinitions, oSkin)
    assert(type(tDefinitions) == "table" and #tDefinitions > 0, "List Columns must be a nonempty array.");
    local tColumns, tCache, tOrder = {}, {}, {};

    for nIndex, tDefinition in ipairs(tDefinitions) do
        assert(type(tDefinition) == "table", "Invalid list column.");
        local vKey = tDefinition.Key;
        local sType = tDefinition.Type or "text";
        assert((type(vKey) == "string" and vKey ~= "")
            or (_finite(vKey) and vKey >= 1 and vKey % 1 == 0), "Column Key must identify a row field.");
        assert(sType == "text" or sType == "image" or sType == "number" or sType == "boolean",
            "Unsupported list column Type.");
        local nWidth = tDefinition.Width;
        local nWeight = tDefinition.Weight or 1;
        assert(nWidth == nil or (_finite(nWidth) and nWidth > 0 and nWidth % 1 == 0), "Invalid column Width.");
        assert(_finite(nWeight) and nWeight > 0, "Invalid column Weight.");
        local sAlign = tDefinition.Align or "left";
        assert(sAlign == "left" or sAlign == "center" or sAlign == "right", "Invalid column Align.");
        assert(tDefinition.Format == nil or type(tDefinition.Format) == "function", "Invalid column Format.");
        tColumns[nIndex] = {
            Key = vKey, Type = sType, Width = nWidth, Weight = nWeight,
            Align = sAlign, Format = tDefinition.Format
        };
    end

    local tRenderer = {};

    --[[!
    @fqxn wxLuma.UI.ListRowRenderer.copyItem
    @desc Validates configured cell types and copies the row structure. Nil cells
        are blank. Unconfigured application fields are shallow-copied unchanged.
    !]]
    function tRenderer.copyItem(tItem)
        assert(type(tItem) == "table", "Typed list items must be row records.");

        for _, tColumn in ipairs(tColumns) do
            local vValue = tItem[tColumn.Key];

            if (vValue ~= nil) then
                if (tColumn.Type == "image" or tColumn.Type == "text") then
                    assert(type(vValue) == "string", "Image/text cells must be strings or nil.");
                elseif (tColumn.Type == "number") then
                    assert(_finite(vValue), "Number cells must be finite numbers or nil.");
                else
                    assert(type(vValue) == "boolean", "Boolean cells must be booleans or nil.");
                end
            end
        end

        local tCopy = {};

        for vKey, vValue in pairs(tItem) do
            tCopy[vKey] = vValue;
        end

        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.ListRowRenderer.getColumns
    @desc Returns independent column definitions; mutating them cannot change layout.
    !]]
    function tRenderer.getColumns()
        local tCopy = {};

        for nIndex, tColumn in ipairs(tColumns) do
            local tDefinition = {};

            for sKey, vValue in pairs(tColumn) do
                tDefinition[sKey] = vValue;
            end

            tCopy[nIndex] = tDefinition;
        end

        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.ListRowRenderer.getColumnKey
    @desc Validates a one-based column index and returns its configured row key.
    !]]
    function tRenderer.getColumnKey(nColumn)
        assert(_finite(nColumn) and nColumn % 1 == 0 and tColumns[nColumn], "Invalid list column index.");
        return tColumns[nColumn].Key;
    end
    -- Format display text without mutating underlying typed cell values.
    local function fText(tColumn, tItem, nIndex)
        local vValue = tItem[tColumn.Key];

        if (vValue == nil) then
            return "";
        end

        if (tColumn.Format) then
            local sText = tColumn.Format(vValue, tItem, nIndex);
            assert(type(sText) == "string", "Column Format must return a string.");
            return sText;
        end

        if (tColumn.Type == "boolean") then
            return vValue and "Yes" or "No";
        end

        return tostring(vValue);
    end

    --[[!
    @fqxn wxLuma.UI.ListRowRenderer.getText
    @desc Uses the first text column, or first non-image column, for selection text
        and character search. An all-image row has an empty text representation.
    !]]
    function tRenderer.getText(tItem, nIndex)
        if (not tItem) then
            return "";
        end

        local tFallback;

        for _, tColumn in ipairs(tColumns) do
            if (tColumn.Type == "text") then
                return fText(tColumn, tItem, nIndex);
            elseif (tColumn.Type ~= "image" and not tFallback) then
                tFallback = tColumn;
            end
        end

        return tFallback and fText(tFallback, tItem, nIndex) or "";
    end

    -- Bounded FIFO thumbnails are independent of row count. Decode sources only
    -- on a visible cache miss, scale once, then release the full-size wxImage.
    local function fThumbnail(pImage, nWidth, nHeight)
        local sCacheKey = pImage.."\0"..nWidth.."x"..nHeight;
        local tEntry = tCache[sCacheKey];

        if (tEntry and tEntry.Width == nWidth and tEntry.Height == nHeight) then
            return tEntry;
        end

        if (tEntry) then
            if (tEntry.Bitmap) then
                tEntry.Bitmap:delete();
            end
        else
            if (#tOrder == 64) then
                local pOld = table.remove(tOrder, 1);
                local tOld = tCache[pOld];

                if (tOld.Bitmap) then
                    tOld.Bitmap:delete();
                end

                tCache[pOld] = nil;
            end

            tOrder[#tOrder + 1] = sCacheKey;
        end

        tEntry = {Width = nWidth, Height = nHeight};
        tCache[sCacheKey] = tEntry;
        local hFile = io.open(pImage, "rb");

        if (not hFile) then
            return tEntry;
        end

        hFile:close();
        -- Paint must not open a native error dialog for a corrupt image.
        local oLog = _wx.wxLogNull();
        local oImage = _wx.wxImage(pImage, _wx.wxBITMAP_TYPE_ANY);
        oLog:delete();

        if (oImage:IsOk()) then
            local nScale = math.min(nWidth / oImage:GetWidth(), nHeight / oImage:GetHeight());
            local nDrawWidth = math.max(1, math.floor(oImage:GetWidth() * nScale + 0.5));
            local nDrawHeight = math.max(1, math.floor(oImage:GetHeight() * nScale + 0.5));
            local oScaled = oImage:Scale(nDrawWidth, nDrawHeight, _wx.wxIMAGE_QUALITY_HIGH);
            tEntry.Bitmap = _wx.wxBitmap(oScaled);
            tEntry.DrawWidth, tEntry.DrawHeight = nDrawWidth, nDrawHeight;
            oScaled:delete();
        end

        oImage:delete();
        return tEntry;
    end

    --[[!
    @fqxn wxLuma.UI.ListRowRenderer.draw
    @desc Draws typed cells over List's selection/hover background. Fixed Width
        columns use pixels; remaining columns share free space by Weight. Overflow
        clips at the list edge. Each cell has its own nested clipping region.
    !]]
    function tRenderer.draw(oDC, tItem, nIndex, nX, nY, nWidth, nHeight, bEnabled)
        local nFixed, nWeight = 0, 0;

        for _, tColumn in ipairs(tColumns) do
            if (tColumn.Width) then
                nFixed = nFixed + tColumn.Width;
            else
                nWeight = nWeight + tColumn.Weight;
            end
        end

        local nFree = math.max(0, nWidth - nFixed);
        local nUsedWeight, nUsedFree = 0, 0;

        for _, tColumn in ipairs(tColumns) do
            local nCellWidth = tColumn.Width;

            if (not nCellWidth) then
                nUsedWeight = nUsedWeight + tColumn.Weight;
                local nEnd = math.floor(nFree * nUsedWeight / nWeight);
                nCellWidth = nEnd - nUsedFree;
                nUsedFree = nEnd;
            end

            local nContentWidth = math.max(0, nCellWidth - 12);

            if (nContentWidth > 0) then
                local oClipper = _wx.wxDCClipper(oDC, _wx.wxRect(nX + 6, nY + 2, nContentWidth, nHeight - 4));
                local vValue = tItem[tColumn.Key];

                if (tColumn.Type == "image") then
                    if (vValue and vValue ~= "") then
                        local tImage = fThumbnail(vValue, nContentWidth, nHeight - 8);

                        if (tImage.Bitmap) then
                            oDC:DrawBitmap(tImage.Bitmap, nX + 6 + math.floor((nContentWidth - tImage.DrawWidth) / 2),
                                nY + math.floor((nHeight - tImage.DrawHeight) / 2), true);
                        else
                            oSkin.text(oDC, "?", nX + 6, nY + (nHeight - 18) / 2, bEnabled);
                        end
                    end
                else
                    local sText = fText(tColumn, tItem, nIndex);
                    oDC:SetFont(oSkin.Font);
                    local nTextWidth = oDC:GetTextExtent(sText);
                    local nTextX = nX + 6;

                    if (tColumn.Align == "center") then
                        nTextX = nTextX + math.floor((nContentWidth - nTextWidth) / 2);
                    elseif (tColumn.Align == "right") then
                        nTextX = nTextX + nContentWidth - nTextWidth;
                    end

                    oSkin.text(oDC, sText, nTextX, nY + (nHeight - 18) / 2, bEnabled);
                end

                oClipper:delete();
            end

            nX = nX + nCellWidth;
        end
    end

    --[[!
    @fqxn wxLuma.UI.ListRowRenderer.clear
    @desc Releases all cached native thumbnails on replacement or disposal.
    !]]
    function tRenderer.clear()
        for _, tEntry in pairs(tCache) do
            if (tEntry.Bitmap) then
                tEntry.Bitmap:delete();
            end
        end

        tCache, tOrder = {}, {};
    end

    return tRenderer;
end

return ListRowRenderer;