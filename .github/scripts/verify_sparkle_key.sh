#!/usr/bin/env bash
# verify_sparkle_key.sh —— 校验 SPARKLE_PRIVATE_KEY 私钥文件是否为 base64(96B) Ed25519 私钥格式。
#
# 背景（ITER-13 / ITER-18）：发布流程 publish.yml 与 CI 冒烟 signing-check.yml 共用本脚本，
#       避免同一份 guard 逻辑在两处各写一份导致漂移（改一处漏一处）。
# 格式约定：base64(96B) = expanded 私钥 64B（scalar‖prefix）+ 公钥 32B，
#       与 Sparkle 官方 generate_keys -x 导出的 Ed25519 私钥文件一致。
#
# 用法：verify_sparkle_key.sh <keyfile>
#   退出码 0：格式正确（base64 解码后恰好 96B），stdout 打印 OK；
#   退出码 1：格式错误（非 base64 / PEM / 解码后长度≠96B），错误信息写 stderr。
# 注：本脚本只做格式校验；密钥与 SUPublicEDKey 的配套关系由 publish.yml 的交叉自检负责。

set -u

KEYFILE="${1:?usage: verify_sparkle_key.sh <keyfile>}"

if [ ! -f "$KEYFILE" ]; then
  echo "ERROR: keyfile not found: $KEYFILE" >&2
  exit 1
fi

# 与 ITER-13 原始内联 guard 逐行一致：
# base64 解码失败（如 PEM）→ 输出 0 字节 → 0≠96 走错误分支；解码成功但长度≠96B 同样走错误分支。
KEY_LEN=$(base64 -d < "$KEYFILE" 2>/dev/null | wc -c | tr -d ' ')
if [ "$KEY_LEN" -ne 96 ]; then
  echo "ERROR: SPARKLE_PRIVATE_KEY 不是 base64(96B) Ed25519 私钥格式（期望 scalar‖prefix 64B + 公钥 32B）" >&2
  exit 1
fi

echo "OK: SPARKLE_PRIVATE_KEY 是 base64(96B) Ed25519 私钥格式"
exit 0
