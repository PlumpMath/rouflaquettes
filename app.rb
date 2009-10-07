#!/usr/bin/env rubygems
require 'rubygems'
require 'sinatra'
require 'twitter_oauth'
require 'www/delicious'
require 'erb'

CONTENT_TYPES = {:html => 'text/html', :css => 'text/css', :js  => 'application/javascript'}



configure do
  set :sessions, true
end

before do
  @user = session[:user]
  @client = TwitterOAuth::Client.new(
    :consumer_key => 'Ob88dhyY3G6F04NgHZrCA', #replace with your own consumer key
    :consumer_secret => 'WbWsanzbO8WRcghMBSByIasp7Lyzg63huvYxTGDIw', #replace with your own consumer secret
    :token => session[:access_token],
    :secret => session[:secret_token]
  )
  
  request_uri = case request.env['REQUEST_URI']
    when /\.css$/ : :css
    when /\.js$/  : :js
    else          :html
  end
  content_type CONTENT_TYPES[request_uri], :charset => 'utf-8'
  @statuses = Array.new
  @page = 1
end

get '/' do
  redirect '/timeline' if @user
  erb :index
end

get '/timeline' do
  @tweets = @client.favorites.gsub(/((https?:\/\/|www\.)([-\w\.]+)+(:\d+)?(\/([\w\/_\.]*(\?\S+)?)?)?)/, %Q{<a href="\\1">\\1</a>})
  erb :timeline
end

get '/timeline/:page' do
  @page = params[:page]
  @tweets = @client.favorites(params[:page]).gsub(/((https?:\/\/|www\.)([-\w\.]+)+(:\d+)?(\/([\w\/_\.]*(\?\S+)?)?)?)/, %Q{<a href="\\1">\\1</a>})
  erb :timeline
end

# store the request tokens and send to Twitter
get '/connect' do
  request_token = @client.request_token
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  redirect request_token.authorize_url
end

get '/auth' do
  # Exchange the request token for an access token.
  @access_token = @client.authorize(
    session[:request_token],
    session[:request_token_secret]
  )
  
  if @client.authorized?
      # Storing the access tokens so we don't have to go back to Twitter again
      # in this session.  In a larger app you would probably persist these details somewhere.
      session[:access_token] = @access_token.token
      session[:secret_token] = @access_token.secret
      session[:user] = true
      redirect '/d_auth'
    else
      redirect '/'
  end
end

get '/disconnect' do
  session[:user] = nil
  session[:request_token] = nil
  session[:request_token_secret] = nil
  session[:access_token] = nil
  session[:secret_token] = nil
  redirect '/'
end

get '/d_auth' do
  erb :d_auth
end

post '/d_auth' do
  session[:d_name] = params[:d_name]
  session[:d_password] = params[:d_password]
  #@d_user = WWW::Delicious.new(params[:d_name], params[:d_password])
  redirect '/timeline'
end

post '/bookmark' do
  delicious = WWW::Delicious.new(session[:d_name], session[:d_password])
  
    params[:tweets].each do |tweet|
      @statuses.push(tweet)
    end if params[:tweets]
    
    @statuses.each do |tweet|
      link_regex = /(http:\S+)/    
      links = tweet.scan(link_regex)[0]
      content = tweet.gsub(link_regex, '')
      #Post to del.icio.us
      delicious.posts_add(:url => links[0], :title => content, :notes => 'Imported from Twitter')
    end
end

helpers do
  def make_link(t)
    t.gsub(/((https?:\/\/|www\.)([-\w\.]+)+(:\d+)?(\/([\w\/_\.]*(\?\S+)?)?)?)/, %Q{<a href="\\1">\\1</a>})
  end
end

