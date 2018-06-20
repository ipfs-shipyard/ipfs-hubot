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
#   hubot ipfs help - shows all ipfs commands (this list shows only a few)
#   hubot pin <ipfs-path> - pins <ipfs-path> (recursively)
#   hubot ipfs cat <ipfs-path> - cats content at <ipfs-path> inline (pls no large things yet)
#
# Notes:
#   https://github.com/ipfs/ipfs-hubot
#
# Author:
#   @jbenet

allCommandsHelp = """
Here are all the commands I understand. They are very similar to the go-ipfs
command line tool. Only the read-only commands are implemented as of now.
Maybe if we figure out an authentication model we can see about more.

NODE INFO
  ipfs api-info                 show the api urls to the ipfs node i'm using
  ipfs id                       show status info about the ipfs node
  ipfs version                  show the version of the ipfs node
  ipfs help                     show this help text

BASIC COMMANDS
  ipfs cat <ipfs-path>          treat <ipfs-path> as a file and output contents
  ipfs ls <ipfs-path>           list all ipfs links of object at <ipfs-path>
  ipfs refs <ipfs-path>         list all refs (recursively!) under <ipfs-path>
  ipfs cache <ipfs-path>        temporarily cache all the content at <ipfs-path>

DATA STRUCTURE COMMANDS
  ipfs block get <cid>          output the raw ipfs block contents of <key>
  ipfs block stat <cid>         check statistics of block at <cid>
# ipfs block put <data>         store raw input as ipfs block
# ipfs block rm  <cid>          remove ipfs block at <cid>

  ipfs dag get <cid>            output the ipld dag node at <cid>
# ipfs dag put <data>           add an ipld dag node to ipfs, output its <cid>
# ipfs dag resolve <path>       resolve <path> to an ipld dag node

# ipfs object ...

FILES COMMANDS
# ipfs files cp <src> <dst>     copy files into mfs.
# ipfs files flush [<path>]     flush a given path's data to disk.
  ipfs files ls [<path>]        list directories in the local mutable namespace.
# ipfs files mkdir <path>       make directories.
# ipfs files mv <src> <dst>     move files.
  ipfs files read <path>        read a file in a given mfs.
# ipfs files rm <path>...       remove a file.
  ipfs files stat <path>        display file status.
# ipfs files write <path> <d>   write <d> to a mutable file at a given <path>.

NAME COMMANDS
# ipfs name publish <path>      publish <ipfs-path> to a name
  ipfs name resolve <name>      resolve <name> and output value
  ipfs dns <domain>             resolve dnslink at <domain>

REPO AND PINNING COMMANDS
# ipfs repo stat                get stats about ipfs node repo
  ipfs repo version             get the repo version
# ipfs repo fsck                remove repo lock files
# ipfs repo gc                  garbage collect the repo
# ipfs repo verify              verify all blocks are correct

  pin                           alias for: ipfs pin add -r
  ipfs pin add -r <ipfs-path>   pin <ipfs-path> recursively to local storage
  ipfs pin ls <ipfs-path>       list paths pinned to local storage
# ipfs pin rm <ipfs-path>       remove pins for <ipfs-path>
# ipfs pin update <p1> <p2>     update recursive pin from path <p1> to <p2>
# ipfs pin verify               verify that recursive pins are complete

NETWORK COMMANDS
  ipfs ping <peerid>            ping <peerid> 5 times, and output latency

  ipfs swarm peers              show all peers this node is connected to
  ipfs swarm addrs              show all addresses the node knows about
# ipfs swarm connect <addr>     connect to the peer at <addr>
# ipfs swarm disconnect <addr>  disconnect from the peer at <addr>
# ipfs swarm filters            manipulate address filters

  ipfs bootstrap list           shows the list of bootstrap addresses
# ipfs bootstrap add <addr>     adds a peer's address to the bootstrap list
# ipfs bootstrap rm <addr>      removes a peer's address from the bootstrap list

# ipfs dht get <key>            output the value stored at <key>
# ipfs dht put <key> <value>    set <value> at <key>
  ipfs dht findpeer <peerid>    find addresses for peer with id <peer-id>
# ipfs dht query <peerid>       find the closest peers to <peerid>
  ipfs dht findprovs <cid>      find providers for content at <cid>
# ipfs dht provide <cid>        set a record that this node is providing <cid>

OTHER COMMANDS
  ipfs diag cmds                show usage stats of commands at this node

  ipfs stats bitswap            show bitswap stats and bitswap partners
  ipfs stats bw                 show bandwidth usage
# ipfs stats repo               show repo disk usage and other stats
"""

allCommandsHelp = allCommandsHelp.replace(/^#.*\n?/gm, '')
console.log allCommandsHelp


# ------------------------------------------------------------
# setup

ipfsApi = require 'ipfs-api'
_ = require 'underscore'

localApiUrl = '/ip4/127.0.0.1/tcp/5001'
localGatewayUrl = 'http://localhost:8080'
globalGatewayUrl = 'https://gateway.ipfs.io'

# grab values from env vars
localApiUrl = process.env.IPFS_LOCAL_API if process.env.IPFS_LOCAL_API
localGatewayUrl = process.env.IPFS_GLOBAL_GATEWAY if process.env.IPFS_GLOBAL_GATEWAY
globalGatewayUrl = process.env.IPFS_LOCAL_GATEWAY if process.env.IPFS_LOCAL_GATEWAY

ipfs = ipfsApi localApiUrl

# test it just to show if it's not online on startup.
ipfs.version (err) ->
  if (err)
    console.error 'api not online yet. ' + err

# ------------------------------------------------------------
# content formatting

isIpfsPath = (path) -> path.match(/\/ip[fnl]s\//)

cleanPath = (path) ->
  path = path.trim()
  unless isIpfsPath(path.substring(0, 6))
    path = '/ipfs/' + path
  return path

gatewayLink = (gwayUrl, path) -> gwayUrl + cleanPath(path)
globalGWLink = (path) -> gatewayLink globalGatewayUrl, path
localGWLink = (path) -> gatewayLink localGatewayUrl, path

linksTo = (path) -> "global: #{globalGWLink path} local: #{localGWLink path}"

prettyPath = (path) ->
  "`#{path}` (<#{globalGWLink path}|global>, <#{localGWLink path}|local>)"

contentFooter = (cmd, path, content) ->
  return """
  cmd: #{cmd}
  length: #{content.length} bytes
  global: #{globalGWLink path}
  local: #{localGWLink path}
  """

isString = (s) -> typeof s == 'string' || s instanceof String

braceString = (s) ->
  unless s.substr(-1) == '\n'
    s = s + '\n'
  return '```\n' + s + '```'

prettyJSON = (o) ->
  braceString JSON.stringify o, null, 2

prettify = (o) ->
  if Buffer.isBuffer(o)
    o = o.toString 'utf8'
  if isString o
    o = braceString o
  else
    o = prettyJSON o
  return o

contentMsg = (cmd, path, content) ->
  return attachments: [{
    title: path,
    title_link: globalGWLink path
    text: prettify content
    color: 'good'
    footer: contentFooter cmd, path, content
    mrkdwn_in: ['text', 'footer']
  }]

cmdOutputMsg = (cmd, text, out) ->
  return text: text, attachments: [{
    text: prettify out
    pretext: "`#{cmd}`"
    mrkdwn_in: ['text', 'pretext']
  }]

cmdErrMsg = (cmd, err) ->
  return attachments: [{
    pretext: "`#{cmd}`"
    text: prettify '' + err
    color: 'danger'
    mrkdwn_in: ['text', 'pretext']
  }]

# ------------------------------------------------------------
# handlers and command running

# hook into here to log or otherwise detect failures
reportFail = (res, err) ->
  console.log(res.message.rawText, err)
  res.send cmdErrMsg res.message.rawText, err
  return err

# this is here as syntactic sugar for the pattern:
# ipfs.call param1 (err, r) ->
#   if (err)
#     fail res, err
#   do_thing_with r
mustSucceed = (res, cb) ->
  return (err, r) ->
    if (err)
      return reportFail res, err
    return cb(r)

getParams = (params, res) ->
  if params and typeof(params) == 'function'
    return params(res) # caller provided fn
  else if params
    return params # caller provided values
  else if res.match.length > 1
    return res.match.slice(1) # handler parameters
  else
    return [] # no params

testApi = (res, cb) ->
  console.log("running command: " + res.message.rawText)
  ipfs.version (err) ->
    if (err)
      return reportFail res, 'api not working. ' + err
    return cb()

MaxMessageLength = 1000

# these are helper functions that construct similar commands.
# options = {
#   params: [p1, p2, ...] or (res) -> [p1, p2, ...]
#   auxtext: "text" or (cmdres, res) -> "text"
#   output: (cmdres) -> out
# }
runCmd = (cmdfn, opt) -> (res) ->
  opt = {} unless opt
  params = getParams(opt.params, res)
  testApi res, ->
    cb = mustSucceed res, (r) ->
      text = opt.auxtext
      text = text(r, res) if typeof(text) == 'function'
      r = opt.output(r) if typeof(opt.output) == 'function'
      cmdline = res.message.rawText
      res.send cmdOutputMsg cmdline, text, r
    # have to do it this way to get the params to work
    params.push cb
    cmdfn.apply(cmdfn, params)

runCmdPath = (cmdfn, opt) ->
  opt = {} unless opt
  opt.params = (res) -> [cleanPath(res.match[1])]
  return runCmd cmdfn, opt

runCmdContent = (cmdfn) -> (res) ->
  path = cleanPath(res.match[1])
  # todo: some path validation
  testApi res, ->
    cmdfn path, mustSucceed res, (r) ->
      res.send contentMsg res.message.rawText, path, r


# ------------------------------------------------------------
# pinbot implementation
module.exports = (robot) ->

  # NODE INFO
  robot.respond /ipfs api-info/i, (res) ->
    res.send """
      local ipfs api: #{localApiUrl}
      local ipfs gateway: #{localGatewayUrl}
      global ipfs gateway: #{globalGatewayUrl}
      """

  robot.respond /ipfs id/i, runCmd ipfs.id, auxtext: (r) -> "`#{r.id}`"
  robot.respond /ipfs version/i, runCmd ipfs.version
  robot.respond /ipfs (--help|-h|help)/i, (res) ->
    res.send braceString allCommandsHelp

  # BASIC COMMANDS
  robot.respond /ipfs cat (\S+)/i, runCmdContent ipfs.cat
  robot.respond /ipfs ls (\S+)/i, runCmdPath ipfs.ls
  robot.respond /ipfs refs (\S+)/i, runCmdPath (path, cb) ->
    ipfs.refs path, {r: true}, cb

  # ipfs cache is similar to ipfs refs without the output
  robot.respond /ipfs cache (\S+)/i, (res) ->
    path = res.match[1]
    # todo: some path validation
    testApi res, ->
      ipfs.refs path, {r: true}, mustSucceed res, (r) ->
        res.send "success: cached: #{prettyPath path}"

  # DATA STRUCTURE COMMANDS
  robot.respond /ipfs block get (\S+)/i, runCmdPath ipfs.block.get
  robot.respond /ipfs block stat (\S+)/i, runCmdPath ipfs.block.stat
  # robot.respond /ipfs dag resolve (\S+)/i, runCmdPath ipfs.dag.resolve
  robot.respond /ipfs dag get (\S+)/i, runCmdPath ipfs.dag.get

  # FILE COMMANDS
  robot.respond /ipfs files read (\S+)/i, runCmdContent ipfs.files.read
  robot.respond /ipfs files stat (\S+)/i, runCmd ipfs.files.stat
  robot.respond /ipfs files ls (\S)?/i, runCmd ipfs.files.ls,
    output: (o) -> _.pluck(o, 'name').join('\n')

  # NAME COMMANDS
  robot.respond /ipfs name resolve (\S+)/i, runCmd ipfs.name.resolve
  robot.respond /ipfs dns (\S+)/i, runCmd ipfs.dns.resolve

  # REPO AND PINNING COMMANDS
  robot.respond /ipfs repo version/i, runCmd ipfs.repo.version

  # ipfs pin
  robot.respond /(ipfs pin add -r|pin) (\S+)/i, (res) ->
    path = cleanPath(res.match[1])
    # todo: some path validation
    testApi res, ->
      res.send "pinning #{prettyPath path} (warning: experimental)"
      # todo: implement -r=false support (right now it assumes -r=true)
      ipfs.refs path, {r: true}, mustSucceed res, (r) ->
        ipfs.pin.add path, {r: true}, mustSucceed res, (r) ->
          res.send """
            success: pinned recursively: #{prettyPath path}
            (warning: this pinbot is experimental. do not rely on me yet.)
            """

  robot.respond /ipfs pin ls (\S+)/i, runCmdPath ipfs.pin.ls,
    output: (o) -> o.map((e) -> "#{e.hash} #{e.type}").join('\n')

  # NETWORK COMMANDS
  robot.respond /ipfs ping (\S+)/i, runCmd ipfs.ping
  robot.respond /ipfs ping (\S+)/i, runCmd ipfs.swarm

  robot.respond /ipfs swarm peers/i, runCmd ipfs.swarm.peers,
    auxtext: (r) -> r.length + ' peers'
    output: (r) -> r.map((peer) -> peer.addr.toString()).join('\n')

  robot.respond /ipfs swarm addrs/i, runCmd ipfs.swarm.addrs,
    output: (r) ->
      out = ''
      r.map (peer) ->
        out += "#{peer.id.toB58String()}:\n"
        peer.multiaddrs.forEach (addr) ->
          out += "    #{addr.toString()}\n"
      return out

  robot.respond /ipfs bootstrap list/i, runCmd ipfs.bootstrap.list,
    auxtext: (r) -> r.Peers.length + ' bootstrap peers'
    output: (r) -> r.Peers.join('\n')

  # robot.respond /ipfs dht get (\S+)/i, runCmd ipfs.dht.get
  robot.respond /ipfs dht findpeer (\S+)/i, runCmd ipfs.dht.findpeer,
    output: (r) -> r[0]["Responses"].Addrs.join('\n')
  # robot.respond /ipfs dht query (\S+)/i, runCmd ipfs.dht.query
  robot.respond /ipfs dht findprovs (\S+)/i, runCmd ipfs.dht.findprovs,
    output: (r) -> _.pluck (_.flatten _.pluck r, "Responses"), "ID"

  # OTHER COMMANDS
  robot.respond /ipfs diag cmds/i, runCmd ipfs.diag.cmds

  robot.respond /ipfs stats bitswap/i, runCmd ipfs.stats.bitswap
  robot.respond /ipfs stats bw/i, runCmd ipfs.stats.bw
