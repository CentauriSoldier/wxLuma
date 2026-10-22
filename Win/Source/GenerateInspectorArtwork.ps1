# Rebuild the inspector control artwork using the existing wxLuma palette.
# All generated glyphs are transparent PNGs and remain individually replaceable.
param([string]$ArtworkPath = (Join-Path $PSScriptRoot '../../wxLuma/Images/Controls'))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskArtwork = (Resolve-Path -LiteralPath $ArtworkPath).Path

function Copy-Material([string]$Source, [string]$Target) {
    Copy-Item -LiteralPath (Join-Path $taskArtwork ("Control $Source.png")) -Destination (Join-Path $taskArtwork ("Control $Target.png"))
}

function New-Material([string]$Name, [System.Drawing.Color]$Color) {
    $taskBitmap = [Drawing.Bitmap]::new(1, 1)
    try {
        $taskBitmap.SetPixel(0, 0, $Color)
        $taskBitmap.Save((Join-Path $taskArtwork ("Control $Name.png")), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $taskBitmap.Dispose() }
}

function New-Glyph([string]$Name, [string]$Kind, [string]$State) {
    $taskBitmap = [Drawing.Bitmap]::new(24, 24)
    $taskGraphics = [Drawing.Graphics]::FromImage($taskBitmap)
    $taskColor = switch ($State) {
        'Disabled' { [Drawing.Color]::FromArgb(114, 126, 139) }
        'Hover' { [Drawing.Color]::FromArgb(164, 226, 242) }
        'Pressed' { [Drawing.Color]::FromArgb(105, 190, 214) }
        default { [Drawing.Color]::FromArgb(212, 224, 232) }
    }
    $taskPen = [Drawing.Pen]::new($taskColor, 2)
    try {
        $taskGraphics.Clear([Drawing.Color]::Transparent)
        $taskGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $taskPen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $taskPen.EndCap = [Drawing.Drawing2D.LineCap]::Round
        switch ($Kind) {
            'Calendar' {
                $taskGraphics.DrawRectangle($taskPen, 4, 5, 16, 16)
                $taskGraphics.DrawLine($taskPen, 4, 10, 20, 10)
                $taskGraphics.DrawLine($taskPen, 8, 3, 8, 7)
                $taskGraphics.DrawLine($taskPen, 16, 3, 16, 7)
                $taskGraphics.DrawRectangle($taskPen, 8, 14, 3, 3)
            }
            'Next' {
                $taskGraphics.DrawLines($taskPen, [Drawing.Point[]]@([Drawing.Point]::new(8, 5), [Drawing.Point]::new(16, 12), [Drawing.Point]::new(8, 19)))
            }
            'Back' {
                $taskGraphics.DrawLines($taskPen, [Drawing.Point[]]@([Drawing.Point]::new(16, 5), [Drawing.Point]::new(8, 12), [Drawing.Point]::new(16, 19)))
            }
            'Float' {
                $taskGraphics.DrawRectangle($taskPen, 4, 8, 12, 12)
                $taskGraphics.DrawRectangle($taskPen, 9, 3, 12, 12)
            }
            'Grip' {
                foreach ($taskX in @(8, 14)) { foreach ($taskY in @(5, 11, 17)) { $taskGraphics.DrawEllipse($taskPen, $taskX, $taskY, 1, 1) } }
            }
            'Info' {
                $taskGraphics.DrawEllipse($taskPen, 3, 3, 18, 18)
                $taskGraphics.DrawLine($taskPen, 12, 11, 12, 17)
                $taskGraphics.DrawEllipse($taskPen, 11, 7, 1, 1)
            }
            'Check' {
                $taskGraphics.DrawLines($taskPen, [Drawing.Point[]]@([Drawing.Point]::new(4, 12), [Drawing.Point]::new(10, 18), [Drawing.Point]::new(21, 5)))
            }
            'Warning' {
                $taskGraphics.DrawPolygon($taskPen, [Drawing.Point[]]@([Drawing.Point]::new(12, 3), [Drawing.Point]::new(22, 21), [Drawing.Point]::new(2, 21)))
                $taskGraphics.DrawLine($taskPen, 12, 9, 12, 14)
                $taskGraphics.DrawEllipse($taskPen, 11, 17, 1, 1)
            }
            'Magnifier' {
                $taskGraphics.DrawEllipse($taskPen, 4, 3, 12, 12)
                $taskGraphics.DrawLine($taskPen, 14, 14, 21, 21)
            }
            'Clear' {
                $taskGraphics.DrawLine($taskPen, 7, 7, 17, 17)
                $taskGraphics.DrawLine($taskPen, 17, 7, 7, 17)
            }
            'Arrow' {
                $taskGraphics.DrawLine($taskPen, 6, 9, 12, 15)
                $taskGraphics.DrawLine($taskPen, 12, 15, 18, 9)
            }
            'Folder' {
                $taskGraphics.DrawLines($taskPen, [Drawing.Point[]]@(
                    [Drawing.Point]::new(3, 7), [Drawing.Point]::new(9, 7),
                    [Drawing.Point]::new(11, 10), [Drawing.Point]::new(21, 10),
                    [Drawing.Point]::new(21, 19), [Drawing.Point]::new(3, 19), [Drawing.Point]::new(3, 7)))
            }
            'File' {
                $taskGraphics.DrawLines($taskPen, [Drawing.Point[]]@(
                    [Drawing.Point]::new(6, 3), [Drawing.Point]::new(14, 3),
                    [Drawing.Point]::new(19, 8), [Drawing.Point]::new(19, 21),
                    [Drawing.Point]::new(6, 21), [Drawing.Point]::new(6, 3)))
                $taskGraphics.DrawLine($taskPen, 14, 3, 14, 8)
                $taskGraphics.DrawLine($taskPen, 14, 8, 19, 8)
                $taskGraphics.DrawLine($taskPen, 9, 12, 16, 12)
                $taskGraphics.DrawLine($taskPen, 9, 16, 16, 16)
            }
        }
        $taskBitmap.Save((Join-Path $taskArtwork ("Control $Name $State.png")), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $taskPen.Dispose(); $taskGraphics.Dispose(); $taskBitmap.Dispose() }
}

function New-Focus([string]$Name) {
    $taskBitmap = [Drawing.Bitmap]::new(180, 40)
    $taskGraphics = [Drawing.Graphics]::FromImage($taskBitmap)
    $taskPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(140, 204, 224))
    try {
        $taskGraphics.Clear([Drawing.Color]::Transparent)
        $taskGraphics.DrawRectangle($taskPen, 0, 0, 179, 39)
        $taskBitmap.Save((Join-Path $taskArtwork ("Control $Name Focus.png")), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $taskPen.Dispose(); $taskGraphics.Dispose(); $taskBitmap.Dispose() }
}

$taskStates = @('Normal', 'Hover', 'Pressed', 'Disabled')
foreach ($taskFamily in @('Search Field', 'Combo Box', 'File Picker', 'Property Grid Editor')) {
    foreach ($taskState in $taskStates) {
        Copy-Material "Numeric Field $taskState" "$taskFamily Surface $taskState"
    }
    Copy-Material 'Toolbar Text Normal' "$taskFamily Text Normal"
    Copy-Material 'Toolbar Text Disabled' "$taskFamily Text Disabled"
    New-Material "$taskFamily Editor Normal" ([Drawing.Color]::FromArgb(24, 29, 36))
    New-Focus $taskFamily
}
foreach ($taskState in $taskStates) {
    New-Glyph 'Search Field Magnifier' 'Magnifier' $taskState
    New-Glyph 'Search Field Clear' 'Clear' $taskState
    New-Glyph 'Combo Box Arrow' 'Arrow' $taskState
    New-Glyph 'File Picker Browse' 'Folder' $taskState
    New-Glyph 'File Picker Folder' 'Folder' $taskState
    New-Glyph 'File Picker File' 'File' $taskState
    New-Glyph 'Property Grid Arrow' 'Arrow' $taskState
    Copy-Material "Numeric Field $taskState" "Property Grid Editor $taskState"
    Copy-Material "Toolbar Item $taskState" "Collapsible Panel Header $taskState"
    Copy-Material "TreeEx Branch Open $taskState" "Collapsible Panel Open $taskState"
    Copy-Material "TreeEx Branch Closed $taskState" "Collapsible Panel Closed $taskState"
}
foreach ($taskFamily in @('Property Grid', 'Collapsible Panel', 'Accordion')) {
    foreach ($taskState in @('Normal', 'Disabled')) {
        New-Material "$taskFamily Surface $taskState" ([Drawing.Color]::FromArgb(24, 29, 36))
        Copy-Material "Toolbar Text $taskState" "$taskFamily Text $taskState"
    }
    New-Focus $taskFamily
}
Copy-Material 'Toolbar Item Normal' 'Property Grid Row'
Copy-Material 'Toolbar Item Hover' 'Property Grid Category'
Copy-Material 'Toolbar Separator' 'Property Grid Separator'
New-Material 'Property Grid Editor Fill' ([Drawing.Color]::FromArgb(24, 29, 36))

# MenuBar composes Toolbar; each material still has its own menu-bar skin name.
Get-ChildItem -LiteralPath $taskArtwork -Filter 'Control Toolbar *.png' | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $taskArtwork ($_.Name.Replace('Control Toolbar ', 'Control Menu Bar ')))
}
Write-Output 'Inspector control artwork generated.'

# Additional controls share named surfaces while every icon remains replaceable.
foreach ($taskFamily in @('Multiline Text', 'Range Slider', 'Notification', 'Date Time Picker', 'Breadcrumb', 'Dockable Panel', 'Knob', 'Switch')) {
    foreach ($taskState in $taskStates) { Copy-Material "Numeric Field $taskState" "$taskFamily Surface $taskState" }
    foreach ($taskState in @('Normal', 'Disabled')) { Copy-Material "Toolbar Text $taskState" "$taskFamily Text $taskState" }
    New-Material "$taskFamily Editor Normal" ([Drawing.Color]::FromArgb(24, 29, 36))
    New-Focus $taskFamily
}
foreach ($taskState in $taskStates) {
    Copy-Material "Slider Track $taskState" "Range Slider Track $taskState"
    Copy-Material "Slider Thumb $taskState" "Range Slider Thumb $taskState"
    $taskAccent = if ($taskState -eq 'Disabled') { [Drawing.Color]::FromArgb(70, 85, 98) } else { [Drawing.Color]::FromArgb(72, 151, 176) }
    New-Material "Range Slider Fill $taskState" $taskAccent
    Copy-Material "Toolbar Item $taskState" "Breadcrumb Item $taskState"
    Copy-Material "Toolbar Item $taskState" "Date Time Picker Day $taskState"
    Copy-Material "Numeric Field $taskState" "Date Time Picker Calendar $taskState"
    Copy-Material "Toolbar Item $taskState" "Dockable Panel Header $taskState"
    New-Material "Dockable Panel Content $taskState" ([Drawing.Color]::FromArgb(24, 29, 36))
    New-Glyph 'Date Time Picker Icon' 'Calendar' $taskState
    New-Glyph 'Date Time Picker Back' 'Back' $taskState
    New-Glyph 'Date Time Picker Next' 'Next' $taskState
    New-Glyph 'Breadcrumb Separator' 'Next' $taskState
    New-Glyph 'Breadcrumb Back' 'Back' $taskState
    New-Glyph 'Dockable Panel Grip' 'Grip' $taskState
    New-Glyph 'Dockable Panel Action' 'Float' $taskState
    New-Glyph 'Notification Close' 'Clear' $taskState
    foreach ($taskSeverity in @('info', 'success', 'warning', 'error')) {
        Copy-Material "Numeric Field $taskState" "Notification Surface $taskSeverity $taskState"
        $taskGlyph = switch ($taskSeverity) { 'success' { 'Check' } 'warning' { 'Warning' } 'error' { 'Clear' } default { 'Info' } }
        New-Glyph "Notification Icon $taskSeverity" $taskGlyph $taskState
    }
    $taskNeedle = switch ($taskState) {
        'Disabled' { [Drawing.Color]::FromArgb(98, 114, 126) }
        'Hover' { [Drawing.Color]::FromArgb(170, 235, 247) }
        'Pressed' { [Drawing.Color]::FromArgb(87, 184, 210) }
        default { [Drawing.Color]::FromArgb(130, 213, 235) }
    }
    # Needle artwork is a full-face transparent square, pointing right from
    # its center. Geometry and shading belong to the skin, not drawing code.
    $taskNeedleBitmap = [Drawing.Bitmap]::new(384, 384)
    $taskNeedleGraphics = [Drawing.Graphics]::FromImage($taskNeedleBitmap)
    $taskNeedlePen = [Drawing.Pen]::new($taskNeedle, 12)
    try {
        $taskNeedleGraphics.Clear([Drawing.Color]::Transparent)
        $taskNeedleGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $taskNeedlePen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $taskNeedlePen.EndCap = [Drawing.Drawing2D.LineCap]::Round
        $taskNeedleGraphics.DrawLine($taskNeedlePen, 192, 192, 322, 192)
        $taskNeedleBitmap.Save((Join-Path $taskArtwork "Control Knob Needle $taskState.png"), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $taskNeedlePen.Dispose(); $taskNeedleGraphics.Dispose(); $taskNeedleBitmap.Dispose() }
    $taskFace = [Drawing.Bitmap]::new(96, 96)
    $taskFaceGraphics = [Drawing.Graphics]::FromImage($taskFace)
    $taskFacePen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(112, 135, 153), 2)
    $taskFaceRect = [Drawing.Rectangle]::new(4, 4, 88, 88)
    $taskFaceTop = if ($taskState -eq 'Disabled') { [Drawing.Color]::FromArgb(49, 57, 66) } else { [Drawing.Color]::FromArgb(72, 89, 106) }
    $taskFaceBrush = [Drawing.Drawing2D.LinearGradientBrush]::new($taskFaceRect,
        $taskFaceTop, [Drawing.Color]::FromArgb(28, 36, 46), 70.0)
    try {
        $taskFaceGraphics.Clear([Drawing.Color]::Transparent)
        $taskFaceGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $taskFaceGraphics.FillEllipse($taskFaceBrush, $taskFaceRect)
        $taskFaceGraphics.DrawEllipse($taskFacePen, $taskFaceRect)
        $taskFace.Save((Join-Path $taskArtwork ("Control Knob Face $taskState.png")), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $taskFaceBrush.Dispose(); $taskFacePen.Dispose(); $taskFaceGraphics.Dispose(); $taskFace.Dispose() }
}
Write-Output 'Additional control artwork generated.'

# Switch variants are explicit replaceable skins; captions belong to the control.
foreach ($taskVertical in @($false, $true)) {
    foreach ($taskReverse in @($false, $true)) {
        foreach ($taskOn in @($false, $true)) {
            foreach ($taskState in $taskStates) {
                $taskBitmap = [Drawing.Bitmap]::new(112, 48)
                $taskGraphics = [Drawing.Graphics]::FromImage($taskBitmap)
                $taskEdge = [Drawing.Pen]::new([Drawing.Color]::FromArgb(101, 126, 147), 1.5)
                $taskAccent = if ($taskState -eq 'Disabled') { [Drawing.Color]::FromArgb(74, 89, 102) } elseif ($taskOn) { [Drawing.Color]::FromArgb(76, 192, 155) } else { [Drawing.Color]::FromArgb(51, 63, 77) }
                $taskTrack = [Drawing.SolidBrush]::new($taskAccent)
                $taskThumbColor = switch ($taskState) { 'Hover' { [Drawing.Color]::FromArgb(157, 201, 219) } 'Pressed' { [Drawing.Color]::FromArgb(88, 151, 180) } 'Disabled' { [Drawing.Color]::FromArgb(83, 96, 108) } default { [Drawing.Color]::FromArgb(121, 151, 174) } }
                $taskThumb = [Drawing.SolidBrush]::new($taskThumbColor)
                try {
                    $taskGraphics.Clear([Drawing.Color]::Transparent)
                    $taskGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
                    $taskGraphics.FillRectangle($taskTrack, 3, 7, 106, 34)
                    $taskGraphics.DrawRectangle($taskEdge, 3, 7, 106, 34)
                    # Source is horizontal: rotating counterclockwise maps right to up.
                    $taskOnRight = -not $taskReverse
                    $taskRight = $taskOn -eq $taskOnRight
                    $taskThumbX = if ($taskRight) { 72 } else { 6 }
                    $taskGraphics.FillRectangle($taskThumb, $taskThumbX, 9, 34, 30)
                    $taskGraphics.DrawRectangle($taskEdge, $taskThumbX, 9, 34, 30)
                    $taskGraphics.DrawLine($taskEdge, ($taskThumbX + 12), 16, ($taskThumbX + 12), 32)
                    $taskGraphics.DrawLine($taskEdge, ($taskThumbX + 20), 16, ($taskThumbX + 20), 32)
                    $taskOrientation = if ($taskVertical) { 'Vertical' } else { 'Horizontal' }
                    $taskDirection = if ($taskReverse) { 'Reversed' } else { 'Standard' }
                    $taskValue = if ($taskOn) { 'On' } else { 'Off' }
                    if ($taskVertical) { $taskBitmap.RotateFlip([Drawing.RotateFlipType]::Rotate270FlipNone) }
                    $taskBitmap.Save((Join-Path $taskArtwork "Control Switch $taskOrientation $taskDirection $taskValue $taskState.png"), [Drawing.Imaging.ImageFormat]::Png)
                } finally {
                    $taskThumb.Dispose(); $taskTrack.Dispose()
                    $taskEdge.Dispose(); $taskGraphics.Dispose(); $taskBitmap.Dispose()
                }
            }
        }
    }
}

# Neutral light masks retain alpha and shading when the LED applies its color.
foreach ($taskState in @('Normal', 'Disabled')) {
    New-Material "LED Surface $taskState" ([Drawing.Color]::FromArgb(24, 29, 36))
}
foreach ($taskLayer in @('Bezel', 'Lens', 'Glow', 'Glass')) {
    # Four-times source resolution supplies smooth coverage when filtered down.
    $taskBitmap = [Drawing.Bitmap]::new(384, 384)
    $taskGraphics = [Drawing.Graphics]::FromImage($taskBitmap)
    try {
        $taskGraphics.Clear([Drawing.Color]::Transparent)
        $taskGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $taskGraphics.ScaleTransform(4.0, 4.0)
        if ($taskLayer -eq 'Glow') {
            # Continuous radial alpha avoids visible concentric band edges.
            $taskPath = [Drawing.Drawing2D.GraphicsPath]::new()
            $taskPath.AddEllipse(1, 1, 94, 94)
            $taskBrush = [Drawing.Drawing2D.PathGradientBrush]::new($taskPath)
            try {
                $taskBrush.CenterColor = [Drawing.Color]::FromArgb(150, 255, 255, 255)
                $taskBrush.SurroundColors = [Drawing.Color[]]@([Drawing.Color]::FromArgb(0, 255, 255, 255))
                $taskGraphics.FillEllipse($taskBrush, 1, 1, 94, 94)
            } finally { $taskBrush.Dispose(); $taskPath.Dispose() }
        } elseif ($taskLayer -eq 'Glass') {
            $taskBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(85, 255, 255, 255))
            $taskPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(115, 220, 239, 250), 1.5)
            try {
                $taskGraphics.FillEllipse($taskBrush, 24, 19, 46, 19)
                $taskGraphics.DrawArc($taskPen, 17, 17, 62, 62, 205, 120)
            } finally { $taskBrush.Dispose(); $taskPen.Dispose() }
        } else {
            $taskRect = if ($taskLayer -eq 'Lens') { [Drawing.Rectangle]::new(16, 16, 64, 64) } else { [Drawing.Rectangle]::new(8, 8, 80, 80) }
            $taskTop = if ($taskLayer -eq 'Lens') { [Drawing.Color]::White } else { [Drawing.Color]::FromArgb(121, 151, 174) }
            $taskBottom = if ($taskLayer -eq 'Lens') { [Drawing.Color]::FromArgb(135, 135, 135) } else { [Drawing.Color]::FromArgb(29, 39, 50) }
            $taskBrush = [Drawing.Drawing2D.LinearGradientBrush]::new($taskRect, $taskTop, $taskBottom, 75.0)
            try { $taskGraphics.FillEllipse($taskBrush, $taskRect) } finally { $taskBrush.Dispose() }
        }
        $taskBitmap.Save((Join-Path $taskArtwork "Control LED $taskLayer.png"), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $taskGraphics.Dispose(); $taskBitmap.Dispose() }
}
Write-Output 'Switch and LED artwork generated.'

# Logs and charts use their own complete materials rather than native colors.
foreach ($taskFamily in @('Log Viewer', 'Chart')) {
    foreach ($taskState in $taskStates) { Copy-Material "Numeric Field $taskState" "$taskFamily Surface $taskState" }
    foreach ($taskState in @('Normal', 'Disabled')) { Copy-Material "Toolbar Text $taskState" "$taskFamily Text $taskState" }
    New-Focus $taskFamily
}
foreach ($taskState in @('Normal', 'Hover', 'Selected', 'Disabled', 'Alternate')) {
    $taskRowColor = switch ($taskState) {
        'Selected' { [Drawing.Color]::FromArgb(135, 60, 119, 151) }
        'Hover' { [Drawing.Color]::FromArgb(75, 67, 99, 124) }
        'Alternate' { [Drawing.Color]::FromArgb(35, 74, 89, 107) }
        default { [Drawing.Color]::Transparent }
    }
    New-Material "Log Viewer Entry $taskState" $taskRowColor
}
New-Material 'Log Viewer Text Selection' ([Drawing.Color]::FromArgb(200, 55, 129, 172))
Copy-Material 'ListEx Scroll Track' 'Log Viewer Scroll Track'
foreach ($taskState in $taskStates) { Copy-Material "ListEx Scroll Thumb $taskState" "Log Viewer Scroll Thumb $taskState" }
$taskSeverityColors = @{trace = @(145, 159, 176); debug = @(165, 180, 205); info = @(130, 213, 235);
    success = @(118, 217, 160); warning = @(240, 190, 100); error = @(241, 118, 115)}
foreach ($taskSeverity in $taskSeverityColors.Keys) {
    $taskRGB = $taskSeverityColors[$taskSeverity]
    New-Material "Log Viewer Severity $taskSeverity" ([Drawing.Color]::FromArgb($taskRGB[0], $taskRGB[1], $taskRGB[2]))
}
$taskChartColors = @(@(95, 192, 220), @(126, 204, 145), @(231, 173, 91), @(188, 142, 217),
    @(228, 121, 124), @(111, 157, 225), @(216, 190, 115), @(111, 203, 190))
foreach ($taskState in @('Normal', 'Hover', 'Pressed', 'Disabled', 'Selected')) {
    $taskDisabled = $taskState -eq 'Disabled'
    New-Material "Chart Plot $taskState" ([Drawing.Color]::FromArgb(22, 28, 36))
    New-Material "Chart Grid $taskState" ([Drawing.Color]::FromArgb(46, 59, 72))
    New-Material "Chart Axis $taskState" ([Drawing.Color]::FromArgb(103, 125, 145))
    for ($taskIndex = 0; $taskIndex -lt $taskChartColors.Count; $taskIndex++) {
        $taskRGB = $taskChartColors[$taskIndex]
        $taskFactor = if ($taskDisabled) { 0.45 } elseif ($taskState -eq 'Hover' -or $taskState -eq 'Selected') { 1.15 } else { 1.0 }
        New-Material "Chart Series $($taskIndex + 1) $taskState" ([Drawing.Color]::FromArgb(
            [int][Math]::Min(255, $taskRGB[0] * $taskFactor), [int][Math]::Min(255, $taskRGB[1] * $taskFactor), [int][Math]::Min(255, $taskRGB[2] * $taskFactor)))
    }
    $taskMarker = [Drawing.Bitmap]::new(64, 64)
    $taskGraphics = [Drawing.Graphics]::FromImage($taskMarker)
    $taskMarkerColor = [Drawing.Color]::White
    $taskBrush = [Drawing.SolidBrush]::new($taskMarkerColor)
    try {
        $taskGraphics.Clear([Drawing.Color]::Transparent)
        $taskGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $taskGraphics.FillEllipse($taskBrush, 6, 6, 52, 52)
        $taskMarker.Save((Join-Path $taskArtwork "Control Chart Marker $taskState.png"), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $taskBrush.Dispose(); $taskGraphics.Dispose(); $taskMarker.Dispose() }
    New-Material "Chart Bar $taskState" ([Drawing.Color]::White)
    Copy-Material "Chart Marker $taskState" "Chart Swatch $taskState"
}
Write-Output 'Log and chart artwork generated.'
foreach ($taskState in $taskStates) { New-Glyph 'Log Viewer Icon' 'File' $taskState }
$taskBackdrop = [Drawing.Bitmap]::new(384, 128)
$taskGraphics = [Drawing.Graphics]::FromImage($taskBackdrop)
$taskBrush = [Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.Rectangle]::new(0, 0, 384, 128),
    [Drawing.Color]::FromArgb(30, 49, 57), [Drawing.Color]::FromArgb(14, 23, 36), 35.0)
$taskPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(38, 67, 76))
try {
    $taskGraphics.FillRectangle($taskBrush, 0, 0, 384, 128)
    for ($taskX = 0; $taskX -lt 384; $taskX += 32) { $taskGraphics.DrawLine($taskPen, $taskX, 0, ($taskX + 64), 128) }
    $taskBackdrop.Save((Join-Path $taskArtwork 'Control Log Viewer Game Background.png'), [Drawing.Imaging.ImageFormat]::Png)
} finally { $taskPen.Dispose(); $taskBrush.Dispose(); $taskGraphics.Dispose(); $taskBackdrop.Dispose() }
