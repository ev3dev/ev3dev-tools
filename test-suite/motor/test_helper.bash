#!/usr/bin/env bash

find_motor_port() {
    if [ -d /sys/bus/legoev3/devices/${1}:ev3-tacho-motor ]; then
            m=$(basename /sys/bus/legoev3/devices/${1}:ev3-tacho-motor/tacho-motor/*)
            echo -n "/sys/class/tacho-motor/${m}"
            return 0
        fi
    echo -n ""
    return 0
}

# ------------------------------------------------------------------------------
# setup_motor( run_mode, stop_mode, ramp_up_sp, time_sp, ramp_down_sp )

_setup_motor() {
    echo   "${1:-"time"}" > "${port}/run_mode" 
    echo  "${2:-"coast"}" > "${port}/stop_mode" 
    echo      "${3:-"0"}" > "${port}/ramp_up_sp" 
    echo      "${4:-"0"}" > "${port}/time_sp" 
    echo      "${5:-"0"}" > "${port}/ramp_down_sp" 
    return 0
}

# ------------------------------------------------------------------------------
# setup_regulated_motor( pulses_per_second_sp, run_mode, stop_mode, ramp_up_sp, time_sp, ramp_down_sp )

setup_regulated_motor() {
    echo          "0" > "${port}/run"
    echo         "on" > "${port}/regulation_mode" 
    echo  "${1:-"0"}" > "${port}/pulses_per_second_sp" 
    _setup_motor ${2} ${3} ${4} ${5} ${6}
    return 0
}

# ------------------------------------------------------------------------------
# setup_unregulated_motor( duty_cycle_sp, run_mode, stop_mode, ramp_up_sp, time_sp, ramp_down_sp )

setup_unregulated_motor() {
    echo  "0"             > "${port}/run"
    echo  "${1:-"0"}"     > "${port}/duty_cycle_sp" 
    _setup_motor ${2} ${3} ${4} ${5} ${6}
    return 0
}

# verify_speed( target_speed, %tolerance )

verify_speed() {
    pulses_per_second=$(cat "${port}/pulses_per_second")
    tolerance=${2:-"5"} 
    loside=$(( ( ${1} * (100 - ${tolerance}) ) / 100 ))
    hiside=$(( ( ${1} * (100 + ${tolerance}) ) / 100 ))

    if [ 0 -le ${pulses_per_second} ]; then
        return $(( ( ${loside} > ${pulses_per_second} ) || ( ${hiside} < ${pulses_per_second} ) ))
    else
        return $(( ( ${loside} < ${pulses_per_second} ) || ( ${hiside} > ${pulses_per_second} ) ))
    fi
}

# test_speeds( speedlist, %tolerance )

test_speeds() {
    echo "1" > "${port}/run"

    for s in ${1}; do
        echo "${s}" > "${port}/pulses_per_second_sp"
	sleep 1
        if [ 0 != $(verify_speed ${s} ${2}) ] ; then
	    return 1
        fi
    done

    echo "0" > "${port}/run"

    return 0
}

# verify_position( target_position, tolerance )

verify_position() {
    position=$(cat "${port}/position")
    tolerance=${2:-"5"} 
    loside=$(( ${1} - ${tolerance} ))
    hiside=$(( ${1} + ${tolerance} ))
    
    echo $(( ( ${loside} > ${position} ) || ( ${hiside} < ${position} ) ))
}

# test_absolute_positions( positionlist, tolerance )
#
# This script uses a bit of a trick, it puts the sysfs_notify_monitor
# process in the background before turning on the motor, then it waits
# for the backgound task to finish.
#
# That's because very short motor movements finish before the next
# command runs in the bats framework - it took a while for me to figure
# this out :-)

test_absolute_positions() {
    echo "absolute" > "${port}/position_mode"
    echo        "0" > "${port}/position"

    for p in ${1}; do
        echo "${p}" > "${port}/position_sp"
        sysfs_notify_monitor -t 8000 "${port}/state" &
        echo    "1" > "${port}/run"
        wait
        if [ "0" != $(verify_position ${p} ${2}) ] ; then
	    return 1
        fi
    done
    return 0
}

# test_relative_positions( positionlist, tolerance )
#
# This script uses a bit of a trick, it puts the sysfs_notify_monitor
# process in the background before turning on the motor, then it waits
# for the backgound task to finish.
#
# That's because very short motor movements finish before the next
# command runs in the bats framework - it took a while for me to figure
# this out :-)

test_relative_positions() {
    echo "relative" > "${port}/position_mode"
    echo        "0" > "${port}/position"
    target=0;

    for p in ${1}; do
        echo -n -e "# ${target} + ${p} -> " >&3
        target=$(( ${target} + ${p} ))
        echo "${p}" > "${port}/position_sp"
        sysfs_notify_monitor -t 8000 "${port}/state" &
        echo    "1" > "${port}/run"
        wait
        position=$(cat "${port}/position")
        echo -n -e "${position}\n" >&3
        if [ 0 != $(verify_position ${target} ${2}) ] ; then
	    return 1
        fi
    done
    return 0
}


# verify_time( time )

verify_time() {
    sysfs_notify_monitor -t $(( ${1} + 300 )) "${port}/state" &
    bgnotify=$!
    echo    "1" > "${port}/run"
    wait ${bgnotify}
    return $?
}
