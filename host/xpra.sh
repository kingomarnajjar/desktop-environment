REPO_ROOT=$(dirname $(realpath $0))/..

# Export desktop environment shell configuration
export $($REPO_ROOT/docker/scripts/environment.sh)

# Kill all existing xpra services
docker ps -a | grep xpra | cut -c 1-15 | xargs docker rm -f

# Xpra configuration
DISPLAY=:14

# Traefik configuration
ACME_DOMAINS=
ACME_EMAIL=
ACME_ENABLE=
DOCKER_DOMAIN=
TRAEFIK_DEFAULT_ENTRYPOINTS=
TRAEFIK_ENTRYPOINT_HTTP=
TRAEFIK_ENTRYPOINT_HTTPS=
TRAEFIK_HOST=

# Start the xpra server
docker run \
  --detach \
  --env MODE=tcp \
  --env XPRA_HTML=yes \
  --env DISPLAY \
  --name $DESKTOP_ENVIRONMENT_CONTAINER-xpra-x11-bridge \
  --publish 10000:10000 \
  jare/x11-bridge:latest

# Start a desktop environment attached to the xpra server
docker run \
  --detach \
  --env ACME_DOMAINS
  --env ACME_EMAIL
  --env ACME_ENABLE
  --env DISPLAY
  --env DOCKER_DOMAIN
  --env TRAEFIK_DEFAULT_ENTRYPOINTS
  --env TRAEFIK_ENTRYPOINT_HTTP
  --env TRAEFIK_ENTRYPOINT_HTTPS
  --env TRAEFIK_HOST
  --name $DESKTOP_ENVIRONMENT_CONTAINER-xpra-client \
  --volumes-from $DESKTOP_ENVIRONMENT_CONTAINER-xpra-x11-bridge \
  $DESKTOP_ENVIRONMENT_REGISTRY/$DESKTOP_ENVIRONMENT_CONTAINER:$DESKTOP_ENVIRONMENT_BRANCH

# Make the X server publicly accessible using traefik
docker exec \
  --tty \
  --user $DESKTOP_ENVIRONMENT_USER \
  $DESKTOP_ENVIRONMENT_CONTAINER-xpra-client \
  traefik \
  --acme.domains=$ACME_DOMAINS \
  --acme.email="$ACME_EMAIL" \
  --acme.entrypoint=https \
  --acme.httpchallenge \
  --acme.httpchallenge.entrypoint=http \
  --acme.storage=/etc/traefik/acme.json \
  --acme=$ACME_ENABLE \
  --defaultentrypoints=$TRAEFIK_DEFAULT_ENTRYPOINTS \
  --docker \
  --docker.domain="$DOCKER_DOMAIN" \
  --docker.endpoint="unix:///var/run/docker.sock" \
  --docker.exposedbydefault=false \
  --docker.watch=true \
  --logLevel=info \
  --web \
  $TRAEFIK_ENTRYPOINT_HTTP $TRAEFIK_ENTRYPOINT_HTTPS
