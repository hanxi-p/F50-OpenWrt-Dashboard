# USB网络与防火墙适配

[返回功能目录](../../README.md#功能目录) · 功能ID：`usb-firewall` · 独立扩展

## 这项功能做什么

修补RNDIS桥接顺序与厂商5.4的flowtable问题。

匹配的USB桥接脚本与fw4 hook，软件/硬件flow offloading保持关闭；SSH、LuCI、DHCP与NAT分别验收。

## 可以设置/需要准备什么

核对版本和现有USB接口；系统包先--check后安装，保留恢复入口。

## 如何选择与部署

使用[系统组件包](../../extras/system-reliability/README.md)，先运行兼容检查。该包内组件一同部署；本条用于选择检查/配置目标，不代表存在单文件通用安装器。

```text
我选择 F50-OpenWrt-Dashboard 的 usb-firewall 功能。
先读对应功能页、依赖和风险清单，保存原配置；列出会配置/安装的范围后按我的选择推进。
按本页验收并记录通过、失败与未测，最后交付恢复入口。
```

## 怎么验证

USB新连接、DHCP/后台/转发、fw4重载和Wi-Fi管理；不可用条件写未测。

按[风险清单](../risk-register.md)分别记录明显错误、逻辑审查和多轮场景测试。已有历史验证不替代自己设备上的验收，危险或需人工配合场景单列未测。

## 代码与恢复

- [10-mu300-usb](../../extras/system-reliability/10-mu300-usb)
- [19-mu300-fw4](../../extras/system-reliability/19-mu300-fw4)

使用实际安装时生成的备份与恢复脚本，保留历史数据。日志与恢复操作见[维护说明](../operations.md)，历史修补见[修复记录](../fix-history.md)。
