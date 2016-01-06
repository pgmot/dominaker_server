require 'bundler'
Bundler.require
require 'json'

TEAM = ["team_T", "team_Y"]
set :server, 'thin'
set :sockets, []
redis = Redis.new host:"127.0.0.1", port:"6379"

post '/register' do
  req = JSON.parse(request.body.read).to_hash
  req_uuid = req["uuid"]
  flag = 0
  puts team_id = [0,1].sample
  response = {team_id: team_id}
  users = redis.lrange :users, 0, -1
  users.each do |user|
    user = JSON.parse(user).to_hash
    if req_uuid == user[:uuid]
      flag = 1
      response[:team_id] = user[:team_id]
    end
  end
  redis.rpush :users, {uuid: req_uuid, team_id: team_id}.to_json if flag == 0
  response.to_json
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
