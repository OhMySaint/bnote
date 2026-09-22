#!/bin/zsh
# Chép toàn bộ trang từ bản này sang bản kia (hai bản có store riêng).
#
#   scripts/copy-data.sh stable dev    # lấy dữ liệu bản ổn định cho bản Dev thử
#   scripts/copy-data.sh dev stable    # ngược lại
#
# Store đích được sao lưu trước (…/default.store.bak-<ngày giờ>) rồi mới ghi đè.
# Thoát cả hai app trước khi chạy, nếu không SwiftData có thể ghi đè lại.
set -euo pipefail

container() {
  case "$1" in
    stable) echo "$HOME/Library/Containers/com.hoangson.BNote" ;;
    dev)    echo "$HOME/Library/Containers/com.hoangson.BNote.dev" ;;
    *) echo "flavour phải là stable hoặc dev, không phải: $1" >&2; exit 1 ;;
  esac
}

(( $# == 2 )) || { echo "dùng: scripts/copy-data.sh <stable|dev> <stable|dev>"; exit 1 }
[[ "$1" != "$2" ]] || { echo "nguồn và đích trùng nhau"; exit 1 }

SRC="$(container $1)/Data/Library/Application Support"
DST="$(container $2)/Data/Library/Application Support"
[[ -f "$SRC/default.store" ]] || { echo "không thấy store của bản $1 — mở app đó một lần trước đã"; exit 1 }

if pgrep -x "BNote" >/dev/null || pgrep -x "BNote Dev" >/dev/null; then
  echo "BNote đang chạy — thoát app rồi chạy lại."; exit 1
fi

mkdir -p "$DST"
STAMP=$(date +%Y%m%d-%H%M%S)
for f in default.store default.store-wal default.store-shm; do
  [[ -f "$DST/$f" ]] && mv "$DST/$f" "$DST/$f.bak-$STAMP"
  [[ -f "$SRC/$f" ]] && cp "$SRC/$f" "$DST/$f"
done
echo "→ đã chép dữ liệu $1 → $2 (bản cũ của $2 giữ ở *.bak-$STAMP)"
