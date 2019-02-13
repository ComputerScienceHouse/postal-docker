FROM ruby:2.6-alpine
MAINTAINER Computer Science House <rtp@csh.rit.edu>

RUN wget https://github.com/wrouesnel/p2cli/releases/download/r5/p2 -O /usr/local/bin/p2 \
        && chmod +x /usr/local/bin/p2

RUN apk --no-cache add \
        nodejs \
        mariadb-client \
        git \
        bash \
        libcap \
        build-base \
        mariadb-dev \
        tzdata \
        mariadb-connector-c \
        openssl && \
    git clone https://github.com/atech/postal.git /opt/postal && \
    gem install bundler && \
    gem install procodile && \
    gem install tzinfo-data && \
    addgroup -S postal && \
    adduser -S -G postal -h /opt/postal -s /bin/bash postal && \
    chown -R postal:postal /opt/postal/ && \
    chmod og+rwx /opt/postal /opt/postal/config && \
    chmod -R og+rwx /opt/postal/log && \
    /opt/postal/bin/postal bundle /opt/postal/vendor/bundle && \
    apk del git mariadb-dev && \
    rm -rf /var/cache/apk/*

# Adjust permissions
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/ruby

# Precompile assets
RUN cd /opt/postal && \
    cp config/postal.example.yml config/postal.yml && \
    touch config/signing.key config/lets_encrypt.pem && \
    RAILS_GROUPS=assets bundle exec rake assets:precompile && \
    rm -f log/* config/postal.yml config/signing.key config/lets_encrypt.pem && \
    touch public/assets/.prebuilt

# Add required files
ADD docker-entrypoint.sh /docker-entrypoint.sh
ADD postal.yml.j2 /tmp/postal.yml.j2

EXPOSE 25
EXPOSE 80
EXPOSE 443
EXPOSE 5000

ENTRYPOINT ["/bin/bash", "-c", "/docker-entrypoint.sh ${*}", "--"]
