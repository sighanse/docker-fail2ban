# syntax=docker/dockerfile:1

ARG FAIL2BAN_VERSION=1.0.2
ARG ALPINE_VERSION=3.17

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS fail2ban-src
RUN apk add --no-cache git
WORKDIR /src/fail2ban
RUN git init . && git remote add origin "https://github.com/fail2ban/fail2ban.git"
ARG FAIL2BAN_VERSION
RUN git fetch origin "${FAIL2BAN_VERSION}" && git checkout -q FETCH_HEAD

FROM alpine:${ALPINE_VERSION}
RUN --mount=from=fail2ban-src,source=/src/fail2ban,target=/tmp/fail2ban,rw \
  apk --update --no-cache add \
    bash \
    curl \
    grep \
    ipset \
    iptables \
    ip6tables \
    kmod \
    nftables \
    openssh-client-default \
    python3 \
    ssmtp \
    tzdata \
    wget \
    whois \
  && apk --update --no-cache add -t build-dependencies \
    build-base \
    py3-pip \
    py3-setuptools \
    python3-dev \
  && pip3 install --upgrade pip \
  && pip3 install dnspython3 pyinotify \
  && cd /tmp/fail2ban \
  && 2to3 -w --no-diffs bin/* fail2ban \
  && pip3 install . \
  && apk del build-dependencies \
  && rm -rf /etc/fail2ban/jail.d

COPY entrypoint.sh /entrypoint.sh

RUN adduser --uid "1005" --disabled-password --no-create-home -s /sbin/nologin fail2ban && chown -R fail2ban /etc/fail2ban /var/run/fail2ban /etc/ssmtp && chown fail2ban /etc

ENV TZ="UTC"
USER fail2ban

VOLUME [ "/data" ]

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "fail2ban-server", "-f", "-x", "-v", "start" ]

HEALTHCHECK --interval=10s --timeout=5s \
  CMD fail2ban-client ping || exit 1
