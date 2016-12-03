#!/bin/bash
#
# Cronjob to keep bloonix satellite docker image and running
# container up to date on Raspberry Pi Bloonix Satellites
# Also clean up to save space

#set -x

SATELLITE_AUTHKEY='@@@SATELLITE_AUTH_KEY@@@'


# Remove all images not assigned to any containers (if any containers are actually running, or it will remove all images)
# This will fail on images used by running containers - we dont want to remove them
if docker ps | grep BloonixSatellite; then
    docker rmi $(grep -xvf <(docker ps -a --format '{{.Image}}') <(docker images | tail -n +2 | grep -v '<none>' | awk '{ print $1":"$2 }'))
fi

# Pull latest image for raspberrypi / ARM
docker pull satellitesharing/bloonix-satellite:arm

# Stop and rename the previous container
docker stop BloonixSatellite
docker rename BloonixSatellite BloonixSatelliteOLD

# Start the new container
docker run \
    -d \
    --name BloonixSatellite \
    -p 0.0.0.0:5464:5464 \
    --fail \
    --memory="768m" \
    -e AUTHKEY="$SATELLITE_AUTHKEY" \
    -t satellitesharing/bloonix-satellite:arm

# Fail back to the old container version if the new one didnt start
sleep 5
if ! docker ps | grep BloonixSatellite; then
    echo FAILING BACK TO OLD VERSION
    docker rename BloonixSatellite BloonixSatelliteFAILED
    docker rename BloonixSatelliteOLD BloonixSatellite
    docker run \
        -d \
        --name BloonixSatellite \
        -p 0.0.0.0:5464:5464 \
        --memory="768m" \
        -e AUTHKEY="$SATELLITE_AUTHKEY" \
        -t satellitesharing/bloonix-satellite:arm
else
    # Remove old container
    docker rm BloonixSatelliteOLD
fi


exit 0
