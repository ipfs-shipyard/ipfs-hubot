#!/bin/sh
HUBOT_SLACK_TOKEN=$(cat .slack-token-x) ./bin/hubot --adapter slack
