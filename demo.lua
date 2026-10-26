-- elxosc demo widget used by the entry point and real-host smoke tests.

local mp = require 'mp'

local std = require 'elxlibs.std'

local anchor_mod = require 'foundation.anchor'
local color = require 'foundation.color'
local geometry = require 'foundation.geometry'
local text_paint_mod = require 'painting.text_paint'
local text_style = require 'text.text_style'
local basic_widgets = require 'widget.widgets.basic'
local layout_widgets = require 'widget.widgets.layout'
local icon_mod = require 'widget.widgets.icon'
local state_mod = require 'widget.state'
local widget_mod = require 'widget.widget'
local player_context = require 'widget.player_context'
local tween_mod = require 'animation.tween'
local navigation_mod = require 'widget.navigation'

local Color = color.Color
local Anchor = anchor_mod.Anchor
local Offset = geometry.Offset
local Size = geometry.Size
local EdgeInsets = geometry.EdgeInsets
local TextPaint = text_paint_mod.TextPaint
local TextStyle = text_style.TextStyle
local Align = text_style.Align
local State = state_mod.State
local StatefulWidget = widget_mod.StatefulWidget
local PlayerProvider = player_context.PlayerProvider
local Tween = tween_mod.Tween
local Column = layout_widgets.Column
local Row = layout_widgets.Row
local Container = layout_widgets.Container
local OffsetBox = layout_widgets.OffsetBox
local FittedBox = layout_widgets.FittedBox
local TransformBox = layout_widgets.TransformBox
local LayoutScaleBox = layout_widgets.LayoutScaleBox
local SizedBox = layout_widgets.SizedBox
local ElevatedButton = basic_widgets.ElevatedButton
local OutlinedButton = basic_widgets.OutlinedButton
local TextButton = basic_widgets.TextButton
local IconButton = basic_widgets.IconButton
local Icon = icon_mod.Icon
local Text = basic_widgets.Text
local GestureDetector = basic_widgets.GestureDetector
local Page = navigation_mod.Page
local PopupPage = navigation_mod.PopupPage
local Navigator = navigation_mod.Navigator

local M = {}

---@param children Widget[]
---@return Widget
local function navigation_card(children)
  -- Only the card consumes interior clicks; the surrounding area belongs to
  -- PopupRoute's barrier. Passive labels must not dismiss the popup.
  return GestureDetector(Container({
    key = 'demo-navigation-card',
    width = 440,
    padding = EdgeInsets.all(20),
    color = Color.rgba(0x182536FF),
    radius = 8,
    child = Column({
      main_axis_size = 'min',
      spacing = 14,
      children = children
    })
  }), {
    on_down = function ()
    end,
    on_up = function ()
    end
  })
end

-- Replaces the old hand-built RenderObject smoke tree: a stateful widget that
-- counts the `elxosc-demo` script messages, so `set_state` -> rebuild -> ASS
-- output can be eyeballed in mpv.

---@class DemoState: State
---@field widget                  Demo
---@field count                   integer
---@field selected                string
---@field motion                  number              frame-clock animation progress
---@field motion_controller       AnimationController
---@field button_scale_controller AnimationController
---@field button_scale_tween      Tween<Size>
---@field navigation_result       string
---@field navigation_returns      integer
---@field result_unsubscribe      (fun(): boolean)?
---@overload fun(): self
local DemoState = std.class.new('DemoState', { State })

function DemoState:__init()
  std.super(DemoState, self, State).__init(self)
  self.count = 0
  self.selected = 'ready'
  self.motion = 0
  self.button_scale_controller = nil
  self.button_scale_tween = nil
  self.navigation_result = 'No route closed yet'
  self.navigation_returns = 0
  self.result_unsubscribe = nil
end

function DemoState:init_state()
  self.motion_controller = self:create_animation_controller({ duration = 1.2 })
  self.button_scale_controller = self:create_animation_controller({ duration = 0.24 })
  self.button_scale_tween = Tween(Size(1, 1), Size(1.12, 1.12))
  self.motion_controller:add_listener(function (controller)
    self:set_state(function ()
      self.motion = controller.value
    end)
  end)

  -- `set_root_widget` may mount a fresh element (rather than reusing this
  -- one), so registering is made idempotent instead of assuming it runs once.
  mp.unregister_script_message('elxosc-demo')
  mp.register_script_message('elxosc-demo', function (action)
    if action == 'page' then
      self:_open_page()
      return
    elseif action == 'popup' then
      self:_open_popup()
      return
    elseif action ~= nil and action ~= '' then
      return
    end
    self:set_state(function ()
      self.count = self.count + 1
      self.selected = 'message'
      mp.set_property('user-data/elxosc-demo-count', tostring(self.count))
      mp.set_property('user-data/elxosc-demo-event', self.selected)
    end)
  end)
  mp.set_property('user-data/elxosc-demo-count', tostring(self.count))
  mp.set_property('user-data/elxosc-demo-event', self.selected)
  mp.set_property('user-data/elxosc-demo-route', 'home')
  mp.set_property('user-data/elxosc-demo-result', self.navigation_result)
  mp.set_property('user-data/elxosc-demo-returns', '0')
end

function DemoState:dispose()
  mp.unregister_script_message('elxosc-demo')
  if self.result_unsubscribe then
    self.result_unsubscribe()
    self.result_unsubscribe = nil
  end
end

function DemoState:_set_event(name)
  self:set_state(function ()
    self.selected = name
    mp.set_property('user-data/elxosc-demo-event', name)
  end)
end

---@param name string
function DemoState:_animate(name)
  self:set_state(function ()
    self.selected = name
  end)
  self.motion_controller:repeat_animation({ reverse = true, count = 1 })
  mp.set_property('user-data/elxosc-demo-event', name)
end

---@return NavigatorState?
function DemoState:_ready_navigator()
  local navigator = self.widget.navigator
  if not navigator or not self:is_mounted() or self.result_unsubscribe then
    return nil
  end
  local route = navigator:current_route()
  if route and route.page.key == 'demo-home' then
    return navigator
  end
  return nil
end

---@param route Route
---@param label string
function DemoState:_watch_result(route, label)
  mp.set_property('user-data/elxosc-demo-route', route.page.name)
  self.result_unsubscribe = route.result:add_listener(function (value)
    self.result_unsubscribe = nil
    self:set_state(function ()
      self.navigation_result = label .. ': ' .. (value == nil and 'dismissed' or tostring(value))
      self.navigation_returns = self.navigation_returns + 1
      mp.set_property('user-data/elxosc-demo-route', 'home')
      mp.set_property('user-data/elxosc-demo-result', self.navigation_result)
      mp.set_property('user-data/elxosc-demo-returns', tostring(self.navigation_returns))
    end)
  end)
end

function DemoState:_open_page()
  local navigator = self:_ready_navigator()
  if not navigator then
    return
  end
  local route = navigator:push(Page({
      key = 'demo-details',
      name = 'details',
      builder = function (context)
        local current = Navigator.of(context)
        return Container({
          alignment = Offset(0.5, 0.5),
          padding = EdgeInsets.all(16),
          color = Color.rgba(0x101824FF),
          child = navigation_card({
            Text('Page + Route', { style = TextStyle({ font_size = 22, bold = true }) }),
            Text('The home Page stays mounted while this opaque Page is visible.', {
              style = TextStyle({ font_size = 15 })
            }),
            Text('Back returns "done". ESC returns no value.', {
              style = TextStyle({ font_size = 15 })
            }),
            ElevatedButton({
              key = 'demo-page-back',
              label = 'Back with result',
              on_click = function ()
                current:pop('done')
              end
            })
          })
        })
      end
    }))
  self:_watch_result(route, 'Page')
end

function DemoState:_open_popup()
  local navigator = self:_ready_navigator()
  if not navigator then
    return
  end
  local route = navigator:push_popup(PopupPage({
      key = 'demo-popup',
      name = 'popup',
      barrier_color = Color.rgba(0x000000A0),
      barrier_dismissible = true,
      builder = function (context)
        local current = Navigator.of(context)
        return Container({
          alignment = Offset(0.5, 0.5),
          padding = EdgeInsets.all(16),
          child = navigation_card({
            Text('PopupRoute', { style = TextStyle({ font_size = 22, bold = true }) }),
            Text('The home Page remains visible beneath the modal barrier.', {
              style = TextStyle({ font_size = 15 })
            }),
            Text('Click outside or press ESC to dismiss without a result.', {
              style = TextStyle({ font_size = 15 })
            }),
            Row({
              main_axis_size = 'min',
              spacing = 12,
              children = {
                OutlinedButton({
                  key = 'demo-popup-cancel',
                  label = 'Cancel',
                  on_click = function ()
                    current:pop('cancelled')
                  end
                }),
                ElevatedButton({
                  key = 'demo-popup-confirm',
                  label = 'Confirm',
                  on_click = function ()
                    current:pop('confirmed')
                  end
                })
              }
            })
          })
        })
      end
    }))
  self:_watch_result(route, 'Popup')
end

---@return Widget
function DemoState:_navigation_panel()
  if not self.widget.navigator then
    return SizedBox.shrink()
  end
  return Container({
    padding = EdgeInsets.all(10),
    color = Color.rgba(0x183048E8),
    radius = 6,
    child = Column({
      main_axis_size = 'min',
      spacing = 6,
      children = {
        Text('Navigation', { style = TextStyle({ font_size = 18, bold = true }) }),
        Text('Change the counter above, open a route, then return: State is retained.', {
          style = TextStyle({ font_size = 13 })
        }),
        Row({
          main_axis_size = 'min',
          spacing = 10,
          children = {
            ElevatedButton({
              key = 'demo-open-page',
              label = 'Open Page',
              on_click = function ()
                self:_open_page()
              end
            }),
            OutlinedButton({
              key = 'demo-open-popup',
              label = 'Open Popup',
              on_click = function ()
                self:_open_popup()
              end
            })
          }
        }),
        Text(string.format('Result: %s | Returns: %d', self.navigation_result, self.navigation_returns), {
          style = TextStyle({ font_size = 14, color = Color.rgba(0xA7E5C4FF) })
        })
      }
    })
  })
end

---@param context BuildContext
function DemoState:build(context)
  local player = PlayerProvider.maybe_of(context)
  local snapshot = player and player.snapshot
  local display_count = snapshot and snapshot:get('demo_count') or self.count
  local display_event = snapshot and snapshot:get('demo_event') or self.selected

  local function anchor_cell(label, anchor, background)
    return Container({
      width = 64,
      height = 28,
      color = background,
      child = Text(label, {
        style = TextStyle({ font_size = 12, bold = true }),
        text_paint = TextPaint({ anchor = anchor })
      })
    })
  end

  local content = Container {
    padding = EdgeInsets.all(20),
    color = Color.rgba(0x202020C0),
    radius = 6,
    child = Container {
      padding = EdgeInsets.all(5),
      child = Text(string.format('elxosc  %d', display_count), {
        style = TextStyle({ font_size = 20, color = Color.rgba255(0xF0, 0xF0, 0xF0) })
      })
    }
  }
  local anchor_demo = Container({
    padding = EdgeInsets.all(8),
    color = Color.rgba(0x18202AC0),
    child = Row({
      spacing = 4,
      cross_alignment = 'start',
      children = {
        Text('Anchor', {
          style = TextStyle({ font_size = 12, color = Color.rgba255(180, 190, 205) })
        }),
        anchor_cell('TL', Anchor.TOP_LEFT, Color.rgba(0x3C5068C0)),
        anchor_cell('C', Anchor.CENTER, Color.rgba(0x50683CC0)),
        anchor_cell('BR', Anchor.BOTTOM_RIGHT, Color.rgba(0x683C50C0))
      }
    })
  })
  local icon_demo = Container({
    padding = EdgeInsets.all(8),
    color = Color.rgba(0x202020C0),
    child = Row({
      spacing = 10,
      cross_alignment = 'center',
      children = {
        Text('Icon box', {
          style = TextStyle({ font_size = 12, color = Color.rgba255(180, 190, 205) })
        }),
        Icon('play_arrow', { size = 24 }),
        Icon('search', { size = 24, optical_offset = Offset(1, -1) }),
        Icon('favorite', { size = 24 })
      }
    })
  })
  local motion_demo = Container({
    padding = EdgeInsets.all(8),
    color = Color.rgba(0x18202AC0),
    child = Row({
      spacing = 4,
      cross_alignment = 'center',
      children = {
        Text('Frame-clock OffsetBox', {
          style = TextStyle({ font_size = 12, color = Color.rgba255(180, 190, 205) })
        }),
        Container {
          width = 64,
          alignment = Offset(0, 0.5),
          child = OffsetBox {
            offset = Offset(self.motion * 32, 0),
            child = Icon('arrow_forward', { size = 22 })
          }
        },
        Text(string.format('%d%%', math.floor(self.motion * 100 + 0.5)), {
          style = TextStyle({ font_size = 12, bold = true })
        })
      }
    })
  })
  local scale_demo = Container({
    padding = EdgeInsets.all(8),
    color = Color.rgba(0x202020C0),
    child = Row({
      spacing = 6,
      cross_alignment = 'center',
      children = {
        Text('Scale boxes', {
          style = TextStyle({ font_size = 12, color = Color.rgba255(180, 190, 205) })
        }),
        TransformBox(Text('TransformBox', {
          style = TextStyle({
            font_size = 12,
            wrap = false,
            bold = true,
            align = Align.CENTER
          })
        }), {
          scale = Size(1 + self.motion * 0.25, 1 + self.motion * 0.25),
          clip = true
        }),
        LayoutScaleBox(Text('LayoutScaleBox', {
          style = TextStyle({ font_size = 11, wrap = false, align = Align.CENTER })
        }), {
          scale = Size(0.85, 1.15),
          clip = true
        }),
        SizedBox({
          width = 86,
          height = 32,
          child = FittedBox(Text('scale', {
              style = TextStyle({ font_size = 28, wrap = false, bold = true })
            }), { fit = 'contain', clip = true })
        }),
        SizedBox({
          width = 86,
          height = 32,
          child = FittedBox(Text('cover crop', {
              style = TextStyle({ font_size = 20, wrap = false })
            }), { fit = 'cover', clip = true })
        }),
        SizedBox({
          width = 108,
          height = 34,
          child = FittedBox(TransformBox(OutlinedButton {
              label = 'Scale tap',
              on_click = function ()
                self:_set_event('scaled tap')
                self.button_scale_controller:repeat_animation({ reverse = true, count = 1 })
              end
            }, {
              scale = Size(1, 1),
              alignment = Offset(0.5, 0.5),
              scale_controller = self.button_scale_controller,
              scale_tween = self.button_scale_tween
            }), { fit = 'fill', clip = false })
        })
      }
    })
  })
  return Container {
    alignment = Offset(0.5, 0.5),
    color = Color.rgba(0x63636372),
    child = Column({
      main_alignment = 'center',
      spacing = 6,
      children = {
        content,
        anchor_demo,
        icon_demo,
        motion_demo,
        scale_demo,
        Container {
          padding = EdgeInsets.all(5),
          color = Color.rgba(0x2020206C),
          child = Text('event: ' .. tostring(display_event), {
            style = TextStyle({ font_size = 14, color = Color.rgba255(180, 190, 205) })
          })
        },
        Container {
          padding = EdgeInsets.all(5),
          color = Color.rgba(0x183A2AC0),
          child = Text(
            string.format('PlayerContext  count=%s  event=%s', tostring(display_count), tostring(display_event)),
            {
              style = TextStyle({ font_size = 13, color = Color.rgba255(190, 220, 200) })
            }
          )
        },
        Row({
          spacing = 6,
          main_alignment = 'center',
          children = {
            IconButton {
              icon = Icon('add', {
                size = 24
              }),
              on_click = function ()
                self:set_state(function ()
                  self.count = self.count + 1
                  self.selected = 'increment'
                  mp.set_property('user-data/elxosc-demo-count', tostring(self.count))
                  mp.set_property('user-data/elxosc-demo-event', self.selected)
                end)
              end
            },
            OutlinedButton {
              label = 'Reset',
              on_click = function ()
                self:set_state(function ()
                  self.count = 0
                  self.selected = 'reset'
                  mp.set_property('user-data/elxosc-demo-count', '0')
                  mp.set_property('user-data/elxosc-demo-event', self.selected)
                end)
              end
            },
            TextButton { label = 'Ping', on_click = function () self:_set_event('ping') end },
            TextButton {
              label = 'Animate',
              on_click = function ()
                self:_animate('animation')
              end
            },
            IconButton { icon = Text('!'), on_click = function () self:_set_event('icon') end }
          }
        }),
        self:_navigation_panel()
      }
    })
  }
end

---@class _DemoOptions
---@field navigator NavigatorState?
---@field key       any?

---@class Demo: StatefulWidget
---@field navigator NavigatorState?
---@overload fun(options?: _DemoOptions): self
local Demo = std.class.new('Demo', { StatefulWidget })

function Demo:__init(options)
  options = options or {}
  self.key = options.key
  self.navigator = options.navigator
end

function Demo:create_state()
  return DemoState()
end

--- Use the application's WindowLayer Navigator, so ESC targets this stack.
--- The builder supplies a mounted lookup context; events reuse the handle.
---@return Page[]
function M.initial_pages()
  return {
    Page({
      key = 'demo-home',
      name = 'home',
      builder = function (context)
        return Demo({ navigator = Navigator.of(context) })
      end
    })
  }
end

M.DemoState = DemoState
M.Demo = Demo

return M
