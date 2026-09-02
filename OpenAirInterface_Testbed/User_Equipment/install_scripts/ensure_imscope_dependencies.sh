#!/bin/bash
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

# Exit immediately if a command fails
set -e

# Repair missing ImScope dependencies in existing CPM ImGui

CPM_CACHE_ROOT=${CPM_SOURCE_CACHE:-"$HOME/.cache/cpm"}
IMGUI_CACHE_ROOT="$CPM_CACHE_ROOT/imgui"

if [ ! -d "$IMGUI_CACHE_ROOT" ]; then
    exit 0
fi

REQUIRED_FILES=(
    imgui.cpp
    imgui.h
    imconfig.h
    imgui_demo.cpp
    imgui_draw.cpp
    imgui_internal.h
    imgui_tables.cpp
    imgui_widgets.cpp
    imstb_rectpack.h
    imstb_textedit.h
    imstb_truetype.h
    backends/imgui_impl_glfw.cpp
    backends/imgui_impl_glfw.h
    backends/imgui_impl_opengl3.cpp
    backends/imgui_impl_opengl3.h
    backends/imgui_impl_opengl3_loader.h
)

while IFS= read -r GIT_DIR; do
    IMGUI_CHECKOUT=${GIT_DIR%/.git}
    ORIGIN=$(git -C "$IMGUI_CHECKOUT" remote get-url origin 2>/dev/null || true)
    case "$ORIGIN" in
    *ocornut/imgui*) ;;
    *) continue ;;
    esac

    MISSING_FILES=()
    for REQUIRED_FILE in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$IMGUI_CHECKOUT/$REQUIRED_FILE" ]; then
            MISSING_FILES+=("$REQUIRED_FILE")
        fi
    done

    if [ ${#MISSING_FILES[@]} -eq 0 ]; then
        continue
    fi

    for MISSING_FILE in "${MISSING_FILES[@]}"; do
        if ! git -C "$IMGUI_CHECKOUT" cat-file -e "HEAD:$MISSING_FILE" 2>/dev/null; then
            echo "ERROR: ImScope dependency $MISSING_FILE is missing and is not available in the pinned ImGui commit."
            exit 1
        fi
    done

    echo "Repairing missing ImScope files in CPM cache: ${MISSING_FILES[*]}"
    git -C "$IMGUI_CHECKOUT" restore --source=HEAD -- "${MISSING_FILES[@]}"
done < <(find "$IMGUI_CACHE_ROOT" -type d -name .git -print)
