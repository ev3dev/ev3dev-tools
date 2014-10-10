#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# regulation-forever.bats - Test set for running motors
#
# regulation_mode on
# run_mode        forever
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

@test "Check assorted speeds - stop_mode coast" {
    setup_regulated_motor 0 "forever" "coast" 0 0 0 
    test_speeds " 900  600    0  200  400    0" 5
}

@test "Check assorted speeds - stop_mode brake" {
    setup_regulated_motor 0 "forever" "brake" 0 0 0
    test_speeds "-900 -600    0 -200 -400    0" 5
}
