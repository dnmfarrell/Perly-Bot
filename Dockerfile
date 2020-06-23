FROM alpine:3.11

LABEL version=20200623

WORKDIR /perly-bot

COPY perly-bot.tar.gz .

RUN tar xvzf perly-bot.tar.gz && \
  apk update && apk add --no-cache \
    gcc \
    g++ \
    make \
    libressl-dev \
    zlib-dev \
    expat-dev \
    curl \
    perl \
    perl-io-socket-ssl \
    perl-dev \
    shared-mime-info \
    wget && \
  curl -L https://cpanmin.us | perl - App::cpanminus && \
    cpanm --notest --installdeps . -M https://cpan.metacpan.org && \
  apk del \
    curl \
    gcc \
    g++ \
    expat-dev \
    make \
    perl-dev \
    wget && \
  rm -rf /root/.cpanm/* /usr/local/share/man/*

ENV PERLYBOT_PROD=1 AWS_CONFIG_FILE=./credentials AWS_DEFAULT_PROFILE=perly-bot

CMD ["bin/run-perlybot-nonstop"]
