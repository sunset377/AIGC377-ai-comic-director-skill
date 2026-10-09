# LibTV 适配

用于 `libtv-prepare`、`generate` 和涉及画布的 `review`。LibTV 操作通过官方 `libtv` CLI 完成，不自行构造网页接口请求。当前 CLI 帮助优先于本参考。

## 只读预检

先确认工具和登录，再读取远程结构：

```powershell
libtv --version
libtv account info
libtv workspace list -s 20
libtv project list
libtv model search --type image
libtv model search --type video
libtv model <name>
```

`<name>` 必须替换为检索结果中全等且唯一的 `modelKey` 或 `modelName`。完整 schema 返回前不写模型参数。

## 远程写入前置

只有当前任务状态包含 `PROJECT_WRITE_GRANTED`，才能创建或绑定工作区/画布、上传素材、创建节点、改连线或写提示词。先读取现有对象，避免重名和重复上传。

```powershell
libtv workspace create "客户确认的项目名" -d "AI漫剧制作"
libtv workspace use <workspaceId>
libtv project create "客户确认的画布名"
libtv project use <projectUuid>
libtv upload "资产节点名" -f "客户确认的本地文件"
libtv node create "镜头-01" -t video -s "model=<modelKey>" --prompt "已批准的最终提示词"
libtv node "镜头-01" --left "角色参考" --left "场景参考"
```

实际参数必须以 `libtv <子命令> --help` 和模型 schema 为准。命令中的名称、ID、路径和提示词必须来自当前项目文件，不复制示例字面值。

## 节点引用

提示词中的 `{{Node "name"}}` 只引用已连接到当前节点的上游节点。名称不唯一或需要稳定追踪时使用 nodeKey。资产清单保存上传状态和远程 nodeKey；节点图保存模型、入边、提示词文件和参数来源。

## 生成前回读

配置后读取画布摘要、节点列表和每个目标节点，核对：工作区与画布、节点类型、模型、参数、入边、资产顺序、提示词保存内容以及空生成记录。全部一致时写入 `READY_FOR_REVIEW`，不把生成命令放进默认交付。

## 运行与复核

运行生成必须先满足 `PAID_RUN_GRANTED`。授权缺失时停止。生成后保存真实 CLI 输出、节点状态和资源地址，检查连续性、动作、声音和画面；失败后回到 `READY_FOR_REVIEW`，没有 `RETRY_GRANTED` 不再次运行。
