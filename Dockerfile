FROM ghcr.io/foundry-rs/foundry

# workdir
RUN mkdir -p /examples
WORKDIR /examples

# deps
RUN apk add curl bash

COPY . ./

ENTRYPOINT ["/examples/entrypoint.sh"]
CMD []
