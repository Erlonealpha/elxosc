-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@namespace elxosc
---@using elxosc
---@using elxosc.host

local dsl = require 'define.src.dsl'
local player = require 'player'
local define = require 'define'
local geometry = require 'src.foundation.geometry'
local color = require 'src.foundation.color'
local paint = require 'src.painting.paint'
local text_style = require 'src.text.text_style'
local transform = require 'src.foundation.transform'
local anchor = require 'src.foundation.anchor'
local text_paint = require 'src.painting.text_paint'

--- Explicit default scope surface; adding a package does not expand builtins.
---@return mod.host.builtins
local function collect()
    local widgets = require 'material'
    ---@class mod.host.builtins
    local out = {
        Widget = widgets.Widget,
        StatelessWidget = widgets.StatelessWidget,
        StatefulWidget = widgets.StatefulWidget,
        ProxyWidget = widgets.ProxyWidget,
        ParentDataWidget = widgets.ParentDataWidget,
        InheritedWidget = widgets.InheritedWidget,
        RenderObjectWidget = widgets.RenderObjectWidget,
        LeafRenderObjectWidget = widgets.LeafRenderObjectWidget,
        SingleChildRenderObjectWidget = widgets.SingleChildRenderObjectWidget,
        MultiChildRenderObjectWidget = widgets.MultiChildRenderObjectWidget,
        State = widgets.State,
        Key = widgets.Key,
        LocalKey = widgets.LocalKey,
        UniqueKey = widgets.UniqueKey,
        ValueKey = widgets.ValueKey,
        ObjectKey = widgets.ObjectKey,
        GlobalKey = widgets.GlobalKey,
        Provider = widgets.Provider,
        PlayerProvider = player.PlayerProvider,
        PlayerCapability = player.PlayerCapability,
        PlayerSnapshot = player.PlayerSnapshot,
        PlayerScope = player.PlayerScope,
        Theme = widgets.Theme,
        ThemeData = widgets.ThemeData,
        DefaultTextStyle = widgets.DefaultTextStyle,
        DisplaySnapshot = widgets.DisplaySnapshot,
        DisplayScope = widgets.DisplayScope,
        HostActions = player.HostActions,
        HostActionsScope = player.HostActionsScope,
        Opacity = widgets.Opacity,
        Offstage = widgets.Offstage,
        Visibility = widgets.Visibility,
        AutoHide = player.AutoHide,
        AutoHideController = player.AutoHideController,
        Overlay = widgets.Overlay,
        OverlayEntry = widgets.OverlayEntry,
        OverlayEntryWidget = widgets.OverlayEntryWidget,
        OverlayScope = widgets.OverlayScope,
        Theatre = widgets.Theatre,
        Navigator = widgets.Navigator,
        NavigatorScope = widgets.NavigatorScope,
        Page = widgets.Page,
        PopupPage = widgets.PopupPage,
        Route = widgets.Route,
        PopupRoute = widgets.PopupRoute,
        RouteResult = widgets.RouteResult,
        ModalBarrier = widgets.ModalBarrier,
        WidgetsApp = widgets.WidgetsApp,
        DefaultApp = player.DefaultApp,
        Main = player.Main,
        PlayerMain = player.PlayerMain,
        WindowLayer = player.WindowLayer,
        PlayerTheme = player.PlayerTheme,
        PlayerThemeData = player.PlayerThemeData,
        PlayerLayout = player.PlayerLayout,
        PlayerDescriptionLayer = player.PlayerDescriptionLayer,
        PlayerControlBar = player.PlayerControlBar,
        PlayerControlButton = player.PlayerControlButton,
        PlayerTimeDisplay = player.PlayerTimeDisplay,
        PlayerHoverText = player.PlayerHoverText,
        PlayerTooltip = player.PlayerTooltip,
        PlayerIcons = player.PlayerIcons,
        Timeline = player.Timeline,
        SlotSpec = define.SlotSpec,
        SlotWrap = define.SlotWrap,
        Text = widgets.Text,
        Icon = widgets.Icon,
        CustomPaint = widgets.CustomPaint,
        GestureDetector = widgets.GestureDetector,
        Button = widgets.Button,
        ButtonBase = widgets.ButtonBase,
        ButtonStyle = widgets.ButtonStyle,
        ElevatedButton = widgets.ElevatedButton,
        OutlinedButton = widgets.OutlinedButton,
        TextButton = widgets.TextButton,
        IconButton = widgets.IconButton,
        Tooltip = widgets.Tooltip,
        LinearProgressIndicator = widgets.LinearProgressIndicator,
        Slider = widgets.Slider,
        HoverText = widgets.HoverText,
        Padding = widgets.Padding,
        Align = widgets.Align,
        Center = widgets.Center,
        SizedBox = widgets.SizedBox,
        DecoratedBox = widgets.DecoratedBox,
        Flexible = widgets.Flexible,
        Expanded = widgets.Expanded,
        Spacer = widgets.Spacer,
        Flex = widgets.Flex,
        Row = widgets.Row,
        Column = widgets.Column,
        Stack = widgets.Stack,
        Positioned = widgets.Positioned,
        ConstrainedBox = widgets.ConstrainedBox,
        LimitedBox = widgets.LimitedBox,
        UnconstrainedBox = widgets.UnconstrainedBox,
        OverflowBox = widgets.OverflowBox,
        FittedBox = widgets.FittedBox,
        Container = widgets.Container,
        OffsetBox = widgets.OffsetBox,
        TransformBox = widgets.TransformBox,
        LayoutScaleBox = widgets.LayoutScaleBox,
        Offset = geometry.Offset,
        Point = geometry.Point,
        Size = geometry.Size,
        Rect = geometry.Rect,
        EdgeInsets = geometry.EdgeInsets,
        Color = color.Color,
        Paint = paint.Paint,
        TextStyle = text_style.TextStyle,
        Matrix2D = transform.Matrix2D,
        Anchor = anchor.Anchor,
        TextPaint = text_paint.TextPaint,
        new_widget = dsl.new_widget,
        new_state = dsl.new_state,
    }
    return out
end

return collect()
