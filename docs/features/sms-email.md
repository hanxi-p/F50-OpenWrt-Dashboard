# 短信转发到邮件

[返回功能目录](../../README.md#功能目录) · 功能ID：`sms-email` · 独立扩展

## 这项功能做什么

发送号码与完整短信原文转发到自己的邮箱。

固定主题“来自F50新信息”；持久队列、失败重试、去重、漏入队补偿；发送不阻塞短信接收。

## 可以设置/需要准备什么

自己的SMTP邮箱、授权码、收件人、TLS与msmtp；授权码只放私有文件。

## 如何选择与部署

这是[短信邮件独立包](../sms-email.md)，可在已经运行的系统上单独部署。

```text
我选择 F50-OpenWrt-Dashboard 的 sms-email 功能。
先读对应功能页、依赖和风险清单，保存原配置；列出会配置/安装的范围后按我的选择推进。
按本页验收并记录通过、失败与未测，最后交付恢复入口。
```

## 怎么验证

hello编码/SMTP返回、真实新短信入队提交与收件确认；断网/重复/停止清理隔离测试。

按[风险清单](../risk-register.md)分别记录明显错误、逻辑审查和多轮场景测试。已有历史验证不替代自己设备上的验收，危险或需人工配合场景单列未测。

## 代码与恢复

- [worker.sh](../../extras/sms-email/worker.sh)
- [enqueue.sh](../../extras/sms-email/enqueue.sh)
- [reconcile.sh](../../extras/sms-email/reconcile.sh)
- [install.sh](../../extras/sms-email/install.sh)

使用实际安装时生成的备份与恢复脚本，保留历史数据。日志与恢复操作见[维护说明](../operations.md)，历史修补见[修复记录](../fix-history.md)。
