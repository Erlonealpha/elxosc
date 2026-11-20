# 测试与验证

本文定义测试分层、必跑检查、真实宿主范围和证据边界。具体操作见
[test/README.md](../../test/README.md)，测量与性能工具见
[tools/README.md](../../tools/README.md)。逐轮执行记录、计数、环境处理和人工反馈由
本地规划的验收材料承担；设计文档只在验证策略或支持边界改变时更新。

## 测试范围选择

文本服务回归覆盖整行自然跨度、测绘同源、cache双上限、树作用域及环境失效。
真实宿主分别验证有限字体参考、生产Text/Tooltip的环境替换、独立App测量ID与清理；
离线测试负责缺能力/native故障、非法边界、缓存淘汰、部分初始化和删除失败重试。
消费者回归验证Tooltip同帧合并/固定label零测量、paint无native、队列取消及失败顺序，
播放器时间/描述/文件大小内容命中、时间占位与本地toggle。真实输入用例覆盖对应区域
点击、AutoHide/thumbfast及拖动，局部成本与整帧成本分别记录；多行推进按其支持范围验证。
共用hover驱动的显式style_updates trace经production root更换文字颜色，保留原指针/
时钟序列；phase模式将初始App服务的文本layout单列，区分布局调用、native测量和包含
探针的服务成本。显式服务或环境替换后的新服务不由此instance探针覆盖，不能以缺项称零调用。

代码更改必须运行完整 Lua suite 和生产 EmmyLua 检查。真实宿主测试按受影响的行为
选择文件或用例：script loading、presentation、input、Define wiring 和 player integration
变化需要对应 real-host；纯文档或没有相关宿主影响的更改不需要 real-host。

大部分情况下只运行相关 real-host。只有宿主影响广泛、无法合理界定，或用户明确要求
时才运行全量，并说明范围和原因。已通过的检查不因准备提交而重复；新改动、失败或
未解决问题才需要扩大或重复验证。

## 必跑检查与开发依赖

本地工具名来自忽略的 `project.conf`；首次运行前复制 `project.conf.tpl` 并按机器调整。
从仓库根目录运行：

```text
git submodule update --init --recursive
luajit test/run.lua
emmylua_check .
```

Lua suite 依赖根目录固定版本的 `mpv-luatest` 开发子模块。`test/run.lua` 只负责项目
适配；共享 runner/assertion/stub 的更改归独立子模块。更新 gitlink 前先独立验证依赖，
再运行 elxosc 回归；不要把公共运行器逻辑复制回项目。子模块版本必须能被其他 checkout
取得，发布与更新步骤见 test README。

相关 Python/real-host 示例：

```text
uv run --group test python -m pytest -q test/test_runner.py
uv run --group test python -m pytest -q test/real_host/test_player_extensions.py
```

## Lua suite 与离线职责

运行器自动发现 `test_*.lua`，递归进入名称以 `test` 开头的组目录；`real_host` 和 fixtures
不进入 Lua suite。按相对路径排序，筛选器各段按字面子串匹配，可省略 `test_` 和 `.lua`。
例如 `player/layout` 选择 `test_player/test_layout.lua`；单段可匹配任意深度的组或文件。
默认显示失败和总结，`-v` 显示完整记录；空匹配、非法参数和失败断言返回非零。

测试按行为和所有权分层：

| 分区 | 回归职责 |
| --- | --- |
| foundation / painting / text | 值语义、复制、非法边界、Canvas/TextLayout/Paragraph 契约 |
| layout / render | 约束代数、有限布局、变换/clip、绘制记录、命中逆映射和 dirty 分类 |
| animation / scheduler | 假时钟、帧阶段、重复/反向、监听替换和资源清理 |
| widgets / material | Widget/Element 复用、State rebuild、Builder context、输入、样式选项不变性和 collector identity |
| framework owners | BuildScope/inactive/finalize、PipelineOwner、Binding singleton/role identity、owner 隔离及 Key registry 清理 |
| define | sandbox、scope 首次成功 payload、transaction 失败隔离、延迟 module publish、Slot 冲突和 bind 顺序 |
| player | snapshot/Store/Scope、Main 布局和扩展按钮、Timeline、AutoHide、capability、seek 和资源生命周期 |
| logical overlay / navigation | 单 Entry owner、mounted builder、opaque/maintain_state、paint/input eligibility、Route reconciliation、结果及 dispose 顺序 |
| host stub / ASS | 帧循环接线、事件编码/顺序、输入 section、presenter 重试/去重/clear、resolution 与 shutdown |

公共 API 必须有消费者加载与 aggregate/direct-module identity 回归，不能只验证内部字段。
框架隔离测试只 staging lib 与 elxlib，拒绝 player/Define/mp 导入，覆盖 mount、paint、input
和 dispose。canonical require、受支持 alias、移除路径、精确多级 import 和包保护分别验证。

所有 RenderObject 必须在约束内报告有限尺寸。无限/非法尺寸、零/负缩放、非法选项、
caller-owned 配置修改、结构性变化与 paint-only 变化都需要边界或 dirty 回归。
`test_constraints_examples.lua` 保留固定 400×670 约束示例的完整 ASS 快照。

### Provider 和数据更新

- inherited Provider 按精确运行时类型查找最近祖先；监听式 `of`/`maybe_of` 和非监听式
  `read`/`maybe_read` 分别验证依赖行为。
- State 首次挂载及依赖更新经过 `did_change_dependencies`；覆盖
  `update_should_notify == false`、依赖重查和 unmount 清理。
- `init_state`/`dispose` 拒绝监听式 lookup，允许非监听式读取。
- snapshot/selector 更新通过 State/Provider/setter 和既有 dirty 管线，不重新执行扩展
  源码或重复注册 class、observer、timer、host callback。
- LuaJIT weak-key 表不具备 ephemeron 语义；GC 回归分别验证丢弃视图可回收、活视图
  持有 backing 数据，以及 Store replacement 和 mount/dispose 后资源释放。

### 应用、输入和呈现

- Define/Slot 是唯一初始化内容边界；验证四个入口、ordered append、冲突诊断及
  mounted Widget 不被直接编辑。Main 隐藏不卸载 Extension/Page State。
- OverlayEntry 的 visible/opaque/maintain_state、generation plan 和 reconciliation
  分别验证挂载、绘制及输入资格；Navigator Page class/key、重复 key、Popup barrier、
  pop/result/dispose 顺序和空 root ESC 透传保持覆盖。
- pointer regions 随布局、paint-only transform、clip、viewport、visibility 和树变化更新；
  普通 mouse move 复用 RegionSnapshot，不因几何变化对静止鼠标合成 hover。
- 覆盖 section callback 复用、启用顺序、指定 disable、区域空隙透传和双击拦截。
- structured PointerEvent/KeyEvent 的字段、复制和边界独立验证；legacy payload、
  DispatchResult、多按钮 capture、卸载/root replacement/shutdown cancel 及旧 up 清理
  不能因 tooltip 的 hover observer 而改变。
- AutoHide fade 开始清理 tooltip/thumbfast，真实 move 恢复；淡出 capture、hidden
  eligibility、nested policy、controller replacement 和 dispose 分别验证。
- Timeline 普通点击仅 seek；实际拖动才持有 pause，release/cancel、能力失效和卸载
  恢复本次持有的播放状态。seek 回调在同一次操作中保持身份，预览与边框坐标一致。
- 单 Canvas/Presenter 的事件行边界、顺序、提交失败重试、成功后缓存、空 ASS clear、
  resize 和幂等 shutdown 保持覆盖。多 host overlay、focus 和 IME 不能据此宣称已支持。

## EmmyLua

生产目录要求零诊断。测试可以针对 `std.class` 模型或第三方 stub 使用靠近代码的局部
suppression；生产文件不得用文件级 suppression 掩盖问题。类型前缀和运行时路径分别
验证，collector 类型只声明实际成员。

生产分析范围排除 ignored 临时内容和独立编辑器 meta：

```text
emmylua_check . --warnings-as-errors -i '**/tmp/**,**/meta/**'
```

meta 生成一致性、独立扩展分析和编辑器提示属于单独验证范围，不用生产诊断结果替代。
实际执行时要明确所选范围，不能把未运行的检查写成通过。

## Real host

`test/real_host/` 使用真实 mpv/mpv.net、隔离 config、临时 staging 和
ownership-bounded cleanup。fixture 先 IPC quit，再用自有 Job Object/process group
兜底；禁止按进程名结束 mpv。只在所需宿主确实不可用时 skip。

真实输入回归必须经过 mpv 按键解析、section 选择和生产路由。用 script-message 直调
RenderOwner 不能单独证明默认绑定不穿透。交互区域的 `mbtn_left_dbl` 应被消费，
无 interactive area 的背景继续执行用户绑定；坐标缩放、resize、区域空隙和 capture
需要按目标宿主验证。

real-host fixture默认quiet：无console、最小化、不主动获取前台。App输入回归以staged
测试桥接向生产MpInput发送坐标和事件，逐事件确认，物理mouse observer和位置刷新只在
staging隔离；活动、capture、dispatch和真实frame/presenter保持。原生section与key解析
另用mpv IPC验证；直接事件不能替代默认绑定优先级证明。背景回退记录调用，不切fullscreen。
文本resize在桌面外以非激活方式恢复自有VO窗口并等待OSD匹配，保留native/libass。
自动用例不使用桌面鼠标。明确要求真实鼠标的工具才显式quiet=False，操作限自有窗口并
恢复位置；这类可见工具应单独运行。通知、焦点和窗口遮挡属于实际执行记录，不能把
环境失败写成产品通过。

Demo 检查覆盖注入按钮、Page/Popup、ESC、结果和 State 保留；thumbfast 检查使用协议
peer 验证请求、clear 和恢复，不代表外部解码图像的像素验收。自动化生命周期/路由
检查与人工视觉、桌面按钮操作和高刷新率手感需要分别记录。

### 文本测量与性能证据边界

共享hover行为工具用相同scene/直接PointerEvent与逻辑时间，推进生产MpFrameClock /
Scheduler / App管线。仅Lua记录外部边界，real-host提交真实ASS并独立验证最终栅格bounds；
原生mouse/media observers及key callback只在隔离工具中屏蔽。它核对实际帧、prepared文字/
绘制位置、输入路径/区域/动作及owned cleanup，也不代替真实绑定路由。计时、类计数、
选定表创建/访问、function/line采样与GC控制独立运行，计时轮不执行重oracle。
estimate-pair保证两端相同宽度回退；native请求在measure_ass边界严格record/replay，未知/
剩余请求失败。paced模式让出真实宿主执行机会并检查选定frame的bounds，可见帧/scanout
仍为未观测。phase计时包括探针开销；inclusive/exclusive记录与baseline轮分别解释。
逻辑240Hz和batch更新次数不能称屏幕FPS，source事件/heap净增长不等于物理分配。

能直接发送事件的host用例使用quiet fixture（最小化或屏幕外、不抢焦点、Windows无console），
保持真实VO/ASS/libass。需要截图/真实鼠标/人工视觉时显式用可见配置；quiet结果与可见
窗口测量环境分别记录，不能将最小化的呈现行为推断为桌面实际可见帧。工具用法见tools README。

真实 libass bounds 证明 ASS 可被宿主接收，并给出 renderer image rectangle；它不等于
精确 glyph ink、逻辑 advance、baseline/ascent/descent 或光学居中。
ASS 文本探针结合生产编码、viewport resize、字体变化及虚拟分辨率验证定位跨度；
字体文件参考只能支持相应字形/字体范围的结论，复杂 script 不能据此宣称精确逻辑宽度。
多行回归保留原文范围/空白/支持的组合边界，检查line-limit截断和最终ellipsis整串宽度。
真实宿主以相同字形行的bounds坐标差验证逻辑行推进、九anchor、视觉offset和正scale；
空行无event但保留推进，clip bounds位于受约束盒内。事件数/payload与冷热layout、paint、
compute_bounds分别记录；compute_bounds耗时不等同presenter提交或像素呈现。
人工文本预览标明独立预期、原文/参数、约束盒、自然段落范围、行号/逻辑行中心和paint anchor。
溢出对照保持相同原文与约束；辅助线不能称font baseline或精确字形边界，裁剪与原文截断分别说明。

测量服务与 CLI 分别覆盖固定实例复用、空画面、错误、cleanup、外部输入和结果 schema。
报告需记录源码/字体版本、实际 OSD、请求分辨率和 payload hash；未暴露的宿主版本
保留为空，失败或超时不得编造 bounds。

性能工具与行为测试分开：行为回归检查输出等价和失效次数，不断言机器耗时。benchmark
比较需要相同场景、源码、runtime、sampling 和输出合同，明确 warmup、统计方法、GC/JIT
及系统负载限制。ASS 提交延迟不包含像素呈现、scan-out 或外部 thumbfast。
短期进程内存变化包含 decoder/GPU/libass 等分配，不能证明长期没有原生泄露。
持续文本压力分别触及条目数与原文/key字节上限，并跨环境替换检查旧layout回收、
其他App存活和自有ID移除。记录实际工作量与抽样GC干预，不把目标速率当宿主帧率。

可共享的历史数据保存在 `dev/benchmark/` 和 `dev/measure/`，解释时使用各报告的代码版本
及适用范围，不作为当前代码的验收结果。工具方法和报告入口由 tools README 维护。

## 改动后的检查顺序

先运行受影响的 focused suite，再运行完整 Lua 和生产 EmmyLua；涉及宿主行为时选择
相关 real-host。纯文档整理检查差异、链接、当前契约和必要历史信息的保全即可。
提交前检查 `git diff --check`、`git diff --stat`、`git status --short`，只记录实际执行的
命令、版本、结果和未测范围。
