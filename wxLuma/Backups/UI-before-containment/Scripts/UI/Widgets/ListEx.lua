local _List = require("UI.Widgets.List");
local ListEx = {};

--[[!
@fqxn wxLuma.UI.ListEx.create
@desc Creates a typed, multi-column list with whole-row selection. Define any
    positive number of Columns at creation using Key, Type (image/text/number/
    boolean), optional Width or flexible Weight, Align and Format. Items are row
    records; nil cells are blank. Rows and cells remain mutable at runtime through
    setItems/setItem/setCell/addItem/removeItem. Selection is a one-based index,
    or zero. Setters default to silent; on/off adds pointer/key/lifecycle and
    selection/item/cell/activation notifications. Only visible rows are painted.
    Column overflow clips to the viewport; horizontal scrolling is not provided.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Columns, Items; optional RowHeight (64), Value,
    Enabled, OnChange, OnActivate and OnCancel. Format(value,row,index) returns text.
@ret table oComponent One actual/decoy/metatable ListEx instance sharing List's engine.
!]]
function ListEx.create(oParent, tOptions)
    assert(type(tOptions) == "table" and type(tOptions.Columns) == "table", "ListEx requires Columns.");
    local tCopy = {};

    for sKey, vValue in pairs(tOptions) do
        tCopy[sKey] = vValue;
    end

    tCopy.RowHeight = tOptions.RowHeight or 64;
    tCopy.Items = tOptions.Items or {};
    return _List.create(oParent, tCopy, "ListEx");
end

return ListEx;