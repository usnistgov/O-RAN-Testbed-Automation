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

set -e

MIRROR="http://archive.ubuntu.com/ubuntu"
SECURITY_MIRROR="http://security.ubuntu.com/ubuntu"

usage() {
    echo "Usage: $0 [mirror-url]"
    echo "    Set Ubuntu APT archive sources to the Ubuntu main server, or to mirror-url if provided."
    echo "    Changed files are backed up and apt-get update runs only when changes are made."
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
elif [ $# -gt 1 ]; then
    usage
    exit 1
elif [ $# -eq 1 ]; then
    MIRROR="$1"
fi

OS_ID=""
if [ -f /etc/os-release ]; then
    OS_ID=$(grep '^ID=' /etc/os-release | head -n 1 | cut -d= -f2 | tr -d '"')
fi
if [ "$OS_ID" != "ubuntu" ]; then
    echo "ERROR: This helper only supports Ubuntu APT source files."
    exit 1
fi

MIRROR=${MIRROR%/}
SECURITY_MIRROR=${SECURITY_MIRROR%/}

if [ -z "$MIRROR" ]; then
    echo "ERROR: mirror-url cannot be empty."
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d%H%M%S)
UPDATED_ANY=false

for SOURCE_FILE in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    if [ ! -f "$SOURCE_FILE" ]; then
        continue
    fi
    if ! grep -Eq 'ubuntu\.com/ubuntu([[:space:]/]|$)' "$SOURCE_FILE"; then
        continue
    fi

    BEFORE_HASH=$(sha256sum "$SOURCE_FILE" | awk '{print $1}')

    TMP_FILE=$(mktemp)
    awk -v mirror="$MIRROR" -v security_mirror="$SECURITY_MIRROR" '
    /^[[:space:]]*#/ {
        print
        next
    }
    /^[[:space:]]*URIs:/ && /ubuntu\.com\/ubuntu([[:space:]\/]|$)/ {
        if ($0 ~ /security\.ubuntu\.com/) {
            print "URIs: " security_mirror
        } else {
            print "URIs: " mirror
        }
        next
    }
    /^[[:space:]]*deb/ && /ubuntu\.com\/ubuntu([[:space:]\/]|$)/ {
        suite = ""
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^https?:\/\/[^[:space:]]*ubuntu\.com\/ubuntu\/?$/) {
                uri_field = i
                suite = $(i + 1)
                break
            }
        }

        if (suite ~ /-security$/) {
            $uri_field = security_mirror
        } else {
            $uri_field = mirror
        }

        print
        next
    }
    {
        print
    }
    ' "$SOURCE_FILE" >"$TMP_FILE"

    if cmp -s "$SOURCE_FILE" "$TMP_FILE"; then
        rm -f "$TMP_FILE"
        continue
    fi

    echo "Updating $SOURCE_FILE..."
    sudo cp -a "$SOURCE_FILE" "$SOURCE_FILE.bak.$TIMESTAMP"
    sudo install -m 0644 "$TMP_FILE" "$SOURCE_FILE"
    rm -f "$TMP_FILE"

    AFTER_HASH=$(sha256sum "$SOURCE_FILE" | awk '{print $1}')
    if [ "$BEFORE_HASH" != "$AFTER_HASH" ]; then
        UPDATED_ANY=true
    fi
done

if [ "$UPDATED_ANY" = true ]; then
    echo "Successfully updated APT mirror configuration. Backups use suffix .bak.$TIMESTAMP."
    sudo apt-get update
else
    echo "No Ubuntu APT mirror entries needed to be updated."
fi

echo
echo "Ubuntu APT mirrors currently being used:"
grep -RHEh '^[[:space:]]*(deb|URIs:).*ubuntu\.com/ubuntu' \
    /etc/apt/sources.list \
    /etc/apt/sources.list.d/*.list \
    /etc/apt/sources.list.d/*.sources \
    2>/dev/null |
    awk '
		/^[[:space:]]*URIs:/ {
			print $2
			next
		}
		/^[[:space:]]*deb/ {
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^https?:\/\/[^[:space:]]*ubuntu\.com\/ubuntu\/?$/) {
					sub(/\/$/, "", $i)
					print $i
				}
			}
		}
	' |
    sort -u |
    sed 's/^/  - /'
