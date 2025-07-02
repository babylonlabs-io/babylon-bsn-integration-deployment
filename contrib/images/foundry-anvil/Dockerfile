FROM debian:bullseye-slim

RUN apt-get update -y \
  && apt-get install -y curl bash ca-certificates libssl-dev libcurl4 openssl git \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

SHELL ["/bin/bash", "-c"]

RUN curl -L https://foundry.paradigm.xyz | bash && \
    $HOME/.foundry/bin/foundryup

ENV PATH="/root/.foundry/bin:${PATH}"
ENV HOME=/root

WORKDIR /foundry-anvil

COPY wrapper.sh /foundry-anvil/wrapper.sh
RUN chmod +x /foundry-anvil/wrapper.sh

EXPOSE 8545

ENTRYPOINT ["/foundry-anvil/wrapper.sh"]
CMD []
STOPSIGNAL SIGTERM
