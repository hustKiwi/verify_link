url = require 'url'
kit = require 'nokit'
moment = require 'moment'
cfg = require './cfg'

kit.require 'jhash'
kit.require 'colors'

{ _, jhash, Promise } = kit

logs = {}

songinfo_url = (sid) ->
    "http://fm.baidu.com/data/music/songlink?songIds=#{sid}&type=m4a,mp3"

get_ext = (link) ->
    (url.parse link).pathname.split('.').slice(-1)[0]

curl = (url) ->
    kit.request({
        url: url
        headers:
            'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.74 Safari/537.36'
            #range: 'bytes=100-200'
    })

parse_songinfo = (r) ->
    new Promise (resolve, reject) ->
        info = {}

        try
            r = JSON.parse(r)
        catch err
            reject(err)

        if r.errorCode is 22000
            song = r.data.songList[0]
            info.id = song.songId
            info.name = song.songName
        else
            reject(r)

        if cfg.xcode
            info.link = song.songLink
        else
            link = url.parse song.songLink
            info.link = "#{link.protocol}//#{link.host}#{link.pathname}"

        resolve(info)

log = (msg, type = 'log') ->
    kit.exec """
        echo '#{moment().format('MMMM Do YYYY, h:mm:ss a') + ': ' + msg}' >> #{type}.txt
    """
    kit[type](msg[if type is 'log' then 'green' else 'red'])

sids = [1250398, 56763106, 120152481]
#[123858308,7905056,108236178,1010926,31336224,623892,91010155,85079712,8059246,122102630,18597372,124134195,653166,5961739,609984,120378087,71278366,5889617,84974937,323025,14950800,5682044,1090700,1436892,117108786,736491,18900073,1481912,10509856,1356467,31237882,1559029,715402,2342869,440091,120108236,124273488,276802,8310835,121078799,701632,2058049,1942429,17451680,1654771,120872314,296004,365404,59473842,116951598,108887719]

get_song = (sid) ->
    curl(songinfo_url sid).then (info) ->
        parse_songinfo(info)

verify_song = (sid) ->
    kit.sleep(cfg.sleep).then ->
        get_song(sid)
    .then (song) ->
        old_hash = logs[sid]
        curl(song.link).then (buf) ->
            new_hash = jhash.hash(buf)

            if not old_hash and buf
                logs[sid] = new_hash
                return kit.outputFile('hash.txt', JSON.stringify(logs))

            if not _.isEqual(new_hash, old_hash)
                log "#{sid}, #{new_hash}, #{old_hash}, #{JSON.stringify(song)}", 'err'
    .catch (err) ->
        log "sid: #{sid}, #{JSON.stringify(err)}", 'err'

module.exports = (task, option) ->
    task 'default', ['clean'], ->
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

    task 'cdn', ['clean'], ->
        logs = {}
        ips = [
            '222.35.78.36', '180.76.22.36', '163.177.8.36',
            '106.38.179.36', '222.199.191.36', '111.206.76.36',
            '124.193.227.36', '122.70.136.36', '111.13.113.36',
            '122.143.13.36', '124.232.162.36', '118.123.210.36',
            '183.60.131.36', '113.105.244.36', '117.27.148.36',
            '36.248.6.36', '183.61.111.36', '112.90.1.36',
            '211.162.51.36', '183.232.22.36', '61.167.56.36',
            '61.136.173.36', '121.15.253.36', '119.188.176.36',
            '120.192.87.177', '119.188.9.36', '223.99.240.36',
            '124.238.238.36', '59.53.69.36', '117.169.0.36',
            '112.80.252.36', '222.216.229.36', '171.111.156.36',
            '115.231.35.36', '115.231.42.36', '27.221.40.36',
            '119.167.159.36', '211.144.71.36', '112.65.203.36',
            '124.95.170.36', '211.90.25.36', '180.97.66.36',
            '180.97.64.36', '59.49.40.36', '221.204.160.36',
            '60.190.116.36', '61.164.156.36', '113.215.0.222'
        ]

        get_link = (ip, link) ->
            link = url.parse link
            "#{link.protocol}//#{ip}#{link.pathname}#{link.search}"

        i = 0
        get_song('101596497').then (song) ->
            tasks = []
            for ip in ips
                tasks.push do (ip) ->
                    ->
                        link = get_link(ip, song.link)
                        curl(link).then (buf) ->
                            kit.outputFile("./log/#{ip}.#{get_ext(song.link)}", buf)
                            hash = jhash.hash(buf)
                            unless logs[hash]
                                logs[hash] = [ip]
                            else
                                logs[hash].push ip
                            kit.log "#{++i}, #{hash}, #{ip}"
                            kit.outputFile('cdn.txt', JSON.stringify(logs))
                        .catch (err) ->
                            log "ip: #{ip}, #{JSON.stringify(err)}", 'err'
            kit.async(10, tasks).then ->
                kit.log 'All done!'.green

    task 'clean', ->
        kit.remove '*.txt'
        kit.remove './log'
