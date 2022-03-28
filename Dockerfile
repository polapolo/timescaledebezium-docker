ARG PG_MAJOR=14

FROM debezium/postgres:$PG_MAJOR as debezium_postgres

# extends timescaledb image
FROM timescale/timescaledb:latest-pg$PG_MAJOR

ENV PLUGIN_VERSION=v1.9.0.CR1
ENV PROTOC_VERSION=1.3

ENV WAL2JSON_COMMIT_ID=wal2json_2_3

# install debezium decoder into timescaledb
# https://github.com/debezium/docker-images/blob/main/postgres/14/Dockerfile

# build wal2json for debezium
RUN apk add --no-cache protobuf-c-dev
RUN apk add --no-cache --virtual .debezium-build-deps gcc clang llvm git make musl-dev pkgconf \
    && git clone https://github.com/debezium/postgres-decoderbufs -b $PLUGIN_VERSION --single-branch \
    && (cd /postgres-decoderbufs && make && make install) \
    && rm -rf postgres-decoderbufs \
    && git clone https://github.com/eulerto/wal2json -b master --single-branch \
    && (cd /wal2json && git checkout $WAL2JSON_COMMIT_ID && make && make install) \
    && rm -rf wal2json \
    && apk del .debezium-build-deps

COPY --from=debezium_postgres /usr/lib/postgresql/$PG_MAJOR/lib/decoderbufs.so /usr/lib/postgresql/$PG_MAJOR/lib/wal2json.so /usr/lib/postgresql/$PG_MAJOR/lib/
COPY --from=debezium_postgres /usr/share/postgresql/$PG_MAJOR/extension/decoderbufs.control /usr/share/postgresql/$PG_MAJOR/extension/
# Copy the custom configuration which will be passed down to the server (using a .sample file is the preferred way of doing it by
# the base Docker image)
COPY postgresql.conf.sample /usr/share/postgresql/postgresql.conf.sample

# Copy the script which will initialize the replication permissions
COPY /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d