# 测试与验证

本文是测试入口和回归范围的当前说明。所有命令从仓库根目录执行。

## 必跑检查

WSL checkout 的命令：

```text
/mnt/e/lua/local/LuaJIT/bin/luajit.exe test/run.lua
/mnt/f/Tools-soft/emmylua/emmylua_check.exe .
/mnt/c/Windows/system32/cmd.exe /d /c "uv run --group test python -m pytest -q test/real_host"
```

Windows 开发环境对应：

```powershell
E:\lua\local\LuaJIT\bin\luajit.exe test\run.lua
emmylua_check.exe .
uv run --group test python -m pytest -q test/real_host
```

当前基线（2026-10-12）：**1036 Lua checks passed**、EmmyLua **No issues found**、
真实 mpv.net **8 passed**。测试数量变化时，应在本文件和主设计文档同步更新。

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

## EmmyLua

框架生产目录要求零诊断。测试文件可以针对 `std.class` 模型和第三方 host stub
使用靠近代码的局部 suppression，但不能在生产文件用文件级 suppression 掩盖错误。

## Real host

`test/real_host/` 使用隔离 config、临时 staging 和 ownership-bounded cleanup，验证
真实 mpv/mpv.net 能加载脚本、接收 overlay、处理输入并产生非空 bounds。只能在所需
host 确实不可用时 skip；禁止使用按进程名杀 mpv 的清理命令。

真实 libass bounds 证明事件可被宿主接收，不等价于精确字体 ink bounds 或光学居中
证明；精确逻辑仍由离线 Canvas/Paragraph 测试覆盖。

## 改动后的检查顺序

先运行受影响的 focused suite，再运行完整 Lua suite、EmmyLua 和 real-host suite。
提交前检查 `git diff --check`、`git diff --stat`、`git status --short`，并在提交
说明中只写实际执行过的命令。
