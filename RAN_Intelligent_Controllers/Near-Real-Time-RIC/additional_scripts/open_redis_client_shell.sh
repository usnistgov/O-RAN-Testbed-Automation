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

echo -e "\nConnecting to Redis CLI within the Kubernetes pod..."
echo -e "Below are some example commands to interact with the Redis database:\n"
echo -e "  KEYS *\t\t\t\tLists all keys in the database"
echo -e "  TYPE <key-name>\t\t\tDetermines the type of a key"
echo -e "  GET <key-name>\t\t\tRetrieves the value of a specific key if it is a string"
echo -e "  SMEMBERS <set-name>\t\t\tIf key is a set, lists all members of the set"
echo -e "  LRANGE <list-name> 0 -1\t\tIf key is a list, lists all elements in the list"
echo -e "  HGETALL <hash-key-name>\t\tIf key is a hash, retrieves all fields and values of the hash"
echo -e "  ZRANGE <sorted-set-name> 0 -1 WITHSCORES\tIf key is a sorted set, lists all members with their scores"
echo -e "  SCAN 0\t\t\t\tIteratively lists keys in the database in a cursor-based manner"
echo -e "\nType 'exit' to leave the Redis CLI and return to your shell."

kubectl exec -n corbin-oran -it statefulset-ricplt-dbaas-server-0 -c container-ricplt-dbaas-redis -- redis-cli
