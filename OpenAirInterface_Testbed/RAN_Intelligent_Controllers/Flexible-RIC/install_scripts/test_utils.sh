#!/bin/bash
# test_utils.sh - A test runner for utils.sh
#
# NIST-developed software is provided by NIST as a public service. You may use,
# copy, and distribute copies of the software in any medium, provided that you
# keep intact this entire notice. You may improve, modify, and create derivative
# works of the software or any portion of the software, and you may copy and
# distribute such modifications or works. Modified works should carry a notice
# stating that you changed the software and should note the date and nature of
# any such change. Please explicitly acknowledge the National Institute of
# Standards and Technology as the source of the software.
#
# NIST-developed software is expressly provided "AS IS." NIST MAKES NO WARRANTY
# OF ANY KIND, EXPRESS, IMPLIED, IN FACT, OR ARISING BY OPERATION OF LAW,
# INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND DATA ACCURACY. NIST
# NEITHER REPRESENTS NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE
# UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE CORRECTED. NIST DOES
# NOT WARRANT OR MAKE ANY REPRESENTATIONS REGARDING THE USE OF THE SOFTWARE OR
# THE RESULTS THEREOF, INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY,
# RELIABILITY, OR USEFULNESS OF THE SOFTWARE.
#
# You are solely responsible for determining the appropriateness of using and
# distributing the software and you assume all risks associated with its use,
# including but not limited to the risks and costs of program errors, compliance
# with applicable laws, damage to or loss of data, programs or equipment, and
# the unavailability or interruption of operation. This software is not intended
# to be used in any situation where a failure could cause risk of injury or
# damage to property. The software developed by NIST employees is not subject to
# copyright protection within the United States.

# 1. Source the library
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/utils.sh"

# --- THE TEST ENGINE ---

TOTAL_TESTS=0
FAILED_TESTS=0

# Core assertion function
# Usage: assert_eq "expected" "actual" "description"
assert_eq() {
    ((TOTAL_TESTS++))
    local expected="$1"
    local actual="$2"
    local desc="$3"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "  [\e[32mPASS\e[0m] $desc"
    else
        echo -e "  [\e[31mFAIL\e[0m] $desc"
        echo "           Expected: '$expected'"
        echo "           Actual:   '$actual'"
        ((FAILED_TESTS++))
    fi
}

# --- TEST SUITES ---

# Suite for convert_to_ssh function
test_suite_url_conversion() {
    echo "Running Suite: URL Conversion..."

    assert_eq "git@gitlab.someorg.org:projectname/test.git" \
        "$(convert_to_ssh https://gitlab.someorg.org/gitlab/projectname/test.git)" \
        "gitlab prefix removal"

    assert_eq "git@github.com:user/repo.git" \
        "$(convert_to_ssh https://github.com/user/repo.git)" \
        "Standard GitHub conversion"

    assert_eq "git@github.com:user/repo.git" \
        "$(convert_to_ssh git@github.com:user/repo.git)" \
        "Already SSH (no-operation)"
}

# --- MAIN RUNNER ---

echo "========================================"
echo "STARTING UTILS TESTS"
echo "========================================"

test_suite_url_conversion

echo "========================================"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\e[32mOVERALL RESULT: SUCCESS\e[0m"
    echo "Tests Passed: $TOTAL_TESTS / $TOTAL_TESTS"
    exit 0
else
    echo -e "\e[31mOVERALL RESULT: FAILED\e[0m"
    echo "Tests Failed: $FAILED_TESTS / $TOTAL_TESTS"
    exit 1
fi
