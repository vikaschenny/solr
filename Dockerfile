FROM vikaschenny/spm-client:bv1.0

MAINTAINER  birru "chennybirru@gmail.com"

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

RUN apt-get update && apt-get install sudo -y && \
    echo "deb http://pub-repo.sematext.com/ubuntu sematext main" | sudo tee /etc/apt/sources.list.d/sematext.list > /dev/null && \
    wget -O - https://pub-repo.sematext.com/ubuntu/sematext.gpg.key | sudo apt-key add - && \
    sudo apt-get update  &&  sudo apt-get install spm-client -y && \
    apt-get -y install lsof procps wget  && \
    rm -rf /var/lib/apt/lists/*

ENV SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    SOLR_VERSION="7.3.0" \
    SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/7.3.0/solr-7.3.0.tgz" \
    SOLR_SHA256="4b9b9f5dfd4ea4b0fdf69bda9528de47903aaa9bd9c5cb405ce0ae09a8d12fe9" \
    SOLR_KEYS="C5DCD3AAB897097D7815BD6B069E9741F3D97FD6" \
    PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

RUN groupadd -r --gid $SOLR_GID $SOLR_GROUP && \
    useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER

RUN set -e; for key in $SOLR_KEYS; do \
    found=''; \
    for server in \
      ha.pool.sks-keyservers.net \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do \
      echo "  trying $server for $key"; \
      gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
  done; \
  exit 0

RUN mkdir -p /opt/solr && \
  echo "downloading $SOLR_URL" && \
  wget -nv $SOLR_URL -O /opt/solr.tgz && \
  echo "downloading $SOLR_URL.asc" && \
  wget -nv $SOLR_URL.asc -O /opt/solr.tgz.asc && \
  echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
  (>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc) && \
  gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz && \
  tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1 && \
  rm /opt/solr.tgz* && \
  rm -Rf /opt/solr/docs/ && \
  mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores /opt/solr/server/logs /docker-entrypoint-initdb.d /opt/docker-solr && \
  sed -i -e 's/"\$(whoami)" == "root"/$(id -u) == 0/' /opt/solr/bin/solr && \
  sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr && \
  sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh && \
  chown -R $SOLR_USER:$SOLR_GROUP /opt/solr

COPY scripts /opt/docker-solr/scripts
RUN chown -R $SOLR_USER:$SOLR_GROUP /opt/docker-solr

EXPOSE 8983
WORKDIR /opt/solr
RUN echo "solr ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/solr
RUN sudo bash /opt/spm/bin/spm-client-setup-conf.sh $CHAGE YOU SPM MONITOR TOCKERN solr javaagent
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
