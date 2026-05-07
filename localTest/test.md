# How to build and test locally

## Go unit tests (no wkhtmltopdf needed)

```sh
docker build -f localTest/Dockerfile --target test .
docker build -f localTest/Dockerfile --target race .
```

## Integration test (wkhtmltopdf + server)

```sh
docker build -f localTest/Dockerfile --target integration .
```

## Runtime smoke test (docker run)

```sh
bash localTest/runtime_smoke_test.sh
```

## Server

```sh
docker build -f localTest/Dockerfile -t kwkhtmltopdf:0.12.6.3 .
```

## Client

Using "act" you can run the github action "test" locally

Note: requires docker and [act](https://github.com/nektos/act)

```sh
DOCKER_GROUP=$(getent group docker | cut -d ":" -f 3)
act -W .github/workflows/test.yml -j test -P ubuntu-22.04=ghcr.io/catthehacker/ubuntu:full-22.04 --container-options "--privileged --group-add $DOCKER_GROUP" --container-daemon-socket unix:///var/run/docker.sock --container-architecture linux/amd64
```
