# Self Running Containerized Scripts

This is a single shell script, which when run would be executed inside a container (podman or docker)

The main reason I created something like this was for creating isolated builds of third party software without having to pollute my host with dev packages.

## How It Works

The concept is very simple and probably self explainable by looking at the template code.

When run, the script will mount itself inside a container, and then execute itself inside the container.



