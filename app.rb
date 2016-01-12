# -*- coding: utf-8 -*-
require 'bundler'
Bundler.require
require 'json'
require './lib/stage'

TEAM = ["team_T", "team_Y"]
# ステージ範囲（始点，終点）
LAT_START = 34.978691
LNG_START = 135.961200
LAT_END = 34.984252
LNG_END = 135.965040

set :server, 'thin'
set :sockets, []

if ENV["REDISTOGO_URL"] != nil
  uri = URI.parse(ENV["REDISTOGO_URL"])
  redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
else
  redis = Redis.new host:"127.0.0.1", port:"6379"
end
grids = Array.new
stage = nil

configure do
  stage = Stage.new(LAT_START, LNG_START, LAT_END, LNG_END)
end

post '/register' do
  # request = { "uuid": uuid }
  req = JSON.parse(request.body.read).to_hash
  req_uuid = req["uuid"]

  # user 確認
  if user = redis.get(req_uuid)
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
  redis.set req_uuid, {team_id: @team_id, ink_amount: 100}.to_json
  redis.set TEAM[@team_id], nums[@team_id] + 1

  # response = {"team_id": team_id}
  {team_id: @team_id.to_i}.to_json
end

get '/' do
  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      ws.onopen do
        ws.send("Open")
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        # EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
        # 塗り処理
        ## latとlng来るはずだからそれを元に位置特定してgridのID渡す？
        req = JSON.parse(msg).to_hash
        uuid = req[:uuid]
        lat = req[:lat]
        lng = req[:lng]
        draw_ids = Array.new

        recovery_flag = false
        user_data = JSON.parse(redis.get(req_uuid))
        team_id = user_data["team_id"].to_i
        ink_amount = user_data["ink_amount"].to_i

        # レスポンス
        # response = {
        #   draw_status: draw_ids,
        #   ink_amount: ink_amount,
        #   recovery_flag: recovery_flag
        # }

        #塗り判定処理
        ## インク残量が10未満なら塗り処理せずにそのままresponse返す
        return { draw_status: draw_ids, ink_amount: ink_amount, recovery_flag: recovery_flag }.to_json if ink_amount < 10

        #グリッドの数分ループ
        for i in 0..stage.num_of_grids
          # 塗り処理
          if draw?(stage.grids[i], lat, lng)
            stage.grids[i].color = redis.get uuid
            draw_ids << i
          end
        end

        # response
        ws.send { draw_status: draw_ids, ink_amount: ink_amount-10, recovery_flag: recovery_flag }.to_json
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
    (grid.sw_lat.to_f <= lat.to_f &&
     grid.ne_lat.to_f >= lat.to_f &&
     grid.sw_lng.to_f <= lng.to_f &&
     grid.ne_lng.to_f >= lng.to_f)
  end
end
