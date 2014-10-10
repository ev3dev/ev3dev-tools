#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# regulation-time - Test set for running motors
#
# regulation_mode on
# run_mode        time
#
# Refer to the "bats" documentation to understand how the test framework
# operates

load test_helper

# ------------------------------------------------------------------------------
# This part executes once for preprocessing, then once again for every test
# in the file. To make sure we only spend time looking for the motor once, we
# can check to see if port is initialized first.
#
# Here's also where we set up the common features for the test set

if [[ -z "${port}" ]]; then
    export port=$(find_motor_port "outA")
#   echo "# outA -> ${port}"
fi

# ------------------------------------------------------------------------------

setup() {
    echo  "0" > "${port}/run"
}

teardown() {
    echo  "0" > "${port}/run"
}

# ------------------------------------------------------------------------------

@test "Check that the tacho-motor class folder exists" {
    [ -d "/sys/class/tacho-motor" ]
}

@test "Check that the tacho-motor device folder exists" {
    [ -d "${port}" ]
}

@test "Check   0 msec ramp_up/time/ramp_down - stop_mode coast" {
    setup_regulated_motor 600 "time" "coast" 0 2000 0 
    verify_time 2000
}

@test "Check   1 msec ramp_up/time/ramp_down - stop_mode brake" {
    setup_regulated_motor -600 "time" "brake" 1 2000 1 
    verify_time 2000
}

@test "Check   2 msec ramp_up/time/ramp_down - stop_mode coast" {
    setup_regulated_motor 600 "time" "cost" 1 2000 1 
    verify_time 2000
}

@test "Check   3 msec ramp_up/time/ramp_down - stop_mode brake" {
    setup_regulated_motor -600 "time" "brake" 1 2000 1 
    verify_time 2000
}

@test "Check 250 msec ramp_up/time/ramp_down - stop_mode brake" {
    setup_regulated_motor 600 "time" "brake" 250 2000 250 
    verify_time 2000
}

@test "Check coincident ramp_up/time/ramp_down - stop_mode brake" {
    setup_regulated_motor -600 "time" "brake" 1000 2000 1000 
    verify_time 2000
}

@test "Check overlapping ramp_up/time/ramp_down - stop_mode brake" {
    setup_regulated_motor 600 "time" "brake" 2000 2000 2000 
    verify_time 2000
}
