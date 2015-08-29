ipfsApi = require 'ipfs-api'
ipfs = ipfsApi 'localhost', '5001'

gatewayUrl = "https://gateway.ipfs.io"

gatewayPath = (path) ->
  unless path.substring(0, 6) == '/ipfs/'
    path = "/ipfs/" + path
  return gatewayUrl + path

module.exports = (robot) ->

  robot.respond /pin (.*)/i, (res) ->
    path = res.match[1]
    res.send "pinning " + path
    ipfs.refs path, {r: true}, (err, r) ->
      if (err)
        return res.send err
      ipfs.pin.add path, {r: true}, (err, r) ->
        if (err)
          return res.send err
        res.send "pinned successfully -- " + gatewayPath path

  robot.respond /cache (.*)/i, (res) ->
    path = res.match[1]
    res.send "caching " + path
    ipfs.refs path, {r: true}, (err, r) ->
      if (err)
        return res.send err
      res.send "cached successfully -- " + gatewayPath path
