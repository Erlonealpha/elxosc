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
EmmyLua **No issues found**、Python integration **9 passed**、real-host **9 passed**。测试数量变化时，应在本文件和主设计文档
同步更新。

## Lua suite

`test/run.lua` 是无 mpv 依赖的总入口，新文件命名为 `test/test_*.lua` 并注册到
runner。测试按层覆盖：

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

阶段 6 的 real-host fixture 已使用真实用户 `mbtn_left_dbl` 绑定验证：交互控件区域
不触发默认 fullscreen，背景区域仍保留该绑定；OSD resize 后的 mouse area 坐标目前
由 Lua host stub 覆盖，真实宿主回归仍需补齐。多 overlay 需要验证真实 `overlay.z`
的视觉顺序和隐藏/移除后的清理行为。

## 改动后的检查顺序

先运行受影响的 focused suite，再运行完整 Lua suite、EmmyLua 和 real-host suite。
提交前检查 `git diff --check`、`git diff --stat`、`git status --short`，并在提交
说明中只写实际执行过的命令。
