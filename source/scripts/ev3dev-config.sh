#!/usr/bin/env bash

# Part of ev3dev-tools http://github.com/ev3dev/ev3dev-tools
#
# See LICENSE file for copyright and license details

# General config ====================================================
MENU_TITLE="ev3dev Software Configuration Tool (ev3dev-config)"
SELECTABLE_BACKTITLE="Arrow keys to navigate / <SPACE> to select / <ENTER> to save / <ESC> to exit without saving"
MENU_BACKTITLE="Arrow keys to navigate / <ENTER> to select / <ESC> to exit menu"
ASK_TO_REBOOT=0

# Serial config =====================================================
MODPROBE_EV3_CONF="/etc/modprobe.d/ev3.conf"
DISABLE_IN_PORT_LINE="options legoev3_ports disable_in_port=1"
SYSCTL_EV3_CONF="/etc/sysctl.d/ev3.conf"
DISABLE_KERNEL_MESSAGES_LINE="kernel.printk = 0 4 1 3"
SERIAL_SHELL_SERVICE="serial-getty@ttyS1.service"

# Platform config ===================================================
DEVICE_TREE_MODEL_FILE="/proc/device-tree/model"
RASPI_CONFIG_FILE="/boot/flash/config.txt"
PISTORMS_CONFIG_LINES=(
  "dtoverlay=pistorms"
)
BRICKPI_CONFIG_LINES=(
  "dtoverlay=brickpi"
  "init_uart_clock=32000000"
)
BRICKPIPLUS_CONFIG_LINES=(
  "dtoverlay=brickpi"
  "init_uart_clock=32000000"
  "dtparam=brickpi_battery=okay"
)

declare -a PLATFORM_MENU_ITEMS

# Service config ====================================================
declare -A SERVICE_STATUS
declare -a SERVICE_CHECKLIST_OPTIONS
declare -A NEW_SERVICE_STATUS
declare -A TARGET_SERVICES
TARGET_SERVICES=(
  ["avahi-daemon"]="Name resolution for OSX and Linux hosts"
  ["nmbd"]="Name resolution for Windows hosts"
  ["brickman"]="ev3dev graphical brick manager"
  ["openrobertalab"]="OpenRoberta Lab connector"
)

# Utilities =========================================================
calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error 
  # output from tput. However in this case, tput detects neither stdout or 
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=17
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

contains_element () {
  # First argument is target, rest are array values
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

boolean () {
  if [ "$1" = 0 ]; then
    echo true
  else
    echo false
  fi
}

get_current_hostname() {
    # This will return "n/a" if the current hostname doesn't conform to proper formatting
    host_line="$(hostnamectl status | grep -m1 ^"\\s*Static hostname")"
    echo "${host_line##*: }"
}

comment_line() {
    file_path="$1"
    line_contents="$2"
    
    sed -i "/^\s*${line_contents}/ s/^/#/" $file_path
}

uncomment_line() {
    file_path="$1"
    line_contents="$2"
    
    sed -i "/${line_contents}/ s/# *//" $file_path
}

uncomment_lines() {
    file_path="$1"
    shift
    
    for line_contents in "$@"; do
      uncomment_line "$file_path" "$line_contents"
    done
}

comment_lines() {
    file_path="$1"
    shift
    
    for line_contents in "$@"; do
      comment_line "$file_path" "$line_contents"
    done
}

all_lines_uncommented() {
  file_path="$1"
  shift
  
  if [ ! -f "$file_path" ]; then
    return 2
  fi
  
  for line_contents in "$@"; do
    if ! grep -q "^\s*$line_contents" "$file_path"; then
      return 1
    fi
  done
}

# Hardware and platform selection ===================================
detect_current_platform() {
  if [ ! -f "$DEVICE_TREE_MODEL_FILE" ]; then
    # TODO: We should check /proc/cpuinfo here instead of just assuming
    echo "brick"
    return 0
  fi
  
  device_tree_model="$(cat $DEVICE_TREE_MODEL_FILE)"
  if [[ "$device_tree_model" == "LEGO MINDSTORMS EV3"* ]]; then
    echo "brick"
  elif [[ "$device_tree_model" == "Raspberry Pi"* ]]; then
    echo "raspi"
  elif [[ "$device_tree_model" == "TI AM335x BeagleBone"* ]]; then
    echo "beagle"
  else
    echo "unknown"
  fi
}

detect_current_platform_config() {
  current_platform="$(detect_current_platform)"
  if [ "$current_platform" = "brick" ]; then
    echo "brick"
    return 0
  elif [ "$current_platform" = "beagle" ]; then
    echo "evb"
    return 0
  fi
  
  all_lines_uncommented "$RASPI_CONFIG_FILE" "${PISTORMS_CONFIG_LINES[@]}"
  PISTORMS_ENABLED="$(boolean $?)"
  all_lines_uncommented "$RASPI_CONFIG_FILE" "${BRICKPI_CONFIG_LINES[@]}"
  BRICKPI_ENABLED="$(boolean $?)"
  all_lines_uncommented "$RASPI_CONFIG_FILE" "${BRICKPIPLUS_CONFIG_LINES[@]}"
  BRICKPIPLUS_ENABLED="$(boolean $?)"
  
  if [ "$PISTORMS_ENABLED" = true ] && [ "$BRICKPI_ENABLED" = false ] && [ "$BRICKPIPLUS_ENABLED" = false ]; then
    echo "pistorms"
  elif [ "$PISTORMS_ENABLED" = false ] && [ "$BRICKPIPLUS_ENABLED" = true ]; then #BrickPi+ config is a superset of BrickPi config
    echo "brickpiplus"
  elif [ "$PISTORMS_ENABLED" = false ] && [ "$BRICKPI_ENABLED" = true ] && [ "$BRICKPIPLUS_ENABLED" = false ]; then
    echo "brickpi"
  else
    echo "unknown"
  fi
}

get_platform_menu_state() {
  current_option="$1"
  detected_platform_config="$2"
  
  if [ "$current_option" = "$detected_platform_config" ]; then
    echo "on"
  elif [ "$detected_platform_config" = "unknown" ] && [ "$current_option" = "brick" ]; then
    echo "on"
  elif [ "$detected_platform_config" = "unknown" ] && [ "$current_option" = "none" ]; then
    echo "on"
  else
    echo "off"
  fi
}

clean_raspi_plat_config() {
  comment_lines "$RASPI_CONFIG_FILE" "${PISTORMS_CONFIG_LINES[@]}"
  comment_lines "$RASPI_CONFIG_FILE" "${BRICKPI_CONFIG_LINES[@]}"
  comment_lines "$RASPI_CONFIG_FILE" "${BRICKPIPLUS_CONFIG_LINES[@]}"
}

get_available_platform_menu_items() {
  current_platform="$1"
  current_platform_config="$2"
  
  
  PLATFORM_MENU_ITEMS=()
  if [ "$current_platform" = "raspi" ]; then
    PLATFORM_MENU_ITEMS=(
      "pistorms" "Raspberry Pi with PiStorms" "$(get_platform_menu_state pistorms $current_platform_config)"
      "brickpi" "Raspberry Pi with BrickPi" "$(get_platform_menu_state brickpi $current_platform_config)"
      "brickpiplus" "Raspberry Pi with BrickPi+" "$(get_platform_menu_state brickpiplus $current_platform_config)"
      "none" "Raspberry Pi without any EV3-related functionality (unconfigured)" "$(get_platform_menu_state none $current_platform_config)"
    )
  elif [ "$current_platform" = "beagle" ]; then
    PLATFORM_MENU_ITEMS=(
      "evb" "EVB cape for BeagleBone" "$(get_platform_menu_state evb $current_platform_config)"
    )
  elif [ "$current_platform" = "brick" ]; then
    PLATFORM_MENU_ITEMS=(
      "brick" "Standard LEGO EV3 brick" "$(get_platform_menu_state brick $current_platform_config)"
    )
  fi
}

get_available_hardware_options() {
  current_platform="$1"
  
  HARDWARE_MENU_OPTIONS=()
  if [ "$current_platform" = "raspi" ]; then
    HARDWARE_MENU_OPTIONS=(
      "platconfig" "Specify the hardware to use to interface with EV3 devices"
    )
  elif [ "$current_platform" = "brick" ]; then
    HARDWARE_MENU_OPTIONS=(
      "serial" "Configure input port 1 to be used as a serial debug port"
    )
  fi
}

do_platform_menu() {
  current_platform=$(detect_current_platform)
  current_platform_config="$(detect_current_platform_config)"
  get_available_platform_menu_items "$current_platform" "$current_platform_config"
  
  FUN=$(whiptail --title "$MENU_TITLE" --backtitle "$SELECTABLE_BACKTITLE" --radiolist "Hardware Platform" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
    "${PLATFORM_MENU_ITEMS[@]}" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      brick) : ;; # Noop because we can't configure hardware on the EV3
      none) clean_raspi_plat_config ;;
      pistorms) clean_raspi_plat_config && uncomment_lines "$RASPI_CONFIG_FILE" "${PISTORMS_CONFIG_LINES[@]}" ;;
      brickpi) clean_raspi_plat_config && uncomment_lines "$RASPI_CONFIG_FILE" "${BRICKPI_CONFIG_LINES[@]}" ;;
      brickpiplus) clean_raspi_plat_config && uncomment_lines "$RASPI_CONFIG_FILE" "${BRICKPIPLUS_CONFIG_LINES[@]}" ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_hardware_menu() {
  current_platform=$(detect_current_platform)
  get_available_hardware_options "$current_platform"
  
  if [ ${#HARDWARE_MENU_OPTIONS[@]} -eq 0 ]; then
    whiptail --msgbox "There are no hardware options for your platform." 20 60 1
    return 0
  fi
  
  FUN=$(whiptail --title "$MENU_TITLE" --menu "Hardware Configuration" --backtitle "$MENU_BACKTITLE" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "${HARDWARE_MENU_OPTIONS[@]}" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      platconfig) do_platform_menu ;;
      serial) do_serial_menu ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

# Serial output selection ===========================================
detect_current_serial_config() {
  sensor_enabled=true
  if grep -q "^\s*$DISABLE_IN_PORT_LINE" "$MODPROBE_EV3_CONF"; then
    sensor_enabled=false
  fi
  
  messages_enabled=false
  if grep -q "#\s*kernel\.printk = 0 4 1 3" "$SYSCTL_EV3_CONF"; then
    messages_enabled=true
  fi
  
  shell_enabled=true
  if systemctl show "$SERIAL_SHELL_SERVICE" | grep -q "LoadState=masked"; then
    shell_enabled=false
  fi
  
  if [ "$sensor_enabled" = true ] && [ "$messages_enabled" = false ] && [ "$shell_enabled" = false ]; then
    echo "sensor"
  elif [ "$sensor_enabled" = false ] && [ "$messages_enabled" = true ] && [ "$shell_enabled" = false ]; then
    echo "messages"
  elif [ "$sensor_enabled" = false ] && [ "$messages_enabled" = false ] && [ "$shell_enabled" = true ]; then
    echo "shell"
  elif [ "$sensor_enabled" = false ] && [ "$messages_enabled" = true ] && [ "$shell_enabled" = true ]; then
    echo "both"
  else
    echo "unknown"
  fi
}

get_serial_menu_state() {
  current_option="$1"
  detected_serial_config="$2"
  
  if [ "$current_option" = "$detected_serial_config" ]; then
    echo "on"
  elif [ "$detected_serial_config" = "unknown" ] && [ "$current_serial_config" = "sensor" ]; then
    echo "on"
  else
    echo "off"
  fi
}

configure_in1_serial() {
  enable_kernel_messages="$1"
  enable_shell="$2"
  
  if [ "$enable_kernel_messages" = false ] && [ "$enable_shell" = false ]; then
    comment_line "$MODPROBE_EV3_CONF" "$DISABLE_IN_PORT_LINE"

    # remove console=ttyS1,115200n8 from the kernel command line
    if grep -q '^LINUX_KERNEL_CMDLINE=".*console=ttyS1,115200n8.*"' \
      /etc/default/flash-kernel
    then
      sed -i 's/^\(LINUX_KERNEL_CMDLINE=".*\)\s\+console=ttyS1,115200n8\(.*"\)/\1\2/' \
        /etc/default/flash-kernel
      flash-kernel
    fi
  else
    uncomment_line "$MODPROBE_EV3_CONF" "$DISABLE_IN_PORT_LINE"

    # add console=ttyS1,115200n8 to the kernel command line
    if ! grep -q '^LINUX_KERNEL_CMDLINE=".*console=ttyS1,115200n8.*"' \
        /etc/default/flash-kernel
    then
      sed -i 's/^\(LINUX_KERNEL_CMDLINE=".*\)"/\1\ console=ttyS1,115200n8"/' \
        /etc/default/flash-kernel
      flash-kernel
    fi
  fi
  
  if [ "$enable_kernel_messages" = true ]; then
    comment_line "$SYSCTL_EV3_CONF" "$DISABLE_KERNEL_MESSAGES_LINE"
  else
    uncomment_line "$SYSCTL_EV3_CONF" "$DISABLE_KERNEL_MESSAGES_LINE"
  fi
  
  if [ "$enable_shell" = true ]; then
    systemctl unmask "$SERIAL_SHELL_SERVICE" 
  else
    systemctl mask "$SERIAL_SHELL_SERVICE" 
  fi
}

do_serial_menu() {
  current_serial_config=$(detect_current_serial_config)
  FUN=$(whiptail --title "$MENU_TITLE" --backtitle "$SELECTABLE_BACKTITLE" --radiolist "Use sensor port 1 (\"in1\") for..." $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
    "sensor" "(recommended) Standard sensor input port" $(get_serial_menu_state sensor $current_serial_config) \
    "messages" "Kernel debug message output" $(get_serial_menu_state messages $current_serial_config) \
    "shell" "Shell with login prompt" $(get_serial_menu_state shell $current_serial_config) \
    "both" "Shell with login prompt *and* kernel debug messages" $(get_serial_menu_state both $current_serial_config) \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      sensor) configure_in1_serial false false ;;
      messages) configure_in1_serial true false ;;
      shell) configure_in1_serial false true ;;
      both) configure_in1_serial true true ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    
    new_serial_config=$(detect_current_serial_config)
    if [ "$new_serial_config" != "$current_serial_config" ]; then
        ASK_TO_REBOOT=1
    fi
  fi
}

# Misc menus and simple functionality ===============================
do_warn_wait() {
  whiptail --msgbox "\
This functionality may take 30 seconds or more to load.
Please be patient.\
" 20 70 1
}

do_about() {
  whiptail --msgbox "\
This tool provides a straight-forward way of doing initial
configuration of an ev3dev system. Although it can be run
at any time, some of the options may have difficulties if
you have heavily customised your installation.\
" 20 70 1
}

do_sysinfo() {
  whiptail --msgbox "$(ev3dev-sysinfo)\n\nTo get this information in copyable format, use \"ev3dev-sysinfo\" from the terminal." 20 70 1
}

do_change_pass() {
  whiptail --yesno "You will now be asked to enter a new password for the robot user." --yes-button "OK" --no-button "Cancel" 20 60 1 3>&1 1>&2 2>&3
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    passwd robot &&
    whiptail --msgbox "Password changed successfully" 20 60 1
  fi
}

do_configure_keyboard() {
  do_warn_wait
  dpkg-reconfigure keyboard-configuration &&
  printf "Reloading keymap. This may take a short while\n" &&
  invoke-rc.d keyboard-setup start
}

do_change_locale() {
  do_warn_wait
  dpkg-reconfigure locales
}

do_change_timezone() {
  do_warn_wait
  dpkg-reconfigure tzdata
}

do_change_hostname() {  
  whiptail --msgbox "\
Please note: Hostnames should only contain the
ASCII letters 'a' through 'z' (case-insensitive), 
the digits '0' through '9', and the hyphen.
Hostname labels also shouldn't begin or end
with a hyphen, and other symbols, punctuation
characters, and blank spaces should be avoided.\
" 20 70 1

  CURRENT_HOSTNAME="$(get_current_hostname)"
  NEW_HOSTNAME=$(whiptail --inputbox "Please enter the desired new hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    hostnamectl set-hostname "$NEW_HOSTNAME"
    killall -SIGHUP --quiet bluetoothd || true
    systemctl try-restart avahi-daemon.service || true
    # FIXME: restarting nmbd takes a long time, but there does not seem to be
    # another way to get it to pick up the new host name. e.g. `smbcontrol nmbd
    # reload-config` does not work.
    systemctl try-restart nmbd.service || true
    # TODO: also need to release/renew DCHP in case DHCP server is also DNS.
  fi
}

do_update() {
  apt-get update &&
  apt-get upgrade &&
  apt-get dist-upgrade
}

do_finish() {
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Some operations that have been performed require a reboot to fully function. Would you like to reboot now?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      reboot
    fi
  fi
  exit 0
}

# Service selection =================================================
get_service_status() {
  for service_name in "${!TARGET_SERVICES[@]}"; do
    if [ "$service_name" = "nmbd" ]; then
      if /etc/init.d/nmbd status | grep -q "active (running)"; then
        service_is_enabled="enabled"
      else
        service_is_enabled="disabled"
      fi
    else
      service_is_enabled=$(systemctl is-enabled $service_name)
    fi
    SERVICE_STATUS["$service_name"]="$service_is_enabled"
  done
}

get_service_checklist_options() {
  SERVICE_CHECKLIST_OPTIONS=()
  for service_name in "${!SERVICE_STATUS[@]}"; do
    service_check_state="off"
    if [ ${SERVICE_STATUS["$service_name"]} == "enabled" ]; then
        service_check_state="on"
    fi
    
    SERVICE_CHECKLIST_OPTIONS=("${SERVICE_CHECKLIST_OPTIONS[@]}" "$service_name" "${TARGET_SERVICES["$service_name"]}" "$service_check_state")
  done
}

transform_service_checklist_options() {
  NEW_SERVICE_STATUS=()
  for service_name in "${!TARGET_SERVICES[@]}"; do
    # whiptail returns quoted names, so we need to add quotes for the comparison
    contains_element "\"$service_name\"" "$@"
    contain_result=$?
    
    if [ $contain_result -eq 0 ]; then
      NEW_SERVICE_STATUS["$service_name"]="enabled"
    else
      NEW_SERVICE_STATUS["$service_name"]="disabled"
    fi
  done
}

apply_service_changes() {
  for service_name in "${!TARGET_SERVICES[@]}"; do
    original_state="${SERVICE_STATUS["$service_name"]}"
    new_state="${NEW_SERVICE_STATUS["$service_name"]}"
    
    echo "$service_name had an original state of $original_state and has a new state of $new_state"
    if [ "$original_state" = "disabled" ] && [ "$new_state" = "enabled" ]; then
      echo "  Enabling $service_name"
      systemctl enable "$service_name"
      systemctl start "$service_name"
    elif [ "$original_state" = "enabled" ] && [ "$new_state" = "disabled" ]; then
      echo "  Disabling $service_name"
      systemctl stop "$service_name"
      systemctl disable "$service_name"
    fi
  done
}

do_service_menu() {
  get_service_status
  get_service_checklist_options
  
  FUN=$(whiptail --title "$MENU_TITLE" --checklist "Enable/Disable Services" --backtitle "$SELECTABLE_BACKTITLE" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
    "${SERVICE_CHECKLIST_OPTIONS[@]}" \
    3>&1 1>&2 2>&3)
  RET=$?
  
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    transform_service_checklist_options $FUN
    apply_service_changes
  fi
}

# Main menus ========================================================
do_internationalization_menu() {
  FUN=$(whiptail --title "$MENU_TITLE" --menu "Internationalization Options" --backtitle "$MENU_BACKTITLE" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "I1 Change Locale" "Set up language and regional settings to match your location" \
    "I2 Change Timezone" "Set up timezone to match your location" \
    "I3 Change Keyboard Layout" "Set the keyboard layout to match your keyboard" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      I1\ *) do_change_locale ;;
      I2\ *) do_change_timezone ;;
      I3\ *) do_configure_keyboard ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_advanced_menu() {
  FUN=$(whiptail --title "$MENU_TITLE" --menu "Advanced Options" --backtitle "$MENU_BACKTITLE" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "A1 Hostname" "Set the visible name for this ev3dev device on a network" \
    "A2 Enable/Disable Services" "Enable/Disable system services to free up system resources" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      A1\ *) do_change_hostname ;;
      A2\ *) do_service_menu ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}


# Everything needs to be run as root
if [ $(id -u) -ne 0 ]; then
  printf "Script must be run as root. Try 'sudo ev3dev-config'\n"
  exit 1
fi

#
# Interactive use loop
#
calc_wt_size
while true; do
  FUN=$(whiptail --title "$MENU_TITLE" --menu "Setup Options" --backtitle "$MENU_BACKTITLE" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
    "1 Change User Password" "Change password for the default user (robot)" \
    "2 Hardware Configuration" "Configure EV3-related drivers" \
    "3 Update" "Update all packages" \
    "4 Advanced Options" "Configure advanced settings" \
    "5 System Info" "Get information on your ev3dev system" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_finish
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      1\ *) do_change_pass ;;
      2\ *) do_hardware_menu ;;
      3\ *) do_update ;;
      4\ *) do_advanced_menu ;;
      5\ *) do_sysinfo ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  else
    exit 1
  fi
done
