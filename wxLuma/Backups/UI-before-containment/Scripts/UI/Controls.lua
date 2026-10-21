--[[!
@fqxn wxLuma.UI.Controls
@desc Common-control compatibility facade. Individual widget implementations are
      direct UI modules; each create call returns independent instance state.
!]]
local Controls = {};
Controls.loadSkin   = require("UI.Core.ControlSkin").load;
Controls.radioGroup = require("UI.Widgets.Radio").group;
Controls.checkbox   = require("UI.Widgets.Checkbox").create;
Controls.radio      = require("UI.Widgets.Radio").create;
Controls.slider     = require("UI.Widgets.Slider").create;
Controls.spinner    = require("UI.Widgets.Spinner").create;
Controls.button     = require("UI.Widgets.PushButton").create;
Controls.scrollbar  = require("UI.Widgets.Scrollbar").create;
Controls.list       = require("UI.Widgets.List").create;
Controls.dropdown   = require("UI.Widgets.Dropdown").create;
Controls.textfield  = require("UI.Widgets.TextField").create;
Controls.progress   = require("UI.Widgets.Progress").create;
Controls.tabs       = require("UI.Containers.Tabs").create;
Controls.panel      = require("UI.Containers.Panel").create;
Controls.tooltip    = require("UI.Widgets.Tooltip").create;
Controls.label           = require("UI.Widgets.Label").create;
Controls.image           = require("UI.Widgets.Image").create;
Controls.scrollContainer = require("UI.Containers.ScrollContainer").create;
Controls.tree            = require("UI.Widgets.Tree").create;
Controls.table           = require("UI.Widgets.Table").create;
Controls.splitContainer  = require("UI.Containers.SplitContainer").create;
Controls.listEx          = require("UI.Widgets.ListEx").create;
return Controls;
