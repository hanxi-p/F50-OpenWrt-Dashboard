# 特定构建发送路径修补

先读[完整边界、来源与应用恢复说明](../../../../docs/features/wifi-log-quiet.md)。生成器只接受表中已降噪驱动的完整SHA256，不改写输入、不自动安装或重启。

`tx-guard.s` 是生成器内嵌指令的可复核来源。AP/GO PCIe ARP和普通DNS走数据队列，DHCP/VoWiFi等保留原分支；IPv6组播回到正常分类。描述符访问补上五字节前缀。厂商模块始终由使用者本地提供，不提交 Git。

## ARM 隔离检查

先生成候选文件，然后在电脑/构建主机准备夹具：

```sh
node driver-tx-fix.cjs QUIET.ko TX-FIXED.ko
node prepare-test.cjs TX-FIXED.ko /tmp/f50-tx-instruction-test
```

在生成夹具的目录中，以本仓库文件的实际绝对路径编译：

```sh
cd /tmp/f50-tx-instruction-test
aarch64-linux-gnu-gcc -static -Os /path/to/repo/extras/dashboard/optional/wifi-tx/test-tx-guard.c /path/to/repo/extras/dashboard/optional/wifi-tx/test-tx-guard.s -o test-tx-guard
```

测试使用假结构与隔离返回边界，在 ARM64 用户态执行提取的实际指令；覆盖135个ARP分类、1080个其他分类组合及24576个描述符组合，不加载模块、不读取内核内存、不发包。运行结果不能替代正式应用后的真实DNS、关联、传输、数据保留和错误日志检查。

激活/恢复脚本为已核对构建的独立模板，使用前按文档准备它们要求的私有备份目录、原模块和候选文件，再明确确认重启。不要为了测试反复重启唯一管理连接。
