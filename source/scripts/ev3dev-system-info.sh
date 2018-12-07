#!/usr/bin/env bash

FORMAT_MARKDOWN="false"
case "$1" in
  -h|--help)
    echo "ev3dev system info tool. Prints common platform information for use in reporting issues."
    echo "Use \"ev3dev-sysinfo -m\" to format for GitHub markdown"
    exit
    ;;
  -m|--markdown)
    FORMAT_MARKDOWN=true
    ;;
esac

get_ev3dev_release() {
  if [ -e /etc/ev3dev-release ]; then
    head -n 1 -q /etc/ev3dev-release
  else
    echo "** Pre-2016 release **"
  fi
}

get_package_version () {
  target_line=$(dpkg-query -s "$1" | grep -m1 ^Version)
  echo "${target_line##*: }"
}

get_bluetooth_version () {
  hciconfig -a | grep -o 'HCI Version: [[:digit:]]\.[[:digit:]]' \
    | cut -c 14-
}

print_val() {
  printf "%-20s%s\n" "$1: " "$2"
}

print_fence_if_markdown() {
  if [ "$FORMAT_MARKDOWN" = "true" ]; then
    echo '```'
  fi
}

print_title_if_markdown() {
  if [ "$FORMAT_MARKDOWN" = "true" ]; then
    echo "**System info (from \`ev3dev-sysinfo\`)**"
  fi
}

print_copy_line_if_markdown() {
  if [ "$FORMAT_MARKDOWN" = "true" ]; then
    echo "<!-- Copy everything between these lines -->"
  fi
}

print_copy_line_if_markdown
print_title_if_markdown
print_fence_if_markdown

print_val "Image file" "$(get_ev3dev_release)"
print_val "Kernel version" "$(uname -r)"
print_val "Brickman" "$(get_package_version brickman)"
print_val $(lscpu | grep BogoMIPS | cut --field="1-2" --delimiter=":" --output-delimiter=" ")
print_val "Bluetooth" "$(get_bluetooth_version)"
for board in /sys/class/board-info/*; do
  print_val "Board" "$(basename $board)"
  cat $board/uevent
done

print_fence_if_markdown
print_copy_line_if_markdown
