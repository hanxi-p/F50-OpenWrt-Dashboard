# 每分钟流量日志

[返回功能目录](../../README.md#功能目录) · 功能ID：`minute-log` · 数据展示记录

## 这项功能做什么

每分钟记录下载/上传增量与合计，保留5GB。

原始rx/tx、boot_id、ifindex、uptime、区间秒数与增量并存；重启/计数下降/采样缺口标记；不按日期过期，满后清旧记录。

## 可以设置/需要准备什么

目录/opt/f50-traffic-hours/counters；每类5GB，单日16MiB快循环保护；日志不参与修改套餐。

## 如何选择与部署

此功能使用[共享面板基础包](../install.md)。选择此项确定配置和验收范围；基础包会一并部署共用页面、RPC及采集服务，执行前由codex列出依赖与会一并安装的内容。

```text
我选择 F50-OpenWrt-Dashboard 的 minute-log 功能。
先读对应功能页、依赖和风险清单，保存原配置；列出会配置/安装的范围后按我的选择推进。
按本页验收并记录通过、失败与未测，最后交付恢复入口。
```

## 怎么验证

自然60秒接收+发送=原始差；三轮重启/下降/间断/坏输入/容量与保留。

按[风险清单](../risk-register.md)分别记录明显错误、逻辑审查和多轮场景测试。已有历史验证不替代自己设备上的验收，危险或需人工配合场景单列未测。

## 代码与恢复

- [f50-counter-audit.uc](../../extras/dashboard/f50-counter-audit.uc)
- [f50-traffic-archive](../../extras/dashboard/f50-traffic-archive)

使用实际安装时生成的备份与恢复脚本，保留历史数据。日志与恢复操作见[维护说明](../operations.md)，历史修补见[修复记录](../fix-history.md)。
