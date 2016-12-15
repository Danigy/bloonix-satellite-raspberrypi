#!/bin/bash
#
# Cronjob to keep bloonix satellite docker image and running
# container up to date on Raspberry Pi Bloonix Satellites
# Also clean up to save space


## Source the config file'
source /opt/bloonix-satellite-raspberrypi/config.sh
if [[ -z $SATELLITE_AUTHKEY ]]; then
    echo 'The variable SATELLITE_AUTHKEY could not be sourced from /opt/bloonix-satellite-raspberrypi/config.sh, aborting!'
    exit 1
fi



## Functions

# Pull a docker image
# $1  path of image to pull
docker_pull_image(){
    docker pull $1
}

# Remove all images not assigned to any containers (if any containers are actually running, or it will remove all images)
# This will fail on images used by running containers - thats ok as we dont want to remove them
docker_remove_unassigned_images(){
    docker rmi $(grep -xvf <(docker ps -a --format '{{.Image}}') <(docker images | tail -n +2 | grep -v '<none>' | awk -v OFS=: '{ print $1, $2 }')) 2> /dev/null
}

# Start a bloonix satellite container
# $1  Locally bound VPN Client IP for tun0
# $2  Bloonix Satellite Authkey
docker_start_satellite(){
    docker run \
        -d \
        --name BloonixSatellite \
        -p ${1}:5464:5464 \
        --memory="768m" \
        -e AUTHKEY="$2" \
        -t satellitesharing/bloonix-satellite:arm
}




## Main

# Debug
#set -x

# Clean up eventual previous attempts
echo 'INFO:  Cleaning up eventual old containers'
docker ps -a | grep ${CONTAINER_NAME}Old 2>&1 >/dev/null && docker rm ${CONTAINER_NAME}Old
docker ps -a | grep ${CONTAINER_NAME}Failed 2>&1 >/dev/null && docker rm ${CONTAINER_NAME}Failed
# If there is a stopped container named $CONTAINER_NAME, we need to delete that one too
docker ps -a | grep $CONTAINER_NAME | grep Exited 2>&1 >/dev/null && docker rm $CONTAINER_NAME

# Update the image
echo 'INFO:  Updating the image'
docker_pull_image $IMAGE


# Make sure a container is running at the moment
if ! docker ps | grep $CONTAINER_NAME 2>&1 >/dev/null; then

    echo 'INFO:  No container is running - start one'
    docker_start_satellite "$VPN_CLIENT_IP" "$SATELLITE_AUTHKEY"

# The container is already running
else

    echo 'INFO:  A container is already running, processing it'
    # Gather data about the container and image to compare running and latest version
    LATEST=`docker inspect --format "{{.Id}}" $IMAGE`
    RUNNING=`docker inspect --format "{{.Image}}" $CONTAINER_NAME`
    CONTAINER_NAME=`docker inspect --format '{{.Name}}' $CONTAINER_NAME | sed "s/\///g"`
    echo "INFO:  Latest:" $LATEST
    echo "INFO:  Running:" $RUNNING

    # Check if we have to update
    if [ "$RUNNING" != "$LATEST" ];then
        echo "INFO:  Upgrading $CONTAINER_NAME"

        # "Save" the old container in case the new one doesnt start
        echo "INFO:  Renaming old $CONTAINER_NAME to ${CONTAINER_NAME}Old"
        docker stop $CONTAINER_NAME
        docker rename $CONTAINER_NAME ${CONTAINER_NAME}Old

        # Start the new container
        echo "INFO:  Starting new $CONTAINER_NAME"
        docker_start_satellite "$VPN_CLIENT_IP" "$SATELLITE_AUTHKEY"

        # Fail back to the old container version if the new one didnt start
        sleep 5
        echo "WARN:  The newly started container ${CONTAINER_NAME} Exited, falling back to old one ${CONTAINER_NAME}Old"
        if ! docker ps | grep $CONTAINER_NAME 2>&1 >/dev/null; then
            echo FALLING BACK TO OLD VERSION
            docker rename $CONTAINER_NAME ${CONTAINER_NAME}Failed
            docker rename ${CONTAINER_NAME}Old $CONTAINER_NAME
            docker_start_satellite "$VPN_CLIENT_IP" "$SATELLITE_AUTHKEY"

        # The new container is working - we can remove the old one
        else
            # Remove old container if any
            if docker ps -a | grep ${CONTAINER_NAME}Old 2>&1 >/dev/null; then
                echo "INFO:  Removing old container ${CONTAINER_NAME}Old"
                docker rm ${CONTAINER_NAME}Old
            fi

        fi

    # Nothing to do
    else
        echo "INFO:  $CONTAINER_NAME up to date"
        # Free some unused space
        docker_remove_unassigned_images
    fi

fi


# Show status
echo -e "\nINFO:  Showing docker container processes and logs"
docker ps -a
docker logs --tail 10 ${CONTAINER_NAME}


echo "INFO:  Finished successfully"
exit 0
