# BoltWrt Packages

📦本仓库提供 BoltWrt 固件使用的 OpenWrt 构建 feed。固件下载、安装和升级见主仓。 [BoltWrt](https://github.com/BoltWrt/BoltWrt)

固件构建按源码锁检出此 feed 及子模块。本地候选可用固件准备脚本的 `--local-feed` 选项验证，候选提交须与锁一致。4.1.0 发布已暂停，原标签不包含后续策略修正。 [开发分支源码锁](https://github.com/BoltWrt/BoltWrt/blob/develop/config/source-lock.json) · [准备脚本](https://github.com/BoltWrt/BoltWrt/blob/develop/scripts/boltwrt-prepare.py)

PassWall2 的后端及核心选项跟随锁定上游；不恢复独立 Hysteria2、SS-libev、NaiveProxy 或 TUIC 后端。保留配置迁移和安全修复，停止生成设备内持久备份。Argon 保持上游子模块，通过精确补丁移除主题选择、外观设置及独立更新入口。

4.0.0 的组件兼容说明和安全审查原文可在锁定提交中查阅。 [4.0.0 Packages 历史资料](https://github.com/BoltWrt/Packages/tree/45ad2e027ad925eb084231421bb6a7576aa099e3)
