require 'bundler'
Bundler.require
require 'json'

TEAM = ["team_T", "team_Y"]
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
        EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
      end
      ws.onclose do
        warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
  end
end
