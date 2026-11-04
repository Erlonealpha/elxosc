# 测试与验证

本文是测试入口和回归范围的当前说明。所有命令从仓库根目录执行。

## 必跑检查

本地工具名来自忽略的 `project.conf`；首次运行前复制 `project.conf.tpl` 并按机器调整。
默认命令为：

```text
luajit test/run.lua
emmylua_check .
uv run --group test python -m pytest -q test/real_host
```

历史基线（2026-10-16）为 **1315 Lua checks passed**、EmmyLua **No issues found**、
real-host **9 passed**。P0/R1/R2 + N1/N2 工作区（2026-10-26）为 **1371 Lua checks passed**；
加入 R3/R4 回归后为 **1381 Lua checks passed**，加入 N3 回归后为 **1426 Lua checks passed**；
当时 EmmyLua **No issues found**、Python integration **9 passed**、real-host **9 passed**。
N3 Demo 回归后的基线为 **1458 Lua checks passed**；N4/N5 回归后的历史基线为
**1491 Lua checks passed**、EmmyLua **No issues found**、
real-host **10 passed**。测试数量变化时，应在本文件和主设计文档同步更新。

2026-10-27 runtime 完成与测试运行器更新后：**1682 Lua checks**（runtime 组 **252**），
CLI 子进程测试 **14 passed**。`emmylua_check . --ignore 'tmp/**'` 无诊断；默认扫描
包含本地 Git-ignored 类型草稿时有 **18 个重复类型/字段 warning**，正式 Key/Binding
类型声明位于生产模块，不依赖草稿。工作区 `main.lua` 用户开关为 false 时 real-host
为 **8 passed, 2 failed**（Demo 启动）；仅启用入口的隔离源码副本为 **10 passed**。
这些结果分别记录，未将隔离副本通过写成禁用入口工作区通过。

2026-10-28 P1 Builder contract 完成后：**1708 Lua checks**，其中 Builder 专项 **26**；
`emmylua_check . --ignore 'tmp/**'` 无诊断。工作区 real-host 仍为 **8 passed, 2 failed**，
失败原因是用户保持 `main.lua enable = false`，未启动 Demo 入口；未将该结果写成 Builder
代码失败或通过。

2026-10-28 P2 ModernX 默认播放器完成后：**1753 Lua checks**，其中 ModernX 专项 **31**；
`emmylua_check . --ignore 'tmp/**'` 无诊断。P2 关联回归为 input **94**、main_layout **26**、
host_app **106**、flutter_runtime/lifecycle **70**。工作区 real-host 入口仍由用户关闭，
因此未将 real-host 结果写成 P2 通过。

2026-10-29 P2.5 controls/seek 核心切片后：**2029 Lua checks**，其中 ModernX 专项 **78**、
main_layout **67**、player_layout **62**、widget **98**；`emmylua_check . --ignore 'tmp/**'`
无诊断；real-host **10 passed**。本切片新增 ProgressBar hover/seek state machine、button
rebuild hover persistence、ModernX edge background、window control 和 extended HostActions
回归。P2.5 仍为 `in_progress`，未将未完成 seekbar time tooltip/thumbfast/soft-repeat/metadata/capability 产品状态
写成阶段通过。

2026-10-30 P2.5 收口后：**2060 Lua checks**；ModernX 专项 **88**、main_layout **72**、
player_layout **69**、widget **100**、host_player_context **33**、host_app **126**；
`emmylua_check . --ignore 'tmp/**'` 无诊断；real-host 使用现有已暂存入口版本 **10 passed**。
新增 seekbar time/chapter tooltip、thumbfast capability fallback、frame-clock soft-repeat、selector
message 和 download capability empty-state 回归；P2.5 标记为 `completed`，metadata/idle/第三方
 异步业务与最终人工 parity 仍由 P2.6/P2.7 负责。

2026-11-03 P2.6 metadata/idle/capability 基础 slice 后：**2079 Lua checks**；
`test_player_metadata` **9**、ModernX **90**、player_layout **73**、host_player_context **35**、
host_app **128**；`emmylua_check . --ignore 'tmp/**'` 无诊断。metadata/file-size observer、idle
无控件状态、URL/live/loading 文案、description panel、键盘链接路由、下载生命周期、SponsorBlock
ranges 和 yt-dlp unavailable/dispose capability boundary 已有回归；P2.6 仍为 `in_progress`，
comments 未批准能力保持 explicit unavailable，最终 parity 由 P2.7 负责。

2026-11-03 P2.6 收口后：**2110 Lua checks**；real-host 使用用户已暂存入口 **10 passed**；
`emmylua_check . --ignore 'tmp/**'` 无诊断。open_url/download、TAB/Shift+TAB/Enter/ESC、
SponsorBlock 独立 ranges、stats formatting 和 async cancellation 均有 focused regression。

2026-11-04 P2.7 parity 修复切片后：**2131 Lua checks**；focused `player_layout` **89**、
`modernx_player` **100**、`main_layout` **76**、`host_player_context` **42**；
`emmylua_check .` **No issues found**。本次覆盖 ModernX hover/tooltip、语义图标、1.5 默认
scale、thumbfast 重复 info/cancel、description panel AutoHide、seekable cache ranges 和
persistent progress。

工作区用户保持的 `main.lua` demo pages 注释状态下，real-host 为 **8 passed, 2 failed**，
失败仅为 Demo property/route 不存在；临时隔离恢复 demo pages 返回值运行完整
`test/real_host` 为 **10 passed**，随后已逐字恢复 `main.lua`。最终视觉/手感仍需用户人工
对照 ModernX 确认，未将临时入口结果写成工作区默认入口通过。

### 播放器复审修正与 hover 调查（2026-11-05）

完整 `luajit test/run.lua`：**2177 checks passed**；`emmylua_check .`：
**No issues found**。新增回归覆盖随 Main scale 更新的 AutoHide 唤醒区、独立 blur glyph
hover、disabled alpha/点击透传、背景源边界、顶部几何、四态音量图标、tooltip 固定高度、
thumbfast 边缘对齐，以及拆分模块和旧入口的 identity。

`uv run --group test python -m pytest -q test/real_host test/test_runner.py --tb=short`
为 **22 passed, 2 failed**：real-host **8 passed, 2 failed**，runner CLI **14 passed**。
两项失败是用户 `main.lua` 注释了 Demo pages 返回值，导致 Demo count/route property 不存在。
fixture 新增显式选项，只在临时 staging 副本中恢复识别到的 Demo pages 返回值：

```powershell
$env:ELXOSC_TEST_DEMO_ENTRY = '1'
uv run --group test python -m pytest -q test/real_host --tb=short
```

该模式 **10 passed**；原始工作文件及 index blob 均保持不变。不能把 staging 模式通过
写成工作区默认入口通过。Windows/mpv.net 已运行，Linux 未运行；最终视觉和手感待人工验收。

局部调查入口：

```text
luajit tools/benchmark_player_hover.lua 2000
```

环境为 Windows/x64、LuaJIT 2.1.1748459687，1280×720、Main scale 1.5、20 chapters、
available 320×180 thumbfast、200 warmup、2000 samples、QPC 计时。代码基线为
`75e35d5` 加本轮播放器工作区；前后仅比较 tooltip 从 State rebuild 切换为直接绘制的成本，
不把原提交未经外观修正的播放器当作前测样本。探针对 Element rebuild 方法计数，并立即
执行各帧阶段；未开启 debug 日志。

| 指标 | 绘制优化前 | 优化后首次 | 优化后复测 |
| --- | ---: | ---: | ---: |
| total P50 (ms) | 12.0611 | 2.4758 | 3.2233 |
| total P95 (ms) | 43.1936 | 9.3202 | 11.5942 |
| total max (ms) | 56.5912 | 25.5217 | 30.0323 |
| Element rebuild calls | 18000 | 0 | 0 |
| layout frames | 2000 | 0 | 0 |
| input invalidated frames | 2000 | 0 | 0 |
| ASS bytes | 13455 | 13455 | 13455 |

| 阶段 mean (ms) | 优化前 | 优化后复测 |
| --- | ---: | ---: |
| activity tree walk | 0.4620 | 0.3966 |
| pointer dispatch | 0.4212 | 0.2967 |
| build | 0.2216 | 0.0142 |
| layout | 0.5824 | 0.0016 |
| input regions | 10.6963 | 0.3870 |
| paint / ASS | 4.3137 | 3.2028 |
| presenter preparation | 0.0143 | 0.0172 |

定位到的主因是 tooltip 每次移动都会重建并触发布局和 input region 刷新。现在 tooltip
始终保留在原树内，hover 更新 State 自有绘制数据并调用 RenderObject paint dirty；
Paragraph 按 label/style 缓存，不改变控件 identity、布局或 RegionSnapshot。

这只是使用 mp stub 的 Lua 路径调查，present 阶段仅包含字符串/缓存准备。它不包含实际
宿主鼠标事件送达、帧定时等待、libass 光栅化、外部 thumbfast 或真实 overlay 提交成本，
也没有直接运行 ModernX 做同路径对照。GC、运行负载和计数 instrumentation 会影响耗时；
剩余开销主要在整树 paint/ASS 和 activity 遍历。完整 benchmark 场景矩阵、宿主延迟和
绘制边界评估仍需后续工作，不能据此宣称真实交互延迟已全部解决。

## Lua suite

2026-11-05 开发 Demo 注入与控件修正后：**2202 Lua checks**，`emmylua_check .`
**No issues found**；`uv run --group test python -m pytest -q test/real_host test/test_runner.py --tb=short`
**25 passed**（real-host **11**、runner CLI **14**）。Demo 默认注入且关闭；加载生成媒体后
真实点击置顶左侧按钮打开，关闭释放 State，再打开重置计数。Windows 输入定位只针对
自有窗口并恢复鼠标位置；测试等待输入 section ready，避免初次挂载/AutoHide 导致点击空区。
此前工作区关闭 Demo pages 的 8/2 结果属于历史入口，不能当作当前入口结果。

新增回归覆盖全强度文本 glow、固定音量圆点、受控右侧按钮插入且不改变 pin/fullscreen
位置、三个 Define slot、Demo close/dispose/reopen 和原有 Page/Popup/ESC 行为。

`test/run.lua` 是无 mpv 依赖的总入口，自动发现 `test_*.lua`，并递归进入以 `test`
开头的测试组目录；其他目录（包括 `real_host` 和 fixtures）不进入 Lua suite。
文件按相对路径排序。筛选器各段按字面子串匹配，并允许省略 `test_` 和 `.lua`：
`player/layout` 匹配 `test_player/test_layout.lua`；单段可匹配任意深度的组或文件。
默认只输出错误和总结，`-v` 显示文件、section 和成功用例；空匹配/非法参数返回非零。

runtime identity、生命周期和 frame 顺序由离线/host stub 测试验收，人工仅负责最终
视觉和交互手感。测试运行器 CLI 本身由 `test/test_runner.py` 的独立子进程测试覆盖。
测试按层覆盖：

- foundation/painting/text：值语义、边界校验、Canvas/TextLayout 契约；
- layout/render：约束代数、布局收敛、绘制记录、命中/输入逆映射、dirty 分类；
- animation/scheduler：假时钟、重复/反向、监听替换和 State 资源生命周期；
- widget：Widget/Element 复用、State rebuild、Builder contract/失败清理、ModernX Main/
  ProgressBar/AutoHide、聚合 identity、控件行为；
- libs/Define：沙箱、模块、scope 首次 payload、transaction 失败隔离、module 延迟发布、
  bind 顺序和错误边界；
- host stub/ASS：presenter、Demo、ASS 标签、host wiring 和 layering 规则；
- Flutter runtime：BuildScope/inactive/finalize、PipelineOwner/RenderOwner identity、
  PaintingContext Canvas 边界、Binding singleton/role identity、copied-owner isolation、
  Key equality/duplicate 和 GlobalKey registry/stale cleanup；
- N1 application：WidgetsApp ambients、DefaultApp/Main composition、uniform scale、
  HostActions、AutoHide/Visibility、Main 隐藏不影响 Extension 和空 WindowLayer；
- N2 Overlay：mounted builder context、single Entry owner、opaque occlusion、
  maintain_state、paint/input eligibility、plan generation、remove/dispose lifecycle；
- N3 navigation：lazy Page builder context、class/key route reconciliation、single Theatre
  push/pop、result/dispose ordering、Popup barrier and ESC claim policy；
- N3 Demo：真实 mounted button 的 pointer 路径、首页 State/计数保留、返回结果展示、
  popup 卡片与遮罩命中、ESC、重复打开命令及 dispose 清理；
- N4 presentation：ASS event 行边界/顺序、单 Canvas/Presenter identity、提交失败重试、
  空 ASS clear、resolution cache 和幂等 shutdown；
- N5 input：RegionSnapshot identity/副本、paint-only input invalidation、section callback
  cache/顺序、指定 disable、passive 透传、capture 取消和 root replacement；
- R3/R4：唯一 `app.extension` Define/Slot boundary、旧 grid target rejection、single
  mounted extension owner、host primitive identity 和不持有整个 App 的 `MpInput`；
- `test_constraints_examples.lua`：固定 400×670 约束示例的完整 ASS 快照。

聚合模块必须和直接模块返回同一类对象；新增公共 API 时要有加载测试，而非只测
内部字段。无效输入、无限尺寸、零/负缩放和非法选项应在边界测试。

阶段 6 的新增回归要求：

6.3 Provider 修复还必须覆盖：

- inherited Provider 的精确运行时类型查找和最近祖先规则；
- `of`/`maybe_of` 的监听依赖与 `read`/`maybe_read` 的非监听读取；
- State 首次挂载、Provider 更新时的 `did_change_dependencies` 顺序；
- `update_should_notify == false`、依赖重查、unmount 清理；
- `init_state`/`dispose` 中拒绝监听式 lookup，并允许明确的非监听读取。

- Define 是唯一扩展内容入口；重复 scope payload、bind 顺序和错误边界保持覆盖；
- 配置/API 热更新验证 snapshot、Provider/State/setter 传播、订阅清理，并证明不会
  重新执行扩展源代码或重复注册 class/host callback；
- DefaultApp/Main、Extension/WindowLayer 边界、Define/Slot 初始化贡献和 ordered append；
- `set_mouse_area` 坐标换算、passive/interactive/exclusive policy、双击拦截和背景
  默认绑定透传；
- 结构化 PointerEvent/KeyEvent 字段、字段快照/边界、legacy payload 兼容、structured
  dispatch result 和显式 capture；
- input section 的 enable/disable、resize、hidden layer、root swap、capture 和
  shutdown 清理；
- 同一逻辑 Overlay 的 entry 创建、更新、移除、opaque/maintain_state plan 和 overlap
  input eligibility；host-level 多 overlay、独立 presenter/cache 和 z policy 仍延期；
- 顶层控件 visible/hidden、AutoHide 和 Offstage 生命周期；N3 的 ESC section/route pop
  已覆盖，完整 keyboard focus 和 host modal policy 仍属于后续输入阶段。

## EmmyLua

框架生产目录要求零诊断。测试文件可以针对 `std.class` 模型和第三方 host stub
使用靠近代码的局部 suppression，但不能在生产文件用文件级 suppression 掩盖错误。

## Real host

`test/real_host/` 使用隔离 config、临时 staging 和 ownership-bounded cleanup，验证
真实 mpv/mpv.net 能加载脚本、接收 overlay、处理输入并产生非空 bounds。只能在所需
host 确实不可用时 skip；禁止使用按进程名杀 mpv 的清理命令。

真实 libass bounds 证明事件可被宿主接收，不等价于精确字体 ink bounds 或光学居中
证明；精确逻辑仍由离线 Canvas/Paragraph 测试覆盖。

`test_elxosc.py` 通过生产 `main.lua` 打开 Demo 的 Page/Popup，发送真实 `keypress ESC`，
验证结果、覆盖期间的计数更新和首页 ESC 交还独立宿主脚本的绑定。这是自动化输入/生命周期
证据；按钮点击、卡片与遮罩的命中由 Lua stub 回归覆盖，不代表人工视觉验收。

阶段 6 的 real-host fixture 已使用真实用户 `mbtn_left_dbl` 绑定验证：交互控件区域
不触发默认 fullscreen，背景区域仍保留该绑定；Demo Page/Popup 的真实 ESC 和结果已覆盖。
OSD resize 后的 mouse area 坐标仍主要由 Lua host stub 覆盖；Linux 本轮未运行。多 overlay
仍是延期项，不把它写成 N4 通过。

## 改动后的检查顺序

先运行受影响的 focused suite，再运行完整 Lua suite、EmmyLua 和 real-host suite。
提交前检查 `git diff --check`、`git diff --stat`、`git status --short`，并在提交
说明中只写实际执行过的命令。
