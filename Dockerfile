FROM debian:buster-slim

RUN set -ex; \
	if ! command -v gpg > /dev/null; then \
		apt-get update; \
		apt-get install -y --no-install-recommends \
			gnupg \
			dirmngr \
		; \
		rm -rf /var/lib/apt/lists/*; \
	fi

ARG DEBIAN_FRONTEND=noninteractive


RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y locales
RUN apt-get -y update
RUN apt-get install -y wget gnupg2 || apt-get install -y gnupg
RUN apt-get install -y curl

RUN sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG ru_RU.UTF-8
ENV LANGUAGE ru_RU:ru
ENV LC_ALL ru_RU.UTF-8



RUN apt-get install -y python3-pip

RUN pip3 install pyxdameraulevenshtein
RUN pip3 install pystemmer

ENV GOSU_VERSION 1.12
RUN set -x \
	&& apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver keyserver.ubuntu.com --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# install "nss_wrapper" in case we need to fake "/etc/passwd" and "/etc/group" (especially for OpenShift)
# https://github.com/docker-library/postgres/issues/359
# https://cwrap.org/nss_wrapper.html
		libnss-wrapper \
# install "xz-utils" for .sql.xz docker-entrypoint-initdb.d files
		xz-utils \
	; \
	rm -rf /var/lib/apt/lists/*

RUN curl -o apt-repo-add.sh http://repo.postgrespro.ru/pgpro-12/keys/apt-repo-add.sh
RUN sh apt-repo-add.sh

#RUN apt-get install -y postgrespro-std-12
RUN apt-get install -y postgrespro-std-12-server
RUN apt-get install -y postgrespro-std-12-client
RUN apt-get install -y postgrespro-std-12-dev
RUN apt-get install -y postgrespro-std-12-libs
RUN apt-get install -y postgrespro-std-12-jit

RUN apt-get install -y postgrespro-std-12-contrib
RUN apt-get install -y postgrespro-std-12-pltcl
RUN apt-get install -y mamonsu
RUN apt-get install -y pgbouncer
RUN apt-get install -y postgrespro-std-12-plpython3

RUN /opt/pgpro/std-12/bin/pg-wrapper links update
RUN /opt/pgpro/std-12/bin/pg-setup find-free-port

RUN mkdir /docker-entrypoint-initdb.d

ENV PGDATA /var/lib/pspro

RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/pspro

COPY docker-entrypoint.sh /usr/local/bin/
COPY conf/postgresql.custom.conf /custom.conf
RUN ln -s usr/local/bin/docker-entrypoint.sh / # backwards compat

ENTRYPOINT ["docker-entrypoint.sh"]

STOPSIGNAL SIGINT
EXPOSE 5432
CMD ["postgres"]
