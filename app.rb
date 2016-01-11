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
GRID_SIZE = 3

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

  # user確認
  team_id = redis.get req_uuid
  return {team_id: team_id.to_i}.to_json if team_id

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
  redis.set req_uuid, @team_id
  redis.set TEAM[@team_id], nums[@team_id] + 1

  {team_id: @team_id.to_i}.to_json
end

get '/' do
  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      ws.onopen do
        ws.send("Game start!")
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        # EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD

=======
>>>>>>> Stageクラスにグリッド導入
=======
        # 塗り処理
=======
>>>>>>> 塗り判定merge
        ## latとlng来るはずだからそれを元に位置特定してgridのID渡す？
        req = JSON.parse(msg).to_hash
        uuid = req[:uuid]
        lat = req[:lat]
        lng = req[:lng]
<<<<<<< HEAD

>>>>>>> map => stage
        #グリッドの初期化(一度のみ初期化するような設計に)
        grids = initialize_grid()

=======
        recovery_flag = req[:recovery_flag]
        ink_amount = 100
>>>>>>> 塗り判定merge
        #塗り判定処理
        #グリッドの数分ループ
        for i in 0..stage.num_of_grids
          # 塗り処理
          # チームIDをとりあえず入れる
          grids[i].color = redis.get uuid if draw?
        end

        # レスポンス
        response = {
          draw_status: stage.grids
          ink_amount: ink_amount
        }
        ws.send response.to_json
      end
      ws.onclose do
        warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
  end
end

helpers do
<<<<<<< HEAD

<<<<<<< HEAD
  #塗り判定のためのグリッド初期化
  def initialize_grid()
    #グリッドを格納するための配列を初期化
    grids = []

    #インクリメント用の変数
    lat = LAT_START
    lng = LNG_START
    #何メートル四方のグリッドか
    grid_id = 0
    default_color = 0

    while lat + LAT_PER1*GRID_SIZE <= LAT_END do
      while lng + LNG_PER1*GRID_SIZE <= LNG_END do
        #ラフグリッドの要素を作成（4辺）
        grid = Grid.new(grid_id, lat, lng, lat + LAT_PER1, lng + LNG_PER1, default_color)
        #一辺の長さ分インクリメント
        lng += LNG_PER1
        grid_id += 1
        grids << grid
      end
      #一辺の長さ分インクリメント
      lat += LAT_PER1
      #ループのため初期化
      lng = LNG_START
    end
    return grids
  end
end
=======
=======
  def draw?
    (stage.grids[i].sw_lat.to_f <= lat.to_f &&
     stage.grids[i].ne_lat.to_f >= lat.to_f &&
     stage.grids[i].sw_lng.to_f <= lng.to_f &&
     stage.grids[i].ne_lng.to_f >= lng.to_f)
  end
>>>>>>> 塗り判定merge
end
>>>>>>> Stageクラスにグリッド導入
