# 归档范围与脱敏边界

本目录是与具体公司、宿主项目和业务功能无关的混合栈技术参考包，仅用于在获得授权的环境中重建 Android / iOS / Flutter 混合栈能力。

## 收录白名单

- `fusion-core/`：Flutter、Android、iOS 的通用单引擎多容器运行时源码及必要构建元数据。
- `contracts/`：generic 路由/事件契约、兼容规则和生成工具。
- `flutter-module-template/`：最小 Flutter module 装配示例。
- `host-adapters/`：Android/iOS 宿主适配接口骨架，不包含任何页面或业务服务。
- `sh/`：构建、发布、清理、依赖切换、校验脚本的 provider-neutral 安全模板。
- `docs/`：架构、协议、生命周期、接入、构建、脱敏和还原说明。

## 永久排除

- 任意宿主 App、业务 package、页面、模型、网络层、埋点、业务路由和业务事件。
- `.git`、远端历史、CI 配置、签名文件、证书、keystore、provisioning profile。
- `build`、`.dart_tool`、Pods、生成的 `.android/.ios`、AAR、framework、xcframework 和缓存。
- 公司 Git 地址、制品库地址、接口服务器、IP、账号、Token、密码、Cookie、Authorization。
- 本机绝对路径和个人信息。

## 安全原则

1. 所有远端地址和凭据只能从环境变量注入；示例文件只放占位符。
2. 发布和远端删除默认关闭，必须显式设置开关并二次确认。
3. 契约只含 `featureHome`、`openNativeScreen`、`pickNativeValue`、`entityChanged` 等无业务含义示例。
4. 本目录采用白名单构建；不得把原宿主目录整体复制进来。
5. 开源/第三方源码的许可证必须保留，不能以脱敏为由删除版权或许可信息。
