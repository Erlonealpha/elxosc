# 设计文档索引

`dev/design/` 描述当前架构、行为契约、不变量、技术理由和支持边界。当前设计从总览
开始，再进入负责具体决策的方向文档；代码位置以仓库根目录为基准，链接相对当前文件：

- [DESIGN.md](DESIGN.md)：当前架构、公共契约和决策规则。
- [ARCHITECTURE.md](ARCHITECTURE.md)：分层、依赖和三棵运行时树。
- [RENDERING.md](RENDERING.md)：约束、RenderObject、文本、ASS、变换和动画。
- [INPUT.md](INPUT.md)：输入区域、section、默认行为、事件和 capture 契约。
- [WIDGETS.md](WIDGETS.md)：Widget/Element/State、控件、key 和 Define 绑定。
- [HOST.md](HOST.md)：mpv 边界、帧循环、输入和 Define 协议。
- [PLAYER.md](PLAYER.md)：播放器组合、Main、扩展区域、数据更新和 OverlayEntry。
- [TESTING.md](TESTING.md)：离线测试、静态检查和真实宿主验证。
- [ROADMAP.md](ROADMAP.md)：能力缺口、依赖、长期方向和明确非目标。

实施阶段、调查过程、逐轮测试结果和人工反馈由本地规划记录承担，设计文档不维护
这些进度。稳定结论必须写回负责的方向文档；公开契约和链接不依赖本地计划目录。

`old/` 保存迁移前的阶段记录、Flutter 约束对标记录和渲染动画记录。它们保留
历史上下文，不是新实现的 API 依据。代码规范和贡献流程分别见根目录
`codestyle.md` 与 `AGENTS.md`。
