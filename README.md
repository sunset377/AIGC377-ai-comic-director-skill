# AI 漫剧导演 Skill

把原创故事转化为可执行、可复核的漫剧导演包：项目卡、角色连续性档案、分集剧本、分镜表、资产清单、提示词、LibTV 节点图与 QC 报告。

[在线演示](https://sunset377.github.io/AIGC377-ai-comic-director-skill/) · [安装说明](#安装) · [安全边界](#安全边界)

## 能做什么

- 从创意建立世界观、角色档案、季纲和分集结构。
- 为单集输出时间轴分镜、画面/运动提示词和资产清单。
- 在明确授权后准备 LibTV 画布，并回读节点与参数作为证据。
- 审查生成结果的连续性、时长、素材权利和最低成本修复方案。

默认终点是 `READY_FOR_REVIEW`。安装、登录、读取、远程写入、付费生成、重试、删除和发布始终是不同权限。

## 在线演示

演示页允许粘贴或选择本地 `.txt` / `.md` 剧本，立即生成结构化分镜预案和资产清单。全部处理在浏览器本地完成，不上传文件、不调用模型、不消耗额度。

## 安装

下载仓库并在项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\installer\install.ps1
```

安装器默认写入 `$CODEX_HOME\skills`；未设置 `CODEX_HOME` 时写入 `%USERPROFILE%\.codex\skills`。已有同名 Skill 时会停止，只有显式加入 `-Upgrade` 才会备份并升级。

安装后新开一个 Codex 对话，可以这样开始：

```text
使用 $ai-comic-director，把这段原创故事整理成角色连续性档案、分集剧本、分镜表和资产清单；不要连接账号，不要上传，不要运行付费生成。
```

可选的 LibTV 依赖安装属于独立操作：

```powershell
powershell -ExecutionPolicy Bypass -File .\installer\install.ps1 -InstallLibTV
```

该选项只从脚本限定的官方 HTTPS 地址读取当前安装信息。登录必须由用户本人完成。

## 安全边界

- 未知事实写为 `待确认`，未执行的外部动作写为 `NOT_RUN`。
- 没有真实文件、命令结果或远程回读证据，不声明完成。
- 不把安装或登录视为付费生成授权。
- 不读取、复制或输出 Cookie、Token、验证码等凭据。
- 用户应确认人物、素材、字体、商标与参考作品的使用权。

## 仓库结构

```text
skill/ai-comic-director/  Codex Skill、参考规则、模板和项目脚本
installer/                Windows 安装、检测和可恢复卸载脚本
docs/                     无后端的 GitHub Pages 演示
examples/                 原创示例需求与预期交付清单
guide/                    快速开始与常见问题
tests/                    结构、安全边界与演示自检
```

## 本地验证

```powershell
python -m unittest discover -s tests -v
node --check .\docs\app.js
$env:PYTHONUTF8=1
python "<skill-creator目录>\scripts\quick_validate.py" .\skill\ai-comic-director
```

## 开源许可

[MIT License](LICENSE)。Codex、LibTV、生成模型和用户素材仍分别适用其权利人与服务条款，详见 [THIRD_PARTY.md](THIRD_PARTY.md)。
