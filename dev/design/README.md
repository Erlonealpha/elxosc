# 设计文档索引

本文档中的代码路径均相对于仓库根目录；同目录 Markdown 链接使用相对路径。

- [DESIGN_PATH.md](DESIGN_PATH.md)：架构地图与阶段性交接记录。
- [DESIGN.md](DESIGN.md)：Flutter 对照和扩展协议的历史设计推演。
- [DESIGN_CONSTRAINTS.md](DESIGN_CONSTRAINTS.md)：约束模型修复及示例测试记录。

旧记录中的测试数量、实现清单和未来阶段不是实时状态；以当前代码和实际测试
输出为准。代码规范以根目录 `codestyle.md` 为准，贡献流程见 `AGENTS.md`。

## 下一阶段：扩展声明系统（尚未实现）

其他脚本应能向预设区域贡献普通 Widget，也能声明完整页面。宿主使用常规布局
控件规定区域及约束，底层不得硬编码“工具栏按钮”或特殊页面 RenderObject。
区域挂载、页面注册与 mpv 消息传输分层处理，避免让 MpDefine 承担布局职责。

先明确命名、顺序、冲突、scope 所有权与生命周期，再调整现有 define/bind 协议。
页面定义与导航状态分开；未来 Navigator 2.0 风格方案由声明式页面列表驱动，
默认主页面也走相同页面模型。当前不新增未经实现验证的导航 API。
