if ! command -v yq &>/dev/null; then
    echo "Installing yq..."
    YQ_PATH="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    sudo wget $YQ_PATH -O /usr/bin/yq
    sudo chmod +x /usr/bin/yq
    # Uninstall with: sudo rm -rf /usr/bin/yq
fi

# Function to update YAML configuration files
update_yaml() {
    local FILE_PATH=$1
    local PROPERTY=$2
    local VALUE=$3
    echo "Updating $FILE_PATH: setting $PROPERTY to $VALUE"
    if [[ "$VALUE" == "true" || "$VALUE" == "false" ]]; then
        yq e "$PROPERTY = $VALUE" -i $FILE_PATH
    else
        yq e "$PROPERTY = \"$VALUE\"" -i $FILE_PATH
    fi
}

if [ ! -d dep ]; then
    echo "Cloning Non-RT RIC..."
    git clone --recursive https://gerrit.o-ran-sc.org/r/it/dep
fi
cd dep/

echo "Revising example recipe..."
RECIPE_PATH="RECIPE_EXAMPLE/NONRTRIC/example_recipe_MODIFIED.yaml"
cp RECIPE_EXAMPLE/NONRTRIC/example_recipe.yaml $RECIPE_PATH

update_yaml $RECIPE_PATH '.nonrtric.installPms' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installA1controller' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installA1simulator' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installControlpanel' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installInformationservice' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installRappcatalogueservice' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installRappcatalogueenhancedservice' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installNonrtricgateway' 'false'
update_yaml $RECIPE_PATH '.nonrtric.installKong' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installDmaapadapterservice' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installDmaapmediatorservice' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installHelmmanager' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installOrufhrecovery' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installRansliceassurance' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installCapifcore' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installServicemanager' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installRanpm' 'false'
update_yaml $RECIPE_PATH '.nonrtric.installrAppmanager' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installDmeParticipant' 'false'
update_yaml $RECIPE_PATH '.nonrtric.volume1.size' '2Gi'
update_yaml $RECIPE_PATH '.nonrtric.volume1.storageClassName' 'pms-storage'
update_yaml $RECIPE_PATH '.nonrtric.volume1.hostPath' '/var/nonrtric/pms-storage'
update_yaml $RECIPE_PATH '.nonrtric.volume2.size' '2Gi'
update_yaml $RECIPE_PATH '.nonrtric.volume2.storageClassName' 'ics-storage'
update_yaml $RECIPE_PATH '.nonrtric.volume2.hostPath' '/var/nonrtric/ics-storage'
update_yaml $RECIPE_PATH '.nonrtric.volume3.size' '1Gi'
update_yaml $RECIPE_PATH '.nonrtric.volume3.storageClassName' 'helmmanager-storage'

sudo ./bin/deploy-nonrtric -f ./RECIPE_EXAMPLE/NONRTRIC/example_recipe_MODIFIED.yaml
