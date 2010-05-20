require 'rubygems'
require 'em-websocket'
require 'twitter/json_stream'
require 'yaml'
require 'yajl'

credentials = YAML.load(File.open('credentials.yml'))
username = credentials['username']
password = credentials['password']
terms = ['yankees', 'kobe', 'ruby', 'jquery']

puts "Connecting to twitter stream as #{username}"

def post?(status)
  post = true
  
  parsed_status = Yajl::Parser.parse(status)
  post = (parsed_status['text'].downcase =~ /suck/) 

  post
end

EventMachine.run {
  @channel = EM::Channel.new

  @twitter = Twitter::JSONStream.connect(
    :path => '/1/statuses/filter.json',
    :auth => "#{username}:#{password}",
    :method  => 'POST',
    :content => "track=#{terms.join(',')}"
  )

  @twitter.each_item do |status| 
    parsed_status = Yajl::Parser.parse(status)
    
    @channel.push status unless (parsed_status['text'].downcase =~ /suck/)
  end

  @twitter.on_error do |message|
    puts message
      # No need to worry here. It might be an issue with Twitter. 
      # Log message for future reference. JSONStream will try to reconnect after a timeout.
  end

  EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080, :debug => true) do |ws|

    ws.onopen {
      sid = @channel.subscribe { |msg| ws.send msg }
      # @channel.push "#{sid} connected!"

      ws.onmessage { |msg|
        @channel.push "<#{sid}>: #{msg}"
      }

      ws.onclose {
        @channel.unsubscribe(sid)
      }

    }
  end

  trap('TERM') {  
    @twitter.stop
    EventMachine.stop if EventMachine.reactor_running? 
  }

  puts "Server started"
}