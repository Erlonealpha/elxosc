# 设计文档索引

`dev/design/` 中的文档均以仓库根目录为路径基准。当前设计从总览开始，再进入
负责具体决策的方向文档：

- [DESIGN.md](DESIGN.md)：当前架构、公共契约、验证基线和决策规则。
- [ARCHITECTURE.md](ARCHITECTURE.md)：分层、依赖和三棵运行时树。
- [RENDERING.md](RENDERING.md)：约束、RenderObject、文本、ASS、变换和动画。
- [WIDGETS.md](WIDGETS.md)：Widget/Element/State、控件、key 和 Define 绑定。
- [HOST.md](HOST.md)：mpv 边界、帧循环、输入和 Define 协议。
- [TESTING.md](TESTING.md)：离线测试、静态检查和真实宿主验证。
- [ROADMAP.md](ROADMAP.md)：已完成能力、后续方向和明确非目标。

`old/` 保存迁移前的阶段记录、Flutter 约束对标记录和渲染动画记录。它们保留
历史上下文，不是新实现的 API 依据。代码规范和贡献流程分别见根目录
`codestyle.md` 与 `AGENTS.md`。
