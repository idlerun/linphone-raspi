#!/bin/bash
cd $(dirname $0)
docker build -t linphone-raspi -f $(pwd)/Dockerfile /opt/vc
docker rm -f linphone-raspi &>/dev/null
docker create --name linphone-raspi linphone-raspi
rm -rf bin
mkdir -p bin
#docker cp linphone-raspi:/src/v4l2rtspserver-0.1.0/v4l2rtspserver-0.1.0 bin/v4l2rtspserver
docker rm -f linphone-raspi &>/dev/null
