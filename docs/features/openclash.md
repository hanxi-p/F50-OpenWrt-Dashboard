# OpenClash开关

[返回功能目录](../../README.md#功能目录) · 功能ID：`openclash` · 快捷指令

## 这项功能做什么

已装代理插件的异步启停与状态反馈。

主面板蓝色开启/白色关闭；后台检查核心、防火墙与DNS，不只看进程；与AdGuard分别控制。

## 可以设置/需要准备什么

本人先提供插件与订阅；面板不自动安装代理或导入私人节点。

## 如何选择与部署

此功能使用[共享面板基础包](../install.md)。选择此项确定配置和验收范围；基础包会一并部署共用页面、RPC及采集服务，执行前由codex列出依赖与会一并安装的内容。

```text
我选择 F50-OpenWrt-Dashboard 的 openclash 功能。
先读对应功能页、依赖和风险清单，保存原配置；列出会配置/安装的范围后按我的选择推进。
按本页验收并记录通过、失败与未测，最后交付恢复入口。
```

## 怎么验证

三轮四种插件组合，DNS/HTTPS/后台、另一个插件PID及恢复原状态。

按[风险清单](../risk-register.md)分别记录明显错误、逻辑审查和多轮场景测试。已有历史验证不替代自己设备上的验收，危险或需人工配合场景单列未测。

## 代码与恢复

- [f50openclash](../../extras/dashboard/f50openclash)
- [f50openclash-worker](../../extras/dashboard/f50openclash-worker)
- [f50openclash.js](../../extras/dashboard/f50openclash.js)

使用实际安装时生成的备份与恢复脚本，保留历史数据。日志与恢复操作见[维护说明](../operations.md)，历史修补见[修复记录](../fix-history.md)。
