# MPV 输入区域与事件系统

本文规划下一阶段的 mpv 输入边界。它建立在当前 `host/mpv_input.lua`、
`RenderOwner` 和 `RenderGesture` 之上，目标是让 UI 控件精确拦截属于自己的输入，
同时保留播放器背景区域的用户 `input.conf` 行为。

**状态：6.0 已完成 API 语义 spike，6.1 区域隔离实施中。** 下文仍有未完成的
事件、真实宿主回归和生命周期部分；实施顺序和依赖见 [ROADMAP.md](ROADMAP.md)。

## 当前基线

当前宿主输入层使用 `elxosc-input`、`elxosc-wheel` 以及按区域追加编号的 section，
按 `RenderOwner:pointer_regions()` 导出的 root-space 区域来启用或禁用。它已经支持
鼠标移动、离开、左右键、滚轮和 pointer capture，但事件字段仍主要放在
`PointerEvent.data`，结构化事件和完整生命周期清理尚未完成。

旧实现中，控件区域遇到用户配置的 `mbtn_left_dbl` 时，mpv 仍可能执行例如
`cycle fullscreen`。仅在 Lua 层收到一次普通 down/up 不能可靠地表达“这个区域已经
消费双击”，因此当前 section 必须显式声明并处理 `mbtn_left_dbl`。

本次提供的参考脚本只作为设计参考，不是运行依赖：

- `osc.lua:439–472`：窗口/虚拟 ASS 坐标换算；`3003–3038`：区域与可见性；
  `3288–3322`：显示监听与点击 section 分离、显式忽略双击；`3509–3511`：空区域初始化。
- `gallerymode.lua:77–80, 127–136`：更新全窗口区域并绑定双击；`160–168`：
  查找用户双击命令。这个“拦截后手动执行命令”的例子不作为通用回退协议。

参考代码提供 mpv 接线经验，不改变核心层无 mpv 依赖的边界。实施时针对目标版本
验证行为，不依赖参考脚本长期存在，也不默认移植其整屏拦截逻辑。

## 输入区域模型

框架负责导出后端无关的命中区域和策略；host 负责将这些区域换算并提交给 mpv。
完成布局和本帧变换更新后产生快照，不在框架中调用 `mp.set_mouse_area`：

```text
RenderObject tree
    → visible interactive nodes
    → root-space Rect list + section policy
    → logical OSD to mpv window coordinate conversion
    → mp.set_mouse_area(..., section)
```

区域快照只在以下条件变化时更新：

- layout 或 viewport/OSD 尺寸变化；
- paint-only offset/scale、clip 或有效命中边界变化（不能只监听 layout dirty）；
- Widget 的可见性或交互能力变化；
- Pages、overlay 的 z 顺序或 modal layer 切换；
- input policy 或配置变化。

普通 mouse move 不应重建整个区域集合；但鼠标位置仍可用于精确命中与 section 选择。
快照必须与当前输入逆变换、有效祖先命中边界和 clip 一致；不得把分离的按钮粗暴并成
一个包围盒，导致中间原本可透传的空隙也被吞掉。

当前目标版本的 mpv 输入实现中，一个 section 只保存一个 `mp_rect`；重复调用
`mp.set_mouse_area()` 会替换该 section 的矩形，而不是追加多个矩形。因此当前 6.1
实现使用一个区域对应一个 section，例如 `elxosc-input`、`elxosc-input-2`，并对
wheel 区域使用对应的 `elxosc-wheel` 编号。这样不能把分离的按钮粗暴合并成包围盒，
也保留了区域空隙、前后层遮挡和拖动 capture。窗口与 OSD 坐标关系、像素边界取整、
零尺寸窗口保护，以及 `force`/exclusive 的实际优先级仍需在目标宿主中继续验证。

## 三类节点

### Passive

Root、Column、Row、Padding、Align、Stack 等根节点、排版节点和纯装饰节点默认是
passive：

- 不声明 `wants_pointer`；
- 不创建自己的 mouse area；
- 不阻止该区域的 mpv 默认绑定；
- 只让命中路径继续到真正的 interactive 子节点。

这里的 passive 是“节点自身不处理”，不是 `IgnorePointer` 式的整棵子树跳过。
例如全屏 Root/Stack 自身不吞事件，仍允许内部 Button 命中；装饰层也不能仅因
覆盖整个 viewport 就挡住下层控件。

### Interactive

Button、GestureDetector、Slider、时间线和其他可操作控件是 interactive：

- 明确声明需要的 down/up/move/wheel/double-click 事件；
- 声明自己的 root-space 区域，由 host 区域管理器分配对应 section；
- 处理声明的事件并按需要请求 capture；
- 默认消费该区域内的相关 mpv mouse binding。

### Exclusive

菜单、对话框、拖拽层和 modal overlay 可以声明 exclusive：

- 启用带 exclusive 语义的 section 或等价 host policy；
- 阻止区域内不属于当前 modal 的事件穿透到播放器；
- 关闭时清除 area、capture、hover 和 section 状态。

`overlay.z` 只决定视觉层顺序，不自动使 overlay exclusive；输入策略必须显式声明。
框架中的 modal/exclusive 不等于直接给 mpv section 加 `exclusive` flag；该 flag
还可能屏蔽本来未声明的键盘绑定。区域拦截与键盘焦点作用域必须分别验证和管理。

## 默认双击规则

下一阶段的默认规则是：

1. interactive 控件的 section 显式绑定 `mbtn_left_dbl`，默认处理为 ignore/consume；
2. 控件没有 double-click handler 时，不产生额外的 UI 回调；
3. 保留宿主实际交付的正常 down/up，不为双击额外合成 click，也不默认延迟单击；
4. UI 空白区和视频背景区没有 interactive area，用户的 `input.conf` 双击行为继续
   生效；
5. 未来需要双击语义的控件再声明 `on_double_tap`，届时明确单/双击互斥规则；普通
   按钮快速点击可能仍产生多次正常 click，这不等于双击事件额外触发业务回调。

这同时解决“按钮双击触发 fullscreen”和“背景双击仍可 fullscreen”两个需求。

## 输入 section 分区

计划使用职责清晰的 section，而不是把所有事件放在一个动态开关里：

| Section | 用途 | 默认行为 |
| --- | --- | --- |
| `elxosc-showhide` | mouse move/leave，驱动顶层控件显隐 | 不抢播放器 click |
| `elxosc-input` | 普通 Button、时间线、菜单控件 | 仅在区域内消费相关鼠标事件 |
| `elxosc-window-controls` | 标题栏和窗口控制 | 仅在标题栏区域内消费 |
| `elxosc-drag` | 明确声明的视频/窗口拖动 | 按控件策略选择 dragging flags |
| `elxosc-modal` | 菜单、对话框和 modal layer | 可 exclusive，关闭时完整清理 |

表中为职责分组；普通输入区域当前使用基础名称加编号的 section。普通控件不默认
允许窗口拖动；`allow-vo-dragging`、`allow-hide-cursor` 按显示监听、拖动区和控件区
分别配置，不把当前全局 flags 原样复制到所有分组。

所有 section 在初始化和关闭时清理旧 mouse area；不可见 layer 不留旧区域或 enable
状态。只移除本应用拥有的 section/observer，不修改用户 `input.conf`。6.0 还要验证
离开区域、窗口失焦和强制隐藏时，宿主是否继续交付已捕获序列的 up/cancel。

## 事件模型重构

当前 boolean `handled` 不能区分“业务已处理”“请求 capture”和“停止传播”。下一阶段
先定义框架内部的结构化结果，并在迁移期兼容 boolean：

```lua
{
    handled = true,
    capture = true,
    stop_propagation = true,
}
```

**mpv 的默认绑定在选择 section 时就已决定**；Lua callback 返回 false 不能重放到
`input.conf`，一个事后的 `prevent_default` 字段也不能控制 mpv 已经选中的命令。
因此 host 默认行为由区域/事件族的事前 claim policy 决定，和树内 dispatch result
分开。不复制 `input-bindings` 命令作为一般回退，也不递归注入相同按键。

`PointerEvent` 计划增加结构化字段，而不是继续扩张 `data`；以下是字段草案：

| 字段 | 语义 |
| --- | --- |
| `type` | down/up/move/cancel/wheel，以及明确的双击语义；hover 由路由器管理 |
| `point` | root-space 坐标；分发时另提供 target local 坐标 |
| `pointer_id`, `button`, `buttons` | 指针标识、变化的键和按住的键集合 |
| `click_count` | 宿主已报告的点击次数，不无依据地合成多击 |
| `delta_x`, `delta_y` | 双轴滚轮/移动量，单位在适配契约中固定 |
| `modifiers` | shift/ctrl/alt/meta，只填目标宿主可提供的信息 |
| `source`, `timestamp` | 输入来源和单调时间；先实现 mouse，为 touch 预留契约 |

Keyboard 不伪装成 PointerEvent，后续使用独立的 `KeyEvent`，包含 key、down/up/press、
modifier、repeat 和 timestamp。Gesture arena 仍属于原有交互路线；本阶段先完成
事件结构、capture、区域和默认行为隔离。

capture 归属至少包含 layer、target 和按键序列；在 capture 期间优先投递到原目标，
不能因为移到另一个 overlay 就重新命中。补齐离开命中区后的可用 local 坐标及
inside/outside 状态，便于时间线拖动；目标卸载、失焦或强制隐藏必须 cancel。鼠标
不移动而布局/变换变化时也重新核对 hover，避免旧状态残留。

## 分期

### 6.0 mpv 输入 spike

- 验证 `mp.set_mouse_area()` 的坐标和多区域语义；已确认每个 section 只有一个矩形，
  当前实现采用按区域拆分 section；
- 验证 `force`、exclusive、用户 `input.conf` 和双击事件优先级；
- 已新增最小 mp stub；真实 host fixture 仍需补充，不先改整个 RenderOwner。

### 6.1 区域与默认输入隔离

- 为 RenderObject 增加可导出的交互区域快照；
- host 完成 OSD/窗口坐标换算、section 生命周期和区域更新；
- interactive 区域消费双击，passive/background 保留 mpv 默认行为；
- 覆盖隐藏 overlay、root swap、resize、capture 和 shutdown 清理。

### 6.2 输入事件重构

- 结构化 PointerEvent/KeyEvent；
- `InputRouter` 或等价 host 层，处理 section、area、capture 和 dispatch result；
- 接入 modifier、middle/right、四向 wheel、double-click、keyboard 基础事件；
- 保持核心层无 mpv 依赖，host 负责将 mpv 事件翻译为值对象。

## 验收标准

- Button 区域双击不会执行用户 `input.conf` 的 fullscreen；
- 没有 interactive region 的背景仍可执行用户默认双击；
- Root、Column、Row、Padding、Align 等排版节点默认不吞输入；
- input area 随 layout、paint-only transform、clip、OSD resize、visibility 和层级变化更新；
- pointer capture 在移出后仍能收到 up/cancel；
- root swap、隐藏 overlay 和 shutdown 清理 capture、hover、area、section；
- mpv stub 和真实 host 都覆盖双击拦截、区域间空隙透传和坐标缩放；
- 真实输入回归经过 mpv 的按键解析/section 选择，而非只用 script-message 直调
  RenderOwner；原先的注入式 Button 测试不能单独证明默认绑定不穿透。
