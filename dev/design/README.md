# 设计文档索引

本文档中的代码路径均相对于仓库根目录；同目录 Markdown 链接使用相对路径。

- [DESIGN_PATH.md](DESIGN_PATH.md)：架构地图与阶段性交接记录。
- [DESIGN.md](DESIGN.md)：Flutter 对照和扩展协议的历史设计推演。
- [DESIGN_CONSTRAINTS.md](DESIGN_CONSTRAINTS.md)：约束模型修复及示例测试记录。

旧记录中的测试数量、实现清单和未来阶段不是实时状态；以当前代码和实际测试
输出为准。代码规范以根目录 `codestyle.md` 为准，贡献流程见 `AGENTS.md`。

## 下一阶段：扩展声明系统（第一切片已实现）

其他脚本应能向预设区域贡献普通 Widget，也能声明完整页面。宿主使用常规布局
控件规定区域及约束，底层不得硬编码“工具栏按钮”或特殊页面 RenderObject。
区域挂载、页面注册与 mpv 消息传输分层处理，避免让 MpDefine 承担布局职责。

当前第一切片已为 `BindRegistry` 增加可选的 `scope_id` 所有权，并支持在挂载前
撤销某个 scope 的待处理绑定；旧的三参数 `bind(id, widget, opts)` 调用保持兼容。
它只管理声明记录，不回滚已经写入 Widget 树的结果，也没有修改 mpv 消息协议。

Define 仍然只用于启动阶段构建一次初始 Widget 树：同一个 `scope_id` 的重复
`define` 会报告警告并忽略后续 payload；同一 scope 对同一 target 的多次 bind
仍允许，但不额外引入优先级。不同 scope 的冲突继续由 target 类型和 bind 操作
决定。没有运行时 scope 关闭、Widget 树重建或导航 API。

下一切片仍需明确命名、顺序、冲突与完整生命周期，再调整现有 define/bind 协议。
页面定义与导航状态分开；未来 Navigator 2.0 风格方案由声明式页面列表驱动，
默认主页面也走相同页面模型。当前不新增未经实现验证的导航 API。
