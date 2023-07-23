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

CONTAINER_ADDITIONAL_FLAGS="--net=host --rm -it -v $PWD:/mnt/cwd"
#######################################################################################################################


function host_preContainer()
{
    echo "Hello from the host_preContainer() - you can use this function to do some stuff on the host"
    echo "before the container starts. For example, you can check if a custom container exists, if it does not"
    echo "git clone it and perform a docker build"
    echo ""
    echo ""
    echo ""
    # Returning something other than 0 will cause the script the terminate before
    # running the podman container
    return 0
}

function host_postContainer()
{
    echo "Hello From the Host! The Container finished. Container exit status: $1"
    cd /tmp
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
apt-get update
apt-get install -y pkg-config git curl wget python3 xz-utils ninja-build nano

git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=/depot_tools:$PATH

cd /


# Clone the repo as "dawn"
git clone https://dawn.googlesource.com/dawn dawn && cd dawn

# Bootstrap the gclient configuration
cp scripts/standalone.gclient .gclient


# gclient sync was causing problems with the tar command
# because we are running in a container.
# the TAR_OPTIONS command seems to fix this
# https://stackoverflow.com/questions/75995085/issue-with-tar-during-webrtc-fetch-inside-docker-ubuntu
export TAR_OPTIONS=--no-same-owner

# Fetch external dependencies and toolchains with gclient
gclient sync

# calling gn args out/Release will attempt to run
# vi to force you to edit the config file
# Since we only need to make modifications if we want to build
# in debug mode, we are going to bypass this by creating a
# passthrough script for vi
echo '#!/bin/bash' > /usr/bin/vi
chmod +x /usr/bin/vi

gn args out/Release

# delete the passthrough script since we don't it anymore
rm /usr/bin/vi

ninja -C out/Release

mkdir -p install/include
cp -r include/* install/include
cp -r out/* install
mv install /mnt/cwd/webgpu_dawn_$(date +%s)

bash

