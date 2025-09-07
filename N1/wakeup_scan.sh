#!/system/bin/sh
# 列出系统中所有已导出的 wakeup 节点，并尝试给出类别与名称

echo "== 1) RAW wakeup 文件列表 =="
find /sys/devices -type f -name wakeup 2>/dev/null | sort

echo
echo "== 2) 逐项解析（类别 | 状态 | 设备名/路径） =="
find /sys/devices -type f -name wakeup 2>/dev/null | while read f; do
  state=$(cat "$f" 2>/dev/null)
  d=${f%/power/wakeup}

  # 归类规则（基于路径特征，尽量覆盖常见 SoC/驱动命名）
  cls="other"
  case "$d" in
    */ethernet|*/ethernet/*)                      cls="ethernet";;
    */rtc.*|*/rtc/*)                              cls="rtc";;
    */rc/*|*/ir*|*/c8100580.rc/*|*/rc-*/input/*)  cls="ir";;
    */gpio_key*|*/gpio-keys*|*/keypad*|*/input/*)  cls="keys";;  # 某些按键会归到 input
    */cec/*|*/aocec/*|*meson_ccec*|*/hdmi*cec*)   cls="cec";;
    */xhci*|*/dwc3/*|*/usb*phy*|*/ehci*|*/ohci*)  cls="usb";;
    */bt*|*/bluetooth*|*/hci*)                    cls="bluetooth";;
    */wlan*|*/sdio*|*/wifi*)                      cls="wifi";;
  esac

  # 尝试拿“名字”（若是 input 设备）
  name=""
  # input 设备有多种层级，尽量匹配
  for p in \
    "$d/name" \
    "$d/device/name" \
    "$(dirname "$d")/name" \
    "$(dirname "$d")/device/name"
  do
    [ -z "$name" ] && [ -f "$p" ] && name=$(cat "$p" 2>/dev/null)
  done

  # 如果仍然拿不到，就看 modalias/driver（帮助识别）
  [ -z "$name" ] && [ -f "$d/modalias" ] && name=$(cat "$d/modalias" 2>/dev/null)
  [ -z "$name" ] && [ -L "$d/driver" ] && name="driver:$(basename "$(readlink "$d/driver")" 2>/dev/null)"

  printf "%-11s | %-7s | %s %s\n" "$cls" "$state" "$d" "${name:+| $name}"
done

echo
echo "== 3) Input 设备（便于识别 IR/按键） =="
for e in /sys/class/input/event*; do
  [ -d "$e" ] || continue
  n=$(cat "$e/device/name" 2>/dev/null)
  w="$e/device/power/wakeup"
  s="no-wakeup"
  [ -f "$w" ] && s=$(cat "$w" 2>/dev/null)
  printf "%s | %-8s | %s\n" "$e" "$s" "${n:-(no-name)}"
done

echo
echo "== 4) wakeup_sources 统计（需要 debugfs） =="
mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug 2>/dev/null
[ -f /sys/kernel/debug/wakeup_sources ] && head -n 200 /sys/kernel/debug/wakeup_sources || echo "(no /sys/kernel/debug/wakeup_sources)"
