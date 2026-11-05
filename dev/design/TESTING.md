# 测试与验证

本文是测试入口和回归范围的当前说明。所有命令从仓库根目录执行。

## 当前基线：离线 ASS 测量（2026-11-06）

完整 Lua suite **2290 checks passed**、EmmyLua **No issues found**。新增
`test_ass_measure.lua` 覆盖 host 错误/空结果、非法边界、分配与清理失败；分层 guard
确认 App/framework 不加载离线工具。CLI schema/failure **11 tests**、新增真实宿主
**2 tests**。最终完整 Python **39 passed in 24.74s**（real-host **14**、runner **14**、
测量 CLI **11**），无 skipped；之前完整运行 **39 passed in 25.27s** 后，只加强坐标断言
和报告元数据，最终复验均通过。

```text
luajit test/run.lua
emmylua_check .
uv run --group test python -m pytest -q test/real_host test/test_runner.py test/test_ass_measure_cli.py --tb=short
uv run --group test python tools/ass_measure.py --repeats 5 --output dev/measure/ass-measure-2026-11-06.json --markdown dev/measure/ass-measure-2026-11-06.md
```

测量工具 schema/exit codes 见 [tools/README.md](../../tools/README.md)。正式结果为
[完整 JSON](../measure/ass-measure-2026-11-06.json) 和
[对照表](../measure/ass-measure-2026-11-06.md)：六个 Widget→RecordCanvas→ASS 样例，
每个重复五次，全部 `ok` 且稳定；logical box 与宿主 bounds 并列，保留 payload/请求
哈希及测量文件哈希。数据基线 `c585d36` 加本轮工具，report 的 worktree_modified=true
明确未把未提交工具冒写为该旧提交已有。字体文件 hash 也在报告中。

环境为 Windows/AMD64、mpv `v0.41.0-1011-g182fa6ca4`、LuaJIT `2.1.1787944725`、libass
compiled/runtime `0x1705000`（日志来源）、FriBidi 1.0.16、HarfBuzz 14.4.0。request 为
640×360，实际 OSD 为 2275×1280；bounds 属于请求坐标空间。字体实际为 ArialMT、CJK
fallback MicrosoftYaHeiUI、仓库 MaterialSymbolsRounded-Regular；工具显式指定字体目录。

先前试跑暴露并修正了：移除命令缺必填 data 导致 cleanup_error；OSD 初始化前第一条
bounds 不稳定；空 payload 返回空表。最终按协议传 data=''、等待非零 OSD 稳定 250ms、
测量期间检查 OSD 未变化，空表为 `empty` 且没有捏造零矩形。不同分辨率矩形及 clip
有 real-host 回归；bounds 会包含渲染图像 padding（1280×720 请求曾得到右边界
147.9375，对应 path right=140），不能当作精确 ink/路径或光学中心模型。

无宿主/无 API 返回 unavailable；命令、IPC timeout、宿主退出、清理失败写明 error。
Lua 同步请求不可抢占；CLI 各 wait/IPC deadline 和 fixture 自有进程 cleanup 分开，超时
不重发测量。不改变 production App、Presenter、TextLayout、Widget 输入或 Define。
Linux 未运行、屏幕像素/scan-out 未测；不据此升级文本估算或承诺跨平台相同 bounds。

## 历史基线：默认播放器收口（2026-11-05）

完整 Lua suite 为 **2241 checks passed**；`emmylua_check .` 为 **No issues found**。
focused `player_layout` **162**、`main_layout` **90**，新增回归覆盖 AutoHide fade-start 清理、
保留 State/controller replacement/nested AutoHide、capability loss/dispose、重显恢复，以及
共享 host 像素矩形的白色边框/黑色外描边、scale、零宽度和 static ASS 输出。

```text
luajit test/run.lua
emmylua_check .
uv run --group test python -m pytest -q test/real_host test/test_runner.py --tb=short
```

最终完整宿主/runner 为 **26 passed in 20.43s**（real-host **12**、runner CLI **14**），
使用当前生产入口、Demo 默认注入且初始关闭。新增 thumbfast 协议对端测试保持真实鼠标
静止，验证 AutoHide 超时只发一次 clear、新 move 恢复、离开再次清理；它不运行外部
thumbnail 解码器。Lua Record/ASS 检查边框几何和样式，不代替实际图像的像素对照。

本轮复验曾为 **25 passed, 1 failed**：Demo 首次点击未进入 elxosc down/up 路由。临时
staging 日志及 `input-bindings` 显示内置 OSC 的 `MBTN_LEFT` 优先级 67 高于 elxosc 的
最高 66；`--load-scripts=no` 不关闭内置 OSC。fixture 增加 `--osc=no` 后，打开/关闭/重开
诊断和完整套件均通过。点击驱动保持原生定位 + IPC keydown/keyup，不靠重试掩盖失败；
诊断脚本已删除。既有 hover benchmark 已显式传入 `--osc=no`，历史数据无需替换。

用户最新整体外观审阅认可，加最后两项 thumbfast 修正和自动证据，支持当前默认播放器
范围收口；未把所有配置、分辨率或动作写成人工通过。Windows/mpv.net 已运行，Linux
未运行；原生桌面按钮逐项操作及外部 thumbfast 像素呈现未在本轮另外测量。240 Hz 播放
更新失效成本和完整兼容仍为后续方向，以下历史基线及测量结果保留原始语境。

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

### 真实播放器 timeline hover benchmark（2026-11-05）

生产代码基线为 `feaaff3`。入口为 `tools/benchmark_real_player_hover.py`，复用 real-host
fixture 的隔离配置和进程清理，Windows 通过自有窗口的原生鼠标输入测量。仅在临时 staging
入口载入 `tools/player_hover_probe.lua`；工作区入口、生产输入方式和用户配置不被修改。
`mouse_move` 是 staging 候选实验：移动走 forced native binding，仍保留 hover-leave/capture
清理。默认 `observe` 继续使用生产 `mouse-pos` observer。

```text
uv run --group test python tools/benchmark_real_player_hover.py --seconds 4 --output dev/benchmark/player-hover-real-2026-11-05.json
uv run --group test python tools/benchmark_real_player_hover.py --rates 240 --modes observe --debug true --seconds 4 --output dev/benchmark/player-hover-real-debug-2026-11-05.json
```

可通过 `ELXOSC_MPV_BINARY` 或 `--host` 选择真实宿主，需安装 ffmpeg。正式结果见
[关闭调试的八场景报告](../benchmark/player-hover-real-2026-11-05.json) 和
[默认调试配置的补测](../benchmark/player-hover-real-debug-2026-11-05.json)。环境为
Windows/x64、mpv.net/mpv `v0.41.0-1011-g182fa6ca4`、嵌入式 LuaJIT `2.1.1787944725`；
生成 1280×720、60 fps H.264 testsrc2 媒体，无音频，软件解码、GPU VO。实际 viewport
为 2276×1280，Main scale 1.5，display-fps 240.003，frame clock delay 4.167 ms。
Demo 注入开启、面板关闭，外部 thumbfast 在隔离环境中为 `unavailable`。

每场景预热 1 秒，采样 4 秒，随后留 100 ms 排空事件。驱动实际达到 59.98～60.00 Hz
和 239.94～240.00 Hz；驱动记录 `SetCursorPos` 前的 QPC 时间，移动调用 P50 约
0.03～0.05 ms。早期逐次枚举 Windows 进程的驱动只能达到约 100 Hz，已修正为启动时
校验 ownership、逐次校验 HWND PID 和持有的进程 handle；早期试跑不作为 240 Hz 证据。

延迟和阶段统计只计每个 input sequence 的首次 tooltip 提交，播放引起的相同指针重复
重绘不重复计入延迟；失效次数则计全部 tooltip 绘制帧。P50/P95 使用 nearest-rank，
输入次数可能包含采样边界的一次事件，Hz 按驱动实际首末时间计算。

| Hz | 输入 | 状态 | debug | 输入次数 | tooltip 提交 Hz | Lua 帧 P50 / P95 ms | 输入→提交 P50 / P95 ms |
| ---: | --- | --- | --- | ---: | ---: | ---: | ---: |
| 60 | observe | paused | false | 241 | 60.5 | 2.045 / 5.958 | 4.778 / 8.382 |
| 60 | observe | playing | false | 188 | 45.7 | 9.700 / 30.920 | 10.708 / 32.678 |
| 60 | mouse_move | paused | false | 241 | 60.5 | 1.991 / 6.143 | 4.302 / 8.261 |
| 60 | mouse_move | playing | false | 241 | 46.7 | 4.275 / 27.609 | 6.066 / 30.767 |
| 240 | observe | paused | false | 866 | 200.4 | 2.043 / 7.935 | 3.589 / 10.080 |
| 240 | observe | playing | false | 330 | 73.1 | 9.507 / 49.945 | 10.120 / 50.958 |
| 240 | mouse_move | paused | false | 770 | 167.9 | 2.014 / 7.718 | 3.755 / 9.823 |
| 240 | mouse_move | playing | false | 959 | 77.8 | 9.847 / 31.098 | 10.666 / 34.215 |
| 240 | observe | paused | true | 768 | 181.9 | 1.876 / 7.686 | 3.062 / 9.370 |
| 240 | observe | playing | true | 320 | 72.3 | 9.994 / 42.367 | 10.817 / 43.361 |

当前 `main.lua` 默认 `debug_enabled = true`。该补测的 OS 移动→提交 P50/P95 为
暂停 **4.608/11.857 ms**、播放 **12.041/45.408 ms**；输入→提交从暂停约 3 ms 升到
播放约 11 ms。debug 两组是独立运行，不能将其差异解释为开启日志带来性能收益。

| 240 Hz 阶段 mean ms | observe paused | observe playing | mouse_move playing |
| --- | ---: | ---: | ---: |
| build | 0.014 | 2.146 | 2.180 |
| layout | 0.003 | 1.030 | 0.802 |
| input regions | 0.333 | 4.483 | 3.862 |
| paint / ASS | 2.198 | 2.465 | 2.490 |
| present | 0.107 | 0.113 | 0.131 |

上表均为 debug=false。所有暂停场景的 build dirty/layout/input invalidation 次数均为
**0**，确认 tooltip 移动的 paint-only 修正有效；播放的四组分别出现 **183/178/177/167**
次 build、layout 和 region generation 更新，默认调试补测播放为 **178** 次。
源码链路也一致：`PlayerScopeState` 订阅整个 Store，`PlayerProvider` 按 snapshot identity
通知，`Main` 监听 Provider 并重新构建 `PlayerLayout`。播放时持续更新的数据重新触发
组合、布局和输入区域刷新，输入区域阶段是本次播放样本中最大的平均成本。

`mouse_move` 在 240 Hz 播放场景收到 959/960 次移动，而 observer 收到 330 次，表明事件
合并值得继续调查；但它仍只产生约 78 Hz 的 tooltip 更新，Lua 帧 P50 接近 10 ms，
超过 240 Hz 的 4.167 ms 帧间隔，暂停场景也没有一致收益。因此下一步先评估收窄
PlayerProvider 依赖、复用稳定控件/callback/style、让进度数据更新只失效必要节点，再
用相同真实场景验证；本次不更换生产输入方式或新增框架 boundary API。

这些是单机、单次短采样，probe 包装、GC、视频播放和 OS 调度都会影响尾部耗时。
结束点为 ASS overlay 提交，包含 Lua 帧和 presenter 调用；不包含 libass 像素呈现、显示
scan-out、外部 thumbfast，也未直接运行 ModernX。Linux 未运行，完整小树/深树/多子节点
benchmark 矩阵及优化前后等价输出对照仍未完成。

工具加入后的 `emmylua_check .` 为 **No issues found**。完整宿主复验曾为 **24 passed,
1 failed**，失败是 Demo 首次打开/关闭的全局原生按钮注入。隔离日志确认坐标、区域和
焦点正确，延长原生按下/释放间隔也未完全消除不稳定。最终 `WindowInput.click` 使用
真实鼠标定位和 mpv IPC `keydown/keyup`，仍经过 mpv 区域选择和生产 `MpInput` 路由；
预留 300 ms 移动处理时间、200 ms 按下时间，并在 finally 中释放按键。该自动检查不代表
桌面原生按钮点击的最终人工验收。高频 benchmark 只调用原生 `move`，不受按钮传输影响。

最终完整 `test/real_host test/test_runner.py --tb=short`：**25 passed in 16.46s**
（real-host **11**、runner CLI **14**）。Lua 生产代码自 `feaaff3` 后未改动，完整 **2202**
checks 的提交前结果继续有效；本轮新增探针的完整 EmmyLua 检查为零诊断。

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
