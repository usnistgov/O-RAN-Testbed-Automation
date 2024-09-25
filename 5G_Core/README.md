### Custom PLMN and TAC Identifiers
To select a different PLMN and TAC ID, modify the contents of `5G_Core/options.yaml`, then apply the changes with:
```
./generate_configurations.sh
./stop.sh
./run.sh

cd ../gNodeB

./generate_configurations.sh

cd ../5G_Core
```
