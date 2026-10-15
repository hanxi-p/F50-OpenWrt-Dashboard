# 更新与回滚互斥

[返回功能目录](../../README.md#功能目录) · 功能ID：`boot-rollback` · 独立扩展

## 这项功能做什么

回滚恢复匹配模块，避免并发修改启动控制。

系统更新、回滚、启动选择共享互斥；恢复旧镜像时同步匹配模块；不等同于重新刷入内核。

## 可以设置/需要准备什么

版本适配和原件备份；不为测试擅自写启动分区。

## 如何选择与部署

使用[系统组件包](../../extras/system-reliability/README.md)，先运行兼容检查。该包内组件一同部署；本条用于选择检查/配置目标，不代表存在单文件通用安装器。

```text
我选择 F50-OpenWrt-Dashboard 的 boot-rollback 功能。
先读对应功能页、依赖和风险清单，保存原配置；列出会配置/安装的范围后按我的选择推进。
按本页验收并记录通过、失败与未测，最后交付恢复入口。
```

## 怎么验证

隔离竞争、失败写入与恢复路径；真实回滚/整套恢复需明确安排。

按[风险清单](../risk-register.md)分别记录明显错误、逻辑审查和多轮场景测试。已有历史验证不替代自己设备上的验收，危险或需人工配合场景单列未测。

## 代码与恢复

- [mu300-update](../../extras/system-reliability/mu300-update)
- [mu300-next-boot](../../extras/system-reliability/mu300-next-boot)
- [modem-lock](../../extras/system-reliability/modem-lock)

使用实际安装时生成的备份与恢复脚本，保留历史数据。日志与恢复操作见[维护说明](../operations.md)，历史修补见[修复记录](../fix-history.md)。
