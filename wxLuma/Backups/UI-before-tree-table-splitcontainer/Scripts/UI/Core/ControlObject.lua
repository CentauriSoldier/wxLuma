--[[!
@fqxn wxLuma.UI.ControlObject
@desc Shared actual/decoy/metatable construction for UI instances. Module tables
    and temporary data remain ordinary tables. Component fields stay writable
    to preserve existing widget extension hooks and application behavior.
!]]
local ControlObject = {};

--[[!
@fqxn wxLuma.UI.ControlObject.create
@desc Creates an empty public decoy over the supplied actual storage. Reads and
    writes reach that storage through the metatable; methods retain their normal
    dot-call signatures. Each call creates an independent decoy and metatable.
@param table tActual The component's fields and methods.
@param string sType The descriptive object name used to protect its metatable.
@ret table oObject The public object. Iteration exposes its stored fields.
!]]
function ControlObject.create(tActual, sType)
    assert(type(tActual) == "table", "Object storage must be a table.");
    assert(type(sType) == "string", "Object type must be a string.");

    local tDecoy = {};
    local tMeta  = {

        -- Read optional hooks as nil rather than rejecting absent properties.
        __index = function(tObject, vKey)
            return tActual[vKey];
        end,

        -- Keep all regular assignments out of the public decoy itself.
        __newindex = function(tObject, vKey, vValue)
            tActual[vKey] = vValue;
        end,

        -- Preserve pairs-based inspection of the former component tables.
        __pairs = function()
            return next, tActual, nil;
        end,

        __metatable = sType,
    };

    return setmetatable(tDecoy, tMeta);
end

return ControlObject;
