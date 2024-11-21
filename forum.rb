# frozen_string_literal: true

require 'bundler/setup'
require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'BCrypt'
require 'time'

require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
  set :erb, escape_html: true
end

configure :development do
  require 'sinatra/reloader'
  also_reload 'database_persistence.rb'
end

before do
  @storage = DatabasePersistence.new(logger)
end

helpers do
  def format_time(timestamp)
    created_on = Time.parse(timestamp)
    difference = ((Time.now - created_on) / 3600).floor
    days = difference / 24

    return 'just a while ago' if difference.zero?
    return '1 hour ago' if difference == 1
    return "#{difference} hours ago" if difference < 24
    return "#{days} days ago" if days > 1
    '1 day ago'
  end

  def user_is_author?(item)
    session[:username] == item[:username]
  end

  def edit_post?(value)
    value == 'true'
  end

  def edit_comment?(value, comment)
    value == comment[:id]
  end

  def format_comments_count(count)
    return 'no comments' if count.zero?
    return '1 comment' if count == 1
    "#{count} comments"
  end
end

# Check if user is signedin
def require_user_signin(return_to = nil)
  return if session.key?(:username)

  session[:error] = 'You must be signed in.'
  session[:return_to] = return_to
  redirect "/users/signin"
end

# Convert value of query parameter to integer
def format_page(value)
  return 1 if value.nil? || value.empty? || value.count('0') == value.size

  value.to_i
end

# Calculate offset
def offset(page)
  page == 1 ? 0 : (page - 1) * 10
end

# Calculate max page
def max_page(items, limit)
  max = (items / limit).ceil
  max.zero? ? 1 : max
end

def invalid_page?(page, max_page)
  return true unless (page =~ /[^0-9]/).nil?
  return true if format_page(page) > max_page

  false
end

# Render all posts
get '/' do
  require_user_signin(request.url)

  limit = 10
  @max_posts_on_index = max_page(@storage.all_posts_count, limit.to_f)

  if invalid_page?(params[:page], @max_posts_on_index)
    session[:error] = 'Invalid page!'
    redirect '/'
  else
    params[:page] = format_page(params[:page])
    offset = offset(params[:page])
    @posts = @storage.all_posts(offset, limit)
    erb :index
  end
end

# Render signin form
get '/users/signin' do
  erb :signin
end

# Validate user credentials
def valid_credentials?(username, password)
  if (credentials = @storage.find_user(username))
    bcrypt_password = BCrypt::Password.new(credentials['password'])
    bcrypt_password == password
  else
    false
  end
end

# Signin a user
post '/users/signin' do
  username = params[:username]
  return_to = session.delete(:return_to)

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:success] = 'Welcome!'
    redirect return_to || '/'
  else
    session[:error] = 'Invalid credentials!'
    status 422
    erb :signin
  end
end

# Signout a user
post '/users/signout' do
  session.delete(:username)
  redirect '/users/signin'
end

# Validate if post id exists
def valid_post_id?(post_id)
  return true if @storage.all_posts_ids.include?(post_id)

  session[:error] = 'The post does not exist.'
  redirect '/'
end

def load_post(post_id)
  @storage.find_post(post_id) if valid_post_id?(post_id)
end

# Render post page
get '/post' do
  require_user_signin(request.url)

  post_id = params[:id].to_i
  limit = 10
  @post = load_post(post_id)
  @max_comments_on_post = max_page(@post[:comments], limit.to_f)

  if invalid_page?(params[:post_comments_page], @max_comments_on_post)
    session[:error] = 'Invalid page!'
    redirect "/post?id=#{post_id}"
  else
    params[:post_comments_page] = format_page(params[:post_comments_page])
    offset = offset(params[:post_comments_page])
    @comments = @storage.comments_on_post(post_id, offset, limit)
    erb :post
  end
end

# Render form to create post
get '/new' do
  require_user_signin(request.url)

  erb :new
end

# Create a post
post '/create' do
  require_user_signin(request.url)

  title = params[:title].strip

  if !(1..100).cover?(title.size)
    session[:error] = 'Title must be between 1 and 100 characters.'
    status 422
    erb :new
  else
    result = @storage.create_post(session[:username], title, params[:content])
    session[:success] = 'Yay! The post was created.'
    redirect "/post?id=#{result[0]['id']}"
  end
end

# Validate if post exists and session user is author
def valid_post_and_author?(post_id)
  post = load_post(post_id)
  post[:username] == session[:username]
end

# Edit a post
post '/post/:post_id/edit' do |post_id|
  require_user_signin(request.url)

  post_id = post_id.to_i
  if valid_post_and_author?(post_id)
    @storage.edit_post(post_id, params[:content])
    session[:success] = 'The post has been saved.'
    redirect "/post?id=#{post_id}"
  else
    redirect '/'
  end
end

# Delete a post
post '/post/:post_id/delete' do |post_id|
  require_user_signin(request.url)

  post_id = post_id.to_i
  if valid_post_and_author?(post_id)
    @storage.delete_post(post_id)
    session[:success] = 'The post has been deleted.'
  end

  redirect '/'
end

# Add a comment
post '/post/:post_id/add_comment' do |post_id|
  require_user_signin(request.url)

  post_id = post_id.to_i
  valid_post_id?(post_id)

  content = params[:content]
  if content.strip.empty?
    session[:error] = 'Comment cannot be empty!'
  else
    @storage.add_comment(post_id, session[:username], content)
    session[:success] = 'Your comment was added.'
  end

  redirect "/post?id=#{post_id}"
end

# Validate if comment id exists
def valid_comment_id?(comment_id, post_id)
  return true if @storage.all_comment_ids.include?(comment_id)

  session[:error] = 'The comment does not exist.'
  redirect "/post?id=#{post_id}"
end

def load_comment(comment_id, post_id)
  @storage.find_comment(comment_id) if valid_comment_id?(comment_id, post_id)
end

# Validate if comment exists and session user is author
def valid_comment_and_author?(comment_id, post_id)
  comment = load_comment(comment_id, post_id)
  comment[:username] == session[:username]
end

# Render comment
get '/comment' do
  require_user_signin(request.url)

  post_id = params[:post_id].to_i
  comment_id = params[:comment_id].to_i

  if !valid_comment_and_author?(comment_id, post_id)
    session[:error] = 'The comment does not exist.'
    redirect "/post?id=#{post_id}"
  else
    @comment = load_comment(comment_id, post_id)
    erb :comment
  end
end

# Edit a comment
post '/post/:post_id/comment/:comment_id/edit' do |post_id, comment_id|
  require_user_signin(request.url)

  post_id = post_id.to_i
  comment_id = comment_id.to_i
  content = params[:comment_content]

  if valid_comment_and_author?(comment_id, post_id)
    if content.strip.empty?
      session[:error] = 'Comment cannot be empty!'
      redirect "/comment?post_id=#{post_id}&comment_id=#{comment_id}"
    else
      @storage.edit_comment(comment_id, content)
      session[:success] = 'The comment has been saved.'
    end
  end

  redirect "/post?id=#{post_id}"
end

# Delete a comment
post '/post/:post_id/comment/:comment_id/delete' do |post_id, comment_id|
  require_user_signin(request.url)

  post_id = post_id.to_i
  comment_id = comment_id.to_i
  if valid_comment_and_author?(comment_id, post_id)
    @storage.delete_comment(comment_id)
    session[:success] = 'The comment has been deleted.'
  end

  redirect "/post?id=#{post_id}"
end

# Render profile page
get '/profile' do
  require_user_signin(request.url)

  user = session[:username]
  limit = 10
  @max_posts_on_profile = max_page(@storage.count_of_posts_by_user(user), limit.to_f)

  if invalid_page?(params[:posts_profile_page], @max_posts_on_profile)
    session[:error] = 'Invalid page!'
    redirect '/profile'
  else
    params[:posts_profile_page] = format_page(params[:posts_profile_page])
    offset = offset(params[:posts_profile_page])
    @posts = @storage.all_posts_by_user(user, offset, limit)
    erb :profile
  end
end

not_found do
  session[:error] = 'Page not found!'
  redirect '/'
end
