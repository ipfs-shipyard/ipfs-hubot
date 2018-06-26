FROM node:10

MAINTAINER Hector Sanjuan <hector@protocol.ai>

RUN npm install -g yo generator-hubot

# Create hubot user
RUN adduser --home /hubot --shell /bin/bash --system hubot
USER  hubot
WORKDIR /hubot

# Install hubot
RUN yo hubot --name="ipfsbot" --description="IPFS Pinbot" --defaults --adapter=slack
RUN npm install --save ipfs-api@github:ipfs/js-ipfs-api#f77bbf59392bd4ea5ed04db46882ed265fcdd231
RUN npm install --save coffeescript@^1.12.6
RUN npm install --save underscore
RUN npm uninstall --save hubot-heroku-keepalive
RUN sed -i '/heroku/d' /hubot/external-scripts.json
ADD scripts/ipfs.coffee /hubot/scripts/ipfs.coffee

# These variables control the behaviour. Overwrite with --env
ENV IPFS_LOCAL_API /ip4/127.0.0.1/tcp/5001
ENV IPFS_LOCAL_GATEWAY http://127.0.0.1:8080
ENV HUBOT_SLACK_TOKEN set-your-own

# And go
ENTRYPOINT ["/bin/sh", "-c", "bin/hubot --adapter slack"]