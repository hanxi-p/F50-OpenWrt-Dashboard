# LuCI 认证参考源码

这些文件由[后台会话时长](../../../../docs/features/session-timeout.md)与[指定设备免密](../../../../docs/features/trusted-login.md)功能按需适配，基础安装器不覆盖 dispatcher、不建立免密名单。

`dispatcher.uc` 源自 LuCI，保留 Apache 2.0 署名和本目录许可证。会话 Cookie 使用配置期限、`Max-Age`、`SameSite=Lax` 与 `HttpOnly`，HTTPS增加 `Secure`；调用者显式传入 Cookie 路径，辅助函数不越域访问 `build_url`。

先备份、比对当前构建和已有定制，再合并需要的差异，不能直接覆盖不同版本。标准密码登录、失败密码、会话权限与退出入口必须保留。

`f50-trusted-auth.uc` 没有内置名单。由使用者另行提供 `/etc/f50-trusted-devices.json`，默认缺失时不免密；核对真实来源、邻居、桥端口和无线授权状态，不信任转发头。模板中的免密会话为12小时，改时长时同时核对该创建期限与 LuCI 配置。

纯匹配测试使用合成地址：`ucode test-match.uc`。完整 HTTP 登录、RPC权限和实际等待期限需在目标环境单独验收；名单、Cookie、会话标识和日志不提交到仓库。
