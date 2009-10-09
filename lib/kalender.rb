require 'rubygems'
require 'sinatra'

get '/' do
  "Hello World!"+ "I'm running version " + Sinatra::VERSION
end

get '/hello/?' do
  "Hello again!"
end
