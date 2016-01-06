# -*- coding: utf-8 -*-
require 'bundler'
Bundler.require
require 'json'

Grid = Struct.new(:grid_id, :sw_lat, :sw_lng, :ne_lat, :ne_lng, :color) 

TEAM = ["team_T", "team_Y"]
#1m単位の緯度，経度
LAT_PER1 = 0.000008983148616
LNG_PER1 = 0.000010966382364
#ステージ範囲（始点，終点）
LAT_START = 34.978691 
LNG_START = 135.961200
LAT_END = 34.984252
LNG_END = 135.965040
set :server, 'thin'
set :sockets, []
redis = Redis.new host:"127.0.0.1", port:"6379"

post '/register' do
  # request = { "uuid": uuid }
  req = JSON.parse(request.body.read).to_hash
  req_uuid = req["uuid"]

  # user確認
  team_id = redis.get req_uuid
  return {team_id: team_id}.to_json if team_id

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

  {team_id: @team_id}.to_json
end

get '/' do
  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      ws.onopen do
        ws.send("Hello World!")
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        # EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
        # 塗り処理
        

        # レスポンス
        ws.send response
      end
      ws.onclose do
        warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
  end
end

get '/test' do
  start = Time.now
  grids = initialize_grid()
  puts Time.now - start
  puts grids[-1]
  #puts grid
end

helpers do

  #塗り判定のためのグリッド初期化
  def initialize_grid()
    #グリッドを格納するための配列を初期化
    grids = []
 
    #インクリメント用の変数
    lat = LAT_START
    lng = LNG_START
    #何メートル四方のグリッドか
    GRID_SIZE = 3
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
