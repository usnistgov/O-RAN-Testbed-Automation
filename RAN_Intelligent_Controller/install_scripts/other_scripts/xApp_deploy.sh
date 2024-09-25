cd hw-go

# docker build -t example.com:80/hw-go:1.2 .
# export CHART_REPO_URL=http://0.0.0.0:8090
# subl config/config-file.json
# • modify tag = 1.2, under containers.image
# • modify registry with example.com:80 under containers.image
# • modify name with hw-go, under containers.image

docker save -o hw-go.tar example.com:80/hw-go:1.2
sudo ctr -n=k8s.io image import hw-go.tar

dms_cli onboard ./config/config-file.json ./config/schema.json

dms_cli uninstall hw-go ricxapp
dms_cli install hw-go 1.0.0 ricxapp

cd ..
./check_xApp_deployed_status.sh
