---
name: ai-comic-director
description: Use when a user asks Codex to develop an original AI 漫剧, direct an episode, prepare or review a LibTV canvas, or explicitly run approved AI comic-drama generation.
---

# AI 漫剧导演 Skill

把原创创意转化为可复核的漫剧导演包，并在获得对应授权后配置 LibTV。对剧本、资产、模型、远程写入、生成和完成状态保持诚实。

## 先读取与路由

每次运行先读取[需求与路由](references/intake-and-routing.md)，选择一个模式：

- `develop`：建立项目卡、世界观、角色连续性档案、季纲和分集结构。读取[故事引擎](references/story-engine.md)与[连续性档案](references/continuity-bible.md)。
- `episode`：完成一集剧本、分镜、提示词和资产清单。继续读取[镜头与动作设计](references/shot-and-motion-design.md)、[提示词合同](references/prompt-contract.md)和[质检合同](references/qc-contract.md)。
- `libtv-prepare`：把已批准导演包配置进 LibTV，止于 `READY_FOR_REVIEW`。读取[LibTV 适配](references/libtv-adapter.md)与[权限和停止线](references/permissions-and-stopping.md)。
- `generate`：仅在当前用户消息明确授予指定画布、节点、模型和最大运行次数后运行。先读取[权限和停止线](references/permissions-and-stopping.md)与[LibTV 适配](references/libtv-adapter.md)。
- `review`：检查真实生成结果，记录连续性失败、证据和最低成本修复方案。读取[质检合同](references/qc-contract.md)及与失败相关的导演参考。
- `full`：依次执行 `develop → episode → libtv-prepare`。该模式仍止于 `READY_FOR_REVIEW`，不自动进入 `generate`。

## 共同执行合同

1. 每个项目和每次运行使用新目录，不覆盖旧导演包、素材、报告或远程记录。
2. 未知事实写为 `待确认`。不得虚构模型可用性、参数、价格、素材权利、远程写入结果、生成结果或发布状态。
3. 角色、服装、道具、地点和时空状态以唯一连续性档案为权威来源；镜头文件引用它，不另造冲突版本。
4. LibTV 模型和字段必须来自当前 `libtv model search` 与完整模型 schema。实际 CLI 帮助与参考不一致时，以当前 `libtv --help` 和子命令帮助为准。
5. 安装、登录、读取账号、准备画布、运行生成、重试、删除和发布是相互独立的权限。前一项不自动授权后一项。
6. 只有观察到对应文件、命令结果或远程回读证据后，才能声明完成。没有运行的外部操作标记为 `NOT_RUN`。

## 默认交付

导演任务默认交付项目卡、世界观与季纲、角色连续性档案、分集剧本、分镜表、资产清单、LibTV 节点图和 QC 报告。`libtv-prepare` 与 `full` 的默认最终状态固定为 `READY_FOR_REVIEW`。
