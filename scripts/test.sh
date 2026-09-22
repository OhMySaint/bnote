#!/bin/zsh
# Headless regression harnesses. They compile the editor sources straight with
# swiftc (no Xcode test target) and drive the real AppKit/SwiftUI views in an
# offscreen window, because GUI automation needs Accessibility rights.
#
#   scripts/test.sh            # editor + keyboard + ui (regression)
#   scripts/test.sh thesis     # generate the 35-page thesis into the app's store
#   scripts/test.sh screenplay # generate the 24-page screenplay
#   scripts/test.sh tree       # generate the screenplay as a page tree
#   scripts/test.sh perf       # trace column vs header geometry after toggling full width
#   scripts/test.sh dash [n]   # Tổng quan với n trang: phải lấp đầy cửa sổ (ảnh bnote-dash-n.png)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/bnote-harness"
mkdir -p "$OUT"

CORE=(BNote/AppFlavor.swift BNote/Models/PageConfig.swift BNote/Models/Note.swift BNote/Models/Tag.swift
      BNote/Views/PageHeaderView.swift BNote/Views/CoverStyle.swift BNote/Views/TagViews.swift
      BNote/Editor/*.swift)
UI=(BNote/AppFlavor.swift BNote/Models/*.swift BNote/Editor/*.swift
    BNote/Views/NoteEditorView.swift BNote/Views/PageHeaderView.swift BNote/Views/FormatToolbar.swift
    BNote/Views/PageInspector.swift BNote/Views/OutlinePanel.swift BNote/Views/ColorPalette.swift
    BNote/Views/CoverStyle.swift BNote/Views/TagViews.swift BNote/Views/SettingsView.swift
    BNote/Views/CoverControls.swift BNote/Views/FindBar.swift)

run() {
  local name=$1; shift
  echo "▶ $name"
  swiftc -O -DDEBUG -o "$OUT/$name" "Tests/Harness/$name/main.swift" "$@" 2>&1 | grep -E "error:" || true
  "$OUT/$name" ${=RUN_ARGS:-} 2>&1 | grep -vE "^$|CoreData: debug" | tail -n +1
}

case "${1:-all}" in
  all)        run editor "${CORE[@]}"; run keyboard "${CORE[@]}"; run ui "${UI[@]}" ;;
  editor|keyboard) run "$1" "${CORE[@]}" ;;
  ui)         run ui "${UI[@]}" ;;
  perf)       run perf "${UI[@]}" ;;   # đo thời gian/độ trễ bật Toàn chiều rộng, không assert
  dash)       RUN_ARGS="${2:-0}" run dash "${UI[@]}" BNote/Views/DashboardView.swift BNote/Views/SidebarView.swift ;;
  thesis|screenplay|tree)
    echo "Ghi vào store của app — thoát BNote trước."; pkill -x BNote || true; sleep 1
    run "$1" BNote/AppFlavor.swift BNote/Models/*.swift BNote/Editor/*.swift BNote/Views/PageHeaderView.swift BNote/Views/CoverStyle.swift BNote/Views/TagViews.swift ;;
  *) echo "unknown: $1"; exit 1 ;;
esac
