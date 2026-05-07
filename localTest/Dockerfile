# syntax=docker/dockerfile:1

# Dockerfile intended for local compilation and unit tests.
# Usage examples:
#   docker build -f localTest/Dockerfile --target test .
#   docker build -f localTest/Dockerfile --target race .
#   docker build -f localTest/Dockerfile --target integration .
#   docker build -f localTest/Dockerfile --target build -o out .
#   docker build -f localTest/Dockerfile --target runtime -t kwkhtmltopdf:dev .

FROM golang:1.18-bullseye AS base
WORKDIR /src

# Copy go.mod first for better layer caching.
COPY go.mod ./
RUN go mod download

# Now copy the rest of the repository.
COPY . .

FROM base AS test
RUN go test ./...

FROM base AS race
# The race detector requires cgo; Debian-based golang images support it.
RUN go test -race ./...

FROM base AS build
RUN go build -trimpath -ldflags "-s -w" -o /kwkhtmltopdf_server ./server

# # Optional export-only stage.
FROM scratch AS artifacts
COPY --from=build /kwkhtmltopdf_server /kwkhtmltopdf_server

FROM --platform=linux/amd64 docker.io/ubuntu:22.04 AS runtime_base
WORKDIR /work

RUN set -x \
  && apt update \
  && apt -y install --no-install-recommends \
    wget \
    curl \
    ca-certificates \
    fonts-liberation2 \
    fontconfig \
    libjpeg-turbo8 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    xfonts-75dpi \
    xfonts-base \
    fonts-lato \
  && wget -q -O /tmp/wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb \
  && echo "800eb1c699d07238fee77bf9df1556964f00ffcf /tmp/wkhtmltox.deb" | sha1sum -c - \
  && dpkg -i /tmp/wkhtmltox.deb \
  && apt -f install \
  && apt -y purge wget --autoremove \
  && apt -y clean \
  && rm -rf /var/lib/apt/lists/* \
  && rm /tmp/wkhtmltox.deb

COPY --from=build /kwkhtmltopdf_server /usr/local/bin/kwkhtmltopdf_server

FROM runtime_base AS integration

COPY --from=base /src/tests/data /tests/data
COPY --from=base /src/localTest/smoke_common.sh /usr/local/bin/smoke_common.sh
COPY --from=base /src/localTest/integration_test.sh /usr/local/bin/integration_test.sh

RUN chmod +x /usr/local/bin/integration_test.sh \
  && /usr/local/bin/integration_test.sh

FROM runtime_base AS runtime
WORKDIR /work
RUN set -x \
  && apt update \
  && apt -y install --no-install-recommends \
    tini \
  && apt -y clean \
  && rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos '' --uid 1000 kwkhtmltopdf
USER 1000
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

EXPOSE 8080
CMD ["/usr/bin/tini", "--", "/usr/local/bin/kwkhtmltopdf_server"]
