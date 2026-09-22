##############################################################################
# 中国镜像（pub 依赖 & Flutter 引擎产物下载走国内 CDN，避免被墙）
##############################################################################
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

##############################################################################
# Java（Flutter / Android 构建依赖 JDK 17）
##############################################################################
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export PATH="$JAVA_HOME/bin:$PATH"

##############################################################################
# Android 平台工具（adb 等）
##############################################################################
export PATH="/Users/andy/zwork/tools/assdk/platform-tools:$PATH"

##############################################################################
# Flutter（用 fvm 管理多版本，按项目自动切换）
#
#   已安装版本（放在 fvm 缓存目录 /Users/andy/zwork/tools/fvm/versions 下）：
#     - ohos      → Flutter 3.35.8-ohos（鸿蒙 fork 版，做 HarmonyOS 开发用）
#     - official  → Flutter 3.38.9（官网版，做普通 Android/iOS 开发用）
#
#   常用命令：
#     fvm use ohos          # 在【当前项目】里锁定鸿蒙版（生成 .fvmrc + .fvm 软链）
#     fvm use official      # 在【当前项目】里锁定官网版
#     fvm global ohos       # 切换【全局默认】版本（更新下面 default 软链的指向）
#     fvm flutter <命令>     # 用项目锁定的版本执行，如 fvm flutter run / fvm flutter build
#     fvm list              # 查看已装版本
#
#   下面把 fvm 的「全局默认版本」软链 default/bin 加进 PATH：
#   - 在 fvm 项目内：优先用项目 .fvmrc 指定的版本（通过 `fvm flutter ...` 或 IDE 设置）
#   - 不在项目内 / 直接敲 `flutter`：回退到这个全局默认版本
#   切换全局默认只需 `fvm global <版本>`，软链自动更新，无需改本文件
##############################################################################
export PATH="/Users/andy/zwork/tools/fvm/default/bin:$PATH"
# 全局激活的 Dart/Flutter 命令行工具（dart pub global activate 装的可执行文件）
export PATH="$PATH:$HOME/.pub-cache/bin"

##############################################################################
# HarmonyOS / OpenHarmony 工具链
#
#   两套 SDK 各司其职，不要混用：
#     - HOS_SDK_HOME    → OpenHarmony SDK（真机 hdc 等命令行工具）
#     - DEVECO_SDK_HOME → DevEco 自带的 HarmonyOS SDK，flutter build hap / hvigor 构建时读它
#
#   注意：不要再执行 `flutter config --ohos-sdk=$HOS_SDK_HOME`。
#   那会把 flutter 的 ohos-sdk 指到 OpenHarmony SDK，而 HarmonyOS 工程构建需要
#   HarmonyOS SDK，会导致 `No Hmos SDK found`。留空让 flutter 自动读 DEVECO_SDK_HOME。
##############################################################################
export HOS_SDK_HOME="/Users/andy/zwork/tools/OpenHarmonySDK"
# OpenHarmony 命令行工具（hdc 等），实际在版本号子目录 23/toolchains 下
export PATH="$PATH:$HOS_SDK_HOME/23/toolchains"

# DevEco Studio 及其自带工具链（ohpm 包管理、hvigor 构建）
export DEVECO_HOME="/Applications/DevEco-Studio.app"
export PATH="$PATH:$DEVECO_HOME/Contents/tools/ohpm/bin"
export PATH="$PATH:$DEVECO_HOME/Contents/tools/hvigor/bin"

# HarmonyOS SDK：flutter build hap / hvigor assembleHap 依赖它定位 SDK
export DEVECO_SDK_HOME="$DEVECO_HOME/Contents/sdk"


##############################################################################
# 别名 · zsh 配置自身
##############################################################################
alias oz="open .zshrc"        # 用默认编辑器打开 .zshrc
alias sz="source .zshrc"      # 重新加载 .zshrc 使改动生效

##############################################################################
# 别名 · Flutter / Dart
#
#   下面统一用 `fvm flutter`，让每条命令严格跟随【当前项目 .fvmrc 锁定的版本】；
#   项目若没有 .fvmrc，则回退到 fvm 全局默认版本（fvm global 设定）。
#   直接敲裸 `flutter` 走的是 PATH 里的 fvm 全局默认版本，二者按需选用。
##############################################################################
alias fpg="fvm flutter pub get"                                     # 拉取依赖
alias fpu="fvm flutter pub upgrade"                                 # 升级依赖
alias fc="fvm flutter clean"                                        # 清理构建产物
alias fcp='rm -rf pubspec.lock && fvm flutter clean && fvm flutter pub get'  # 删锁文件后彻底重装依赖
alias fba="fvm flutter build apk --release"                         # 打 Android release APK
alias fbaar="fvm flutter build aar --release"                       # 打 Android release AAR
alias fbi="fvm flutter build ios --release --no-codesign"           # 打 iOS release（不签名）
alias fbf="fvm flutter build ios-framework --release --output=framework"  # 打 iOS release framework
# iOS 全量重装：清理 → 删锁文件 → 重装 pub 依赖 → 重装 CocoaPods
alias fr='fvm flutter clean && rm pubspec.lock && rm -rf ios/Pods ios/Podfile.lock && fvm flutter pub get && cd ios && pod install && cd ..'

##############################################################################
# 别名 · iOS / CocoaPods
##############################################################################
alias pi="pod install"                          # 安装 Pod 依赖
alias pil="pod install > pod_install.log 2>&1"  # 安装 Pod 并把输出写入日志文件
alias oi="open Runner.xcworkspace"              # 打开 iOS 工程

##############################################################################
# 别名 · XSStack 工程脚本
##############################################################################
alias xsbf='sh /Users/andy/zwork/code/xmain/xmstack/sh/build-framework.sh'   # 构建 framework
alias xsuf='sh /Users/andy/zwork/code/xmain/xmstack/sh/upload-framework.sh'  # 上传 framework
alias xsba='sh /Users/andy/zwork/code/xmain/xmstack/sh/build-aar.sh'         # 构建 aar
alias xscn='sh /Users/andy/zwork/code/xmain/xmstack/sh/clean-nexus.sh'       # 清理 nexus
alias xssd='sh /Users/andy/zwork/code/xmain/xmstack/sh/switch-deps.sh'       # 切换依赖

 
##############################################################################
# 别名 · Git 代理
#
#   开发机常在「需要代理拉取」和「不需要代理」之间切换，这几个别名快速开关。
##############################################################################
alias gitp="sh /Users/andy/zwork/sh/git.sh"   # 设置 Git 全局代理（脚本内实现）
# 查看当前 Git 全局代理
alias gitgetp='echo "HTTP 代理: " && git config --global --get http.proxy && \
         echo "HTTPS 代理: " && git config --global --get https.proxy'
# 取消 Git 全局代理
alias ungitp='git config --global --unset http.proxy && \
git config --global --unset https.proxy && \
echo "Git 全局代理已取消"'

##############################################################################
# 别名 · 终端代理
#
#   setproxy：为【当前终端会话】设置 http/https/socks 代理（走本地 7890 端口）。
#   ⚠️ 原配置里这个别名错误地命名成了 `cat`，会覆盖系统 cat 命令，已改名为 setproxy。
##############################################################################
alias setproxy='export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890'
alias proxy='env | grep -i proxy'   # 查看当前终端已设置的代理变量

##############################################################################
# 别名 · 其他
##############################################################################
alias py='python3'                          # python3 简写
alias sdata='df -h /System/Volumes/Data'    # 查看数据盘剩余空间


# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

##############################################################################
# Oh My Zsh 框架
##############################################################################
export ZSH="$HOME/.oh-my-zsh"                       # Oh My Zsh 安装目录
ZSH_THEME="af-magic"                                # 使用的主题
plugins=(git zsh-autosuggestions zsh-completions)   # 加载的插件：git 集成、命令自动建议、补全增强
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=46'      # 自动建议文本的高亮颜色（亮绿）
fpath+=/path/to/zsh-completions/src                 # 补全脚本搜索路径
zstyle ':completion:*' use-cache on                 # 开启补全缓存，加快补全速度
zstyle ':completion:*' cache-path ~/.zsh/cache      # 补全缓存存放目录
source $ZSH/oh-my-zsh.sh                            # 加载 Oh My Zsh（必须在插件/主题设置之后）



##############################################################################
# Conda 初始化（由 `conda init` 自动管理，勿手动改动下面标记内的内容）
##############################################################################
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

