# 面板安装包

完整流程见 [第十一章](../../docs/11-optional-dashboard.md)，功能见 [features.md](../../docs/features.md)。请下载本仓库完整目录，不混用原刷机指南旧包。

Windows仓库根目录：

```powershell
python .\extras\dashboard\deploy.py --host f50
```

脚本用电脑现有SSH配置传输，设备端先校验`SHA256SUMS`与版本，保存原文件后安装；部署包括页面、RPC/ACL、历史、每日峰值、分钟流量和报错日志。依赖由Codex按指南准备。OpenClash、AdGuard、短信邮件与系统组件分别安装，不自动导入个人配置。

安装器打印设备自己的备份与`restore.sh`入口，保存到本机进度记录。文件与版本不匹配时先适配；本包不包含个人密码、MAC免密名单、SMTP授权码、订阅或整机镜像。
