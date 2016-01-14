#!/usr/bin/env bash

if [ "$1" == '--help' ]; then
  echo "ev3dev system info tool. Prints common platform information for use in reporting issues."
  exit
fi

get_colon_separated_file_prop () {
  target_line=$(grep -m1 ^"$2" "$1")
  echo "${target_line##*: }"
}

get_package_version () {
  target_line=$(dpkg-query -s "$1" | grep -m1 ^Version)
  echo "${target_line##*: }"
}

# dpkg-query --status doesn't accept wildcards, but --list does...
get_package_version_with_wildcard () {
  echo $(dpkg-query -l "$1" | grep "$1" | awk '{print $3}')
}

print_val() {
  printf "%-20s%s\n" "$1: " "$2"
}

print_val "Kernel version" "$(uname -r)"

if [ -f /proc/device-tree/model ]; then
  print_val "Board" "$(cat /proc/device-tree/model)"
else
  print_val "Board" "$(get_colon_separated_file_prop /proc/cpuinfo 'Hardware')"
fi

print_val "Revision" "$(get_colon_separated_file_prop /proc/cpuinfo 'Revision')"
print_val "Brickman" "$(get_package_version brickman)"
print_val "ev3devKit" "$(get_package_version_with_wildcard ev3devkit-\*)"
