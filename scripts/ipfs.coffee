# Description:
#   adds ipfs pinning and other cool things
#
# Dependencies:
#   "<module name>": "<module version>"
#
# Configuration:
#   IPFS_LOCAL_API
#   IPFS_LOCAL_GATEWAY
#   IPFS_GLOBAL_GATEWAY (default: https://gateway.ipfs.io)
#
# Commands:
#   hubot ipfs-node - shows ipfs node urls
#   hubot ipfs-id - shows output of ipfs id
#   hubot cat <ipfs-path> - cats content at <ipfs-path> inline (pls no large things yet)
#   hubot pin <ipfs-path> - pins <ipfs-path> (recursively)
#   hubot cache <ipfs-path> - caches <ipfs-path> (recursively) at local gateway
#   hubot swarm peers - shows output of: ipfs swarm peers
#
# Notes:
#   https://github.com/ipfs/ipfs-hubot
#
# Author:
#   @jbenet

ipfsApi = require 'ipfs-api'

localApiUrl = '/ip4/127.0.0.1/tcp/5001'
localGatewayUrl = 'http://localhost:8080'
globalGatewayUrl = 'https://gateway.ipfs.io'

splitUrl = (url) ->

ipfs = ipfsApi localApiUrl

# test it just to show if it's not online on startup.
ipfs.version (err) ->
  if (err)
    console.error 'api not online yet. ' + err

# ------------------------------------------------------------
# tooling

isIpfsPath = (path) -> path.match(/^\/ip[fnl]s\//)

cleanPath = (path) ->
  unless isIpfsPath(path.substring(0, 6))
    path = '/ipfs/' + path
  return path

gatewayLink = (gwayUrl, path) -> gwayUrl + cleanPath(path)
globalGWLink = (path) -> gatewayLink globalGatewayUrl, path
localGWLink = (path) -> gatewayLink localGatewayUrl, path


linksTo = (path) -> "global: #{globalGWLink path} local: #{localGWLink path}"

prettyPath = (path) ->
  "`#{path}` (<#{globalGWLink path}|global>, <#{localGWLink path}|local>)"

contentFooter = (path, content) ->
  return """
  length: #{content.length} bytes
  global: #{globalGWLink path}
  local: #{localGWLink path}
  """

braceString = (s) ->
  unless s.substr(-1) == '\n'
    s = s + '\n'
  return '```\n' + s + '```'

prettyJSON = (o) ->
  braceString JSON.stringify o, null, 2

# hook into here to log or otherwise detect failures
fail = (res, err) ->
  res.send '' + err
  return err


# this is here as syntactic sugar for the pattern:
# ipfs.call param1 (err, r) ->
#   if (err)
#     fail res, err
#   do_thing_with r
mustSucceed = (res, cb) ->
  return (err, r) ->
    if (err)
      return fail res, err
    return cb(r)



# ------------------------------------------------------------
# pinbot implementation
module.exports = (robot) ->

  testApi = (res, cb) ->
    ipfs.version (err) ->
      if (err)
        return fail res, 'api not working. ' + err
      return cb()

  robot.respond /ipfs-node/i, (res) ->
    res.send """
      local ipfs api: #{localApiUrl}
      local ipfs gateway: #{localGatewayUrl}
      global ipfs gateway: #{globalGatewayUrl}
      """

  robot.respond /ipfs-id/i, (res) ->
    testApi res, ->
      ipfs.id mustSucceed res, (r) ->
        res.send text: "`#{r.id}`", attachments: [{
            text: prettyJSON r
            mrkdwn_in: ['text']
          }]

  robot.respond /swarm peers/i, (res) ->
    testApi res, ->
      ipfs.swarm.peers mustSucceed res, (r) ->
        prettyAddrs = prettyJSON r.map (peer) -> peer.addr.toString()
        peersCount = r.length + ' peers'
        res.send text: peersCount, attachments: [{
            text: prettyAddrs
            mrkdwn_in: ['text']
          }]

  robot.respond /cat (.*)/i, (res) ->
    path = cleanPath(res.match[1])
    testApi res, ->
      # todo: some path validation
      ipfs.cat path, mustSucceed res, (r) ->
        res.send attachments: [{
            title: path,
            title_link: globalGWLink path
            text: braceString(r.toString('utf8'))
            footer: contentFooter path, r
            mrkdwn_in: ['text', 'footer']
          }]

  robot.respond /pin (.*)/i, (res) ->
    path = res.match[1]
    testApi res, ->
      res.send "pinning #{prettyPath path}"
      # todo: implement -r=false support (right now it assumes -r=true)
      # todo: some path validation
      ipfs.refs path, {r: true}, mustSucceed res, (r) ->
        ipfs.pin.add path, {r: true}, mustSucceed res, (r) ->
          res.send "success: pinned recursively: #{prettyPath path}"

  robot.respond /cache (.*)/i, (res) ->
    path = res.match[1]
    testApi res, ->
      # todo: some path validation
      res.send "caching #{prettyPath path}"
      ipfs.refs path, {r: true}, mustSucceed res, (r) ->
        res.send "success: cached: #{prettyPath path}"
