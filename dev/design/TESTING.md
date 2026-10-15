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

当前本地基线（2026-10-16）：**1300 Lua checks passed**、EmmyLua
**No issues found**、real-host **9 passed**。测试数量变化时，应在本文件和主设计
文档同步更新。

## Lua suite

`test/run.lua` 是无 mpv 依赖的总入口，新文件命名为 `test/test_*.lua` 并注册到
runner。测试按层覆盖：

- foundation/painting/text：值语义、边界校验、Canvas/TextLayout 契约；
- layout/render：约束代数、布局收敛、绘制记录、命中/输入逆映射、dirty 分类；
- animation/scheduler：假时钟、重复/反向、监听替换和 State 资源生命周期；
- widget：Widget/Element 复用、State rebuild、聚合 identity、控件行为；
- libs/Define：沙箱、模块、scope 首次 payload、bind 顺序和错误边界；
- host stub/ASS：presenter、Demo、ASS 标签、host wiring 和 layering 规则；
- `test_constraints_examples.lua`：固定 400×670 约束示例的完整 ASS 快照。

聚合模块必须和直接模块返回同一类对象；新增公共 API 时要有加载测试，而非只测
内部字段。无效输入、无限尺寸、零/负缩放和非法选项应在边界测试。

阶段 6 的新增回归要求：

- Define 是唯一扩展内容入口；重复 scope payload、bind 顺序和错误边界保持覆盖；
- 配置/API 热更新验证 snapshot、Provider/State/setter 传播、订阅清理，并证明不会
  重新执行扩展源代码或重复注册 class/host callback；
- Pages/Main、3×3 grid 的全部稳定区域、`more`、扩展内容冲突和 ordered append；
- `set_mouse_area` 坐标换算、passive/interactive/exclusive policy、双击拦截和背景
  默认绑定透传；
- 结构化 PointerEvent/KeyEvent 字段、字段快照/边界、legacy payload 兼容、structured
  dispatch result 和显式 capture；
- input section 的 enable/disable、resize、hidden layer、root swap、capture 和
  shutdown 清理；
- 多 overlay 的创建、更新、移除、z 顺序、同 z 稳定排序、独立 presenter/cache 和
  overlap input policy；
- 顶层控件 visible/hidden、auto/always/never 和 modal 输入策略。

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
