# 原生设备采集器

见[统计功能与口径](../../../docs/features/device-traffic.md)。`flow-account.c` 仅使用 libc 与 Linux netlink ABI，不清零内核计数。

## 在设备外准备

在 Linux 构建主机安装 AArch64 交叉编译器及 binutils，然后在仓库根目录执行：

```sh
sh extras/dashboard/device-traffic/build.sh
```

ARM64 Linux 主机可使用 `CC=gcc sh extras/dashboard/device-traffic/build.sh`。脚本检查 ELF 架构，生成静态 `flow-account` 和 `SHA256SUMS.local`；两者保留在本机，不进入 Git。Windows 部署时，将这两个生成文件复制到电脑上同一目录，再运行基础包 `deploy.py`。基础包会同时核对公开源码清单和本地二进制清单。

原生程序只匹配已核对的 aarch64 F50。`nf_conntrack_acct` 不可用时安装器中止，不自动修改内核、网络或加速开关。内核/代理路径不同需要先适配。

## 隔离测试

以下 C 测试只使用合成 netlink 消息，不连接真实接口：

```sh
cc -O2 extras/dashboard/device-traffic/test-native.c -o /tmp/f50-test-native
/tmp/f50-test-native
```

在提供 ucode 的测试环境运行日/月账本夹具：

```sh
ucode extras/dashboard/device-traffic/test-ledger.uc
```

ARM 构建可在 F50 的 `/tmp` 中运行上述隔离程序。测试覆盖方向、内网/代理排除、首次基线、实际时间差、重复读取、计数回退、采集代次变化、过期、跨日跨月与旧数据迁移。不要将隔离结果当成真实断电、自然跨日、接口切换或加速精度测试。
