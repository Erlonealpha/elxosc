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

## Lua suite

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
- widget：Widget/Element 复用、State rebuild、聚合 identity、控件行为；
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
