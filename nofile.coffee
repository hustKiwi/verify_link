kit = require 'nokit'
moment = require 'moment'
cfg = require './cfg'

kit.require 'jhash'
kit.require 'colors'

{ _, jhash } = kit

logs = {}

songinfo_url = (sid) ->
    "http://fm.baidu.com/data/music/songlink?songIds=#{sid}&type=m4a,mp3"

curl = (url) ->
    kit.request({
        url: url
        headers:
            'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.74 Safari/537.36'
            range: 'bytes=100-200'
    })

parse_songinfo = (r) ->
    info = {}
    r = JSON.parse(r)
    if r.errorCode is 22000
        song = r.data.songList[0]
        info.id = song.songId
        info.link = song.songLink
        info.name = song.songName
    info

log = (msg, type = 'log') ->
    kit.exec """
        echo #{moment().format('MMMM Do YYYY, h:mm:ss a') + ': ' + msg} >> #{type}.txt
    """
    kit[type](msg[if type is 'log' then 'green' else 'red'])

sids = [123858308,7905056,108236178,1010926,31336224,623892,91010155,85079712,8059246,122102630,18597372,124134195,653166,5961739,609984,120378087,71278366,5889617,84974937,323025,14950800,5682044,1090700,1436892,117108786,736491,18900073,1481912,10509856,1356467,31237882,1559029,715402,2342869,440091,120108236,124273488,276802,8310835,121078799,701632,2058049,1942429,17451680,1654771,120872314,296004,365404,59473842,116951598,108887719]

verify_song = (sid) ->
    get_song = kit.flow songinfo_url, curl, parse_songinfo

    kit.sleep(cfg.sleep).then ->
        get_song(sid)
    .then (song) ->
        old_hash = logs[sid]
        curl(song.link).then (buf) ->
            new_hash = jhash.hash(buf)

            if not old_hash and buf
                logs[sid] = new_hash
                return kit.outputFile('hash.txt', JSON.stringify(logs))

            if _.isEqual(new_hash, old_hash)
                log "#{sid}, #{new_hash}, #{old_hash}, #{JSON.stringify(song)}", 'err'
    .catch (err) ->
        log "#{sid}, #{JSON.stringify(err)}", 'err'

module.exports = (task, option) ->
    task 'default', ->
        i = 0
        l = sids.length
        args = []

        while i++ < cfg.total
            sid = sids[i % l]
            args.push [i, sid]

        kit.async cfg.limit, ->
            arg = args.shift()
            if arg
                [i, sid] = arg
                log "i: #{i}, sid: #{sid}"
                verify_song(sid)
            else
                kit.async.end
        .then ->
            log 'All Done!'

    task 'clean', ->
        kit.remove '*.txt'
