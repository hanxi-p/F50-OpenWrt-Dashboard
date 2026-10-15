# AdGuard Home开关

[返回功能目录](../../README.md#功能目录) · 功能ID：`adguard` · 快捷控制

## 这项功能做什么

广告过滤服务独立启停，位于更多设置。

开启填充、关闭描边；开关不重启OpenClash，DNS由协调器按实际健康状态切换。

## 可以设置/需要准备什么

自己选择过滤规则；先核对已装服务、5353端口与管理API配置。

## 如何选择与部署

此功能使用[共享面板基础包](../install.md)。选择此项确定配置和验收范围；基础包会一并部署共用页面、RPC及采集服务，执行前由codex列出依赖与会一并安装的内容。

```text
我选择 F50-OpenWrt-Dashboard 的 adguard 功能。
先读对应功能页、依赖和风险清单，保存原配置；列出会配置/安装的范围后按我的选择推进。
按本页验收并记录通过、失败与未测，最后交付恢复入口。
```

## 怎么验证

三轮四组合、另一个插件PID、解析/HTTPS、过滤与直连恢复。

按[风险清单](../risk-register.md)分别记录明显错误、逻辑审查和多轮场景测试。已有历史验证不替代自己设备上的验收，危险或需人工配合场景单列未测。

## 代码与恢复

- [f50adguard](../../extras/dashboard/f50adguard)
- [f50adguard-worker](../../extras/dashboard/f50adguard-worker)
- [f50adguard.js](../../extras/dashboard/f50adguard.js)

使用实际安装时生成的备份与恢复脚本，保留历史数据。日志与恢复操作见[维护说明](../operations.md)，历史修补见[修复记录](../fix-history.md)。
