#!/bin/bash
#######################################################################################################################
# This script will run directly inside podman (or docker)
# simply call the script as if it was a regular executable
# This first part will start the container and mount this script file in the /usr/bin/container_run_script.sh file
# it will also mount the working directory to /mnt/cwd so that you 
# can copy data back to the host
#
# You can modify the following variables to customize your container
#######################################################################################################################
CONTAINER_RUNTIME=podman

CONTAINER_IMAGE=ubuntu:jammy

CONTAINER_ARTIFACT_FOLDER=$(mktemp -d /tmp/podman_selfrunning.XXXXX)

CONTAINER_ADDITIONAL_FLAGS="--net=host --rm -it -v $PWD:/mnt/cwd -v ${CONTAINER_ARTIFACT_FOLDER}:/mnt/artifacts"
#######################################################################################################################


function host_preContainer()
{
    echo "-------------------------------------------------"
    echo "Hello from the host_preContainer() - you can use this function to do some stuff on the host"
    echo "before the container starts. For example, you can check if a custom container exists, if it does not"
    echo "git clone it and perform a docker build"
    echo ""
    echo ""
    echo ""
    echo "Returning something other than 0 will cause the script the terminate before"
    echo "running the podman container"
    echo ""
#    echo "Sleeping for 5 seconds before continuing"
#    sleep 5
    return 0
}

function host_postContainer()
{
    echo "-------------------------------------------------"
    echo "Hello From the Host! The Container finished. Container exit status: $1"
    echo ""
    echo ""
    echo " Container Artifacts: ${CONTAINER_ARTIFACT_FOLDER}"
    ls ${CONTAINER_ARTIFACT_FOLDER}/*
    return 0
}


#######################################################################################################################
# Find the location of this script on the host even if has been run from
# a different location or if it was a symlink
#######################################################################################################################
FILE_LOCATION="${BASH_SOURCE[0]}"
while [ -h "$FILE_LOCATION" ]; do # resolve $FILE_LOCATION until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$FILE_LOCATION" )" >/dev/null 2>&1 && pwd )"
  FILE_LOCATION="$(readlink "$FILE_LOCATION")"
  # if $FILE_LOCATION was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $FILE_LOCATION != /* ]] && FILE_LOCATION="$DIR/$FILE_LOCATION" 
done
SOURCE_DIR="$( cd -P "$( dirname "$FILE_LOCATION" )" >/dev/null 2>&1 && pwd )"
#######################################################################################

if [[ "${SELF_RUNNING_SCRIPT_FLAG}" != "TRUE" ]]; then

    if [[ ! -f $(which $CONTAINER_RUNTIME) ]]; then
        echo "ERROR: Could not find the executable for: $CONTAINER_RUNTIME"
        exit 1
    fi

    set -e
    host_preContainer

    ARGS_=$@
    SCRIPT_MOUNT_POINT="/usr/bin/container_run_script.sh"
    # the exec command passed into the container
    CONTAINER_EXEC_COMMAND="container_run_script.sh"

    set +e
    ${CONTAINER_RUNTIME} run -e SELF_RUNNING_SCRIPT_FLAG=TRUE ${CONTAINER_ADDITIONAL_FLAGS} -v $(realpath ${FILE_LOCATION}):${SCRIPT_MOUNT_POINT}:ro ${CONTAINER_IMAGE} ${CONTAINER_EXEC_COMMAND} ${ARGS_}

    host_postContainer $?

    exit $?
fi
unset host_on_container_exit
unset SELF_RUNNING_SCRIPT_FLAG
#######################################################################################################################


##########################################################################
# Anything below here will run in the podman container
##########################################################################
echo "-------------------------------------------------"
echo "Hello from the container!"
echo "  Container Working Directory : $PWD"
echo "  Host Working Directory      : /mnt/cwd"
echo "  Host Artifacts Directory    : /mnt/artifacts"
echo "  Exec                        : $0 $@"
echo ""
echo "  If you generate any artifacts in the container you would like to keep. Copy them to /mnt/artifacts"
echo ""
echo "  Container sleeping for 5 seconds then exiting with exit status 3"
echo ""
echo "-------------------------------------------------"
touch /mnt/artifacts/hello_from_container
sleep 5

exit 3
