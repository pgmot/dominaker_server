require 'bundler'
Bundler.require
require 'json'
require './lib/stage'

TEAM = ["team_T", "team_Y"]
# ステージ範囲（始点，終点）
LAT_START =  34.978691
LNG_START = 135.961200
LAT_END   =  34.984252
LNG_END   = 135.965040

set :server, 'thin'
set :sockets, []
set :result, []
set :stage, nil

ws_msg_type = ["status", "msg"]

if ENV["REDISTOGO_URL"] != nil
  uri = URI.parse(ENV["REDISTOGO_URL"])
  redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
else
  redis = Redis.new host:"127.0.0.1", port:"6379"
end
stage = nil
scheduler = Rufus::Scheduler.new

configure do
  stage = Stage.new(LAT_START, LNG_START, LAT_END, LNG_END)
end

# ゲームスタート前にマップリセット
scheduler.cron '0 9 * * *' do
  stage = Stage.new(LAT_START, LNG_START, LAT_END, LNG_END)
  settings.result = []
  settings.stage = nil
end

# 20秒毎に状況表示
## この機能使って定期的にクライアント側の更新かけてもらうのもありかもしれん
#scheduler.every '20s' do
#  result = stage.draw_rate
#  puts "#{TEAM[0]}:#{result[0] / stage.num_of_grids * 100}%"
#  puts "#{TEAM[1]}:#{result[0] / stage.num_of_grids * 100}%"
#end

# 21時に勝敗判定して，その後にredisリセット
scheduler.cron '0 21 * * *' do
  result = stage.draw_rate
  puts "#{TEAM[0]}:#{result[0] / stage.num_of_grids * 100}%"
  puts "#{TEAM[1]}:#{result[0] / stage.num_of_grids * 100}%"
  # なんかあった時のために一旦setに置く（その必要はなさそうだが）
  settings.result = result
  settings.stage = stage

  # redis全消去
  redis.keys.each do |key|
    redis.del key
  end

  # team_id毎に結果を保存
  redis.set "result_0", result[0] / stage.num_of_grids * 100
  redis.set "result_1", result[1] / stage.num_of_grids * 100
end

post '/register' do
  # request = { "uuid": uuid }
  req = JSON.parse(request.body.read)
  uuid = req["uuid"]

  # user 確認
  if user = redis.get(uuid)
    team_id = JSON.parse(user)["team_id"]
    return {team_id: team_id.to_i}.to_json
  end

  # チーム割り当て
  num_of_Tteam = redis.get TEAM[0]
  num_of_Yteam = redis.get TEAM[1]
  nums = [num_of_Tteam.to_i, num_of_Yteam.to_i]
  diff = nums[0] - nums[1]
  if diff == 0
    @team_id = [0,1].sample
  elsif diff < 0
    @team_id = 0
  else
    @team_id = 1
  end
  redis.set uuid, {team_id: @team_id, ink_amount: 100, last_recovery_status: false, last_update: Time.now.to_f}.to_json
  redis.set TEAM[@team_id], nums[@team_id] + 1

  {team_id: @team_id.to_i}.to_json
end

get '/map' do
  stage.grids.reject{|grid| grid.color == -1}.map{|grid| {:id => grid.id, :team_id => grid.color}}.to_json
end

get '/' do
  puts "num of grid #{stage.grids.length}"
  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      ws.onopen do
        #ws.send("Open")
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        # EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
        # requestのパース
        p req = JSON.parse(msg)
        uuid = req["uuid"]
        lat = req["lat"].to_f
        lng = req["lng"].to_f
        draw_flag = req["draw_flag"]

        # redisからuuid使ってデータ抜き出し
        user_data = JSON.parse(redis.get(uuid))
        team_id = user_data["team_id"].to_i
        ink_amount = user_data["ink_amount"].to_i
        last_update = Time.at(user_data["last_update"].to_f)

        recovery_flag = recovery?(stage.recovery_areas, lat, lng)
        draw_ids = Array.new

        # 全員対戦モードに参加している場合は9時から21時まで（時間は適宜変更します）
        # 平日判定があってもいいかも
        now = Time.now
        if now.hour >= 21 and now.hour < 9
          ws.send({type: "msg", data: {msg: "not battle now"}}.to_json)
        end

        # インク回復処理
        if recovery_flag
          times = now - last_update if user_data["last_recovery_status"]
          times ||= 1
          ink_amount += 10*times
        end

        # 塗り判定処理
        ## インク残量が10未満なら塗り処理せずにそのままresponse返す
        #puts "num of grid #{stage.num_of_grids}"
        if ink_amount >= 10 && draw_flag
          #puts "#{lat}, #{lng}"
          #グリッドの数分ループ
          stage.grids.each do |grid|
            #puts grid
            # 塗り処理
            if draw?(grid, lat, lng)
              puts "#{grid}: #{lat}, #{lng}"
              grid.color = team_id
              draw_ids << grid.id
            end
          end
          # 一回の塗りで10減らす
          ink_amount -= 10
        end
        # redisの情報更新
        redis.set uuid, {team_id: team_id, ink_amount: ink_amount.to_i, last_update: now.to_f}.to_json

        # response
        ws.send({type: "status", data: {draw_status: draw_ids, ink_amount: ink_amount.to_i, recovery_flag: recovery_flag} }.to_json)
      end
      ws.onclose do
        warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
  end
end

helpers do
  def draw?(grid, lat, lng)
    (grid.sw_lat <= lat.to_f and
     grid.ne_lat >= lat.to_f and
     grid.sw_lng <= lng.to_f and
     grid.ne_lng >= lng.to_f)
  end

  def recovery?(recovery_areas, lat, lng)
    recovery_areas.each do |area|
      return true if (area.sw_lat <= lat.to_f and
                      area.ne_lat >= lat.to_f and
                      area.sw_lng <= lng.to_f and
                      area.ne_lng >= lng.to_f)
    end
    false
  end

end
