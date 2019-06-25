require 'sinatra'

get '/' do
  erb :index, :locals => {:hostname => `hostname`}
end
