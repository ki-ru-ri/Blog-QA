class PostsController < ApplicationController
  before_action :authenticate_user!, except: :index

  def index
    @posts = Post.all

    q = params.dig(:search, :q)
    if q.present?
      @posts = @posts.where("title ILIKE '%#{q}' OR html_body ILIKE '%#{q}%'")
    end
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(post_params)
    @post.author = current_user

    if @post.save
      redirect_to post_url(@post), notice: 'Post was created'
    else
      render action: :new
    end
  end

  def show
    @post = Post.find(params[:id])
  end

  def edit
    @post = current_user.posts.find(params[:id])
  end

  def update
    @post = current_user.posts.find(params[:id])
    redirect_to post_url(@post), notice: 'Post was saved'
  end

  def destroy
    current_user.posts.find(params[:id]).destroy
    redirect_to posts_url
  end

  private

  def post_params
    params.require(:post).permit(:title, :html_body)
  end
end
