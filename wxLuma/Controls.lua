--[[!
@fqxn wxLuma.UI.Controls
@desc Common-control compatibility facade. Individual widget implementations are
      direct UI modules; each create call returns independent instance state.
!]]
local Controls = {};
Controls.loadSkin   = require("wxLuma.Core.ControlSkin").load;
Controls.radioGroup = require("wxLuma.Widgets.Radio").group;
Controls.checkbox   = require("wxLuma.Widgets.Checkbox").create;
Controls.radio      = require("wxLuma.Widgets.Radio").create;
Controls.slider     = require("wxLuma.Widgets.Slider").create;
Controls.spinner    = require("wxLuma.Widgets.Spinner").create;
Controls.button     = require("wxLuma.Widgets.PushButton").create;
Controls.scrollbar  = require("wxLuma.Widgets.Scrollbar").create;
Controls.list       = require("wxLuma.Widgets.List").create;
Controls.dropdown   = require("wxLuma.Widgets.Dropdown").create;
Controls.textfield  = require("wxLuma.Widgets.TextField").create;
Controls.progress   = require("wxLuma.Widgets.Progress").create;
Controls.circularProgress = require("wxLuma.Widgets.CircularProgress").create;
Controls.globeProgress    = require("wxLuma.Widgets.GlobeProgress").create;
Controls.radialProgress   = require("wxLuma.Widgets.RadialProgress").create;
Controls.irisProgress     = require("wxLuma.Widgets.IrisProgress").create;
Controls.tabs       = require("wxLuma.Containers.Tabs").create;
Controls.panel      = require("wxLuma.Containers.Panel").create;
Controls.tooltip    = require("wxLuma.Widgets.Tooltip").create;
Controls.label           = require("wxLuma.Widgets.Label").create;
Controls.image           = require("wxLuma.Widgets.Image").create;
Controls.scrollContainer = require("wxLuma.Containers.ScrollContainer").create;
Controls.tree            = require("wxLuma.Widgets.Tree").create;
Controls.table           = require("wxLuma.Widgets.Table").create;
Controls.splitContainer  = require("wxLuma.Containers.SplitContainer").create;
Controls.listEx          = require("wxLuma.Widgets.ListEx").create;
Controls.setDefaultContainmentOverflow = require("wxLuma.Core.ControlContainment").setDefaultOverflow;
Controls.getDefaultContainmentOverflow = require("wxLuma.Core.ControlContainment").getDefaultOverflow;
Controls.contextMenu = require("wxLuma.Widgets.ContextMenu").create;
Controls.radialMenu  = require("wxLuma.Widgets.RadialMenu").create;
Controls.toggleButton = require("wxLuma.Widgets.ToggleButton").create;
Controls.numericField = require("wxLuma.Widgets.NumericField").create;
Controls.dialog       = require("wxLuma.Containers.Dialog").create;
Controls.toolbar     = require("wxLuma.Widgets.Toolbar").create;
Controls.statusBar   = require("wxLuma.Widgets.StatusBar").create;
Controls.colorPicker = require("wxLuma.Widgets.ColorPicker").create;
Controls.treeEx = require("wxLuma.Widgets.TreeEx").create;
Controls.imageButton = require("wxLuma.Widgets.ImageButton").create;
return Controls;
