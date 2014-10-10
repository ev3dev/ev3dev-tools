#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# regulation-relative-position.bats - Test set for running motors
#
# regulation_mode on
# run_mode        position
# position_mode   relative
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
#    echo "# outA -> ${port}"
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

@test "Check   0 msec ramp_up/ramp_down - medium speed - stop_mode coast" {
    setup_regulated_motor 450 "position" "coast" 0 0 0 
    test_relative_positions "90 90 180 360 -360 -180 -90 -90" 360
}

@test "Check 500 msec ramp_up/ramp_down - medium speed - stop_mode coast" {
    setup_regulated_motor 450 "position" "coast" 500 0 500 
    test_relative_positions "90 90 180 360 -360 -180 -90 -90" 15
}

@test "Check   0 msec ramp_up/ramp_down - medium speed - stop_mode brake" {
    setup_regulated_motor 450 "position" "brake" 0 0 0 
    test_relative_positions "90 90 180 360 -360 -180 -90 -90" 30
}

@test "Check 500 msec ramp_up/ramp_down - medium speed - stop_mode brake" {
    setup_regulated_motor 450 "position" "brake" 200 0 200 
    test_relative_positions "90 90 180 360 -360 -180 -90 -90" 10
}

@test "Check   0 msec ramp_up/ramp_down - medium speed - stop_mode hold" {
    setup_regulated_motor 450 "position" "hold" 0 0 0 
    test_relative_positions "90 90 180 360 -360 -180 -90 -90" 5
}

@test "Check 200 msec ramp_up/ramp_down - medium speed - stop_mode hold" {
    setup_regulated_motor 450 "position" "hold" 200 0 200 
    test_relative_positions "90 90 180 360 -360 -180 -90 -90" 5
}
