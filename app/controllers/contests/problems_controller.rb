# -*- coding: utf-8 -*-

class Contests::ProblemsController < AuthController
  before_filter :load_contest
  private
  def load_contest
    @contest = Contest.find(params[:contest_id])
    @score = @contest.scores.where(user_id: @current_user.id)
      .first
    unless @score
      @score = Score.new(contest: @contest, user: @current_user)
      @score.save
    end
  end

  # score calculation: max_score * (1 - 0.5 * time_diff / time_length)
  def calculate_score(max_score)
    time_length = @contest.end_time - @contest.start_time
    time_diff   = Time.now - @contest.start_time
    (max_score * (1 - 0.5 * time_diff / time_length)).to_int
  end

  public
  # GET /contests/1/problems
  # GET /contests/1/problems.json
  def index
    @problems = @contest.problems
    @users = User.where(is_admin: false, 'scores.contest_id' => @contest.id)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @problems }
    end
  end

  # GET /contests/1/problems/1
  # GET /contests/1/problems/1.json
  def show
    @problem = Problem.find(params[:id])
    @input_type = params[:input_type]

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @problem }
    end
  end

  # POST /contests/1/problems/1/submit
  def submit
    problem = Problem.find(params[:id])
    input_type = params[:input_type]

    file = params[:files]
    if file
      if file.size > 100.kilobyte
        raise 'Too large file size'
      end
      output = file.read
    else
      output = params[:text_area]
    end

    @solved = problem.correct?(output, input_type)
    if @current_user.is_admin || (@contest.start_time <= Time.now && Time.now <= @contest.end_time)
      if @solved && !@score.solved_time(problem, input_type)
        max_score = input_type == 'small' ? problem.small_score : problem.large_score
        score = @score.score + calculate_score(max_score)
        @score.update_attributes(score: score)
      end
      Submit.create(solved: @solved, problem_type: input_type, problem: problem, score: @score)
    end

    redirect_to action: 'index'
  end

  # GET /contests/1/problems/new
  # GET /contests/1/problems/new.json
  def new
    @problem = Problem.new
    @problem.description = <<EOL
でかい見出し (h1)
========

普通の見出し (h2)
--------
普通の文章
改行をこまめに入れると綺麗になるよ

### リスト
前後に空行を入れてね
入れ子はスペース4つで

* 1st
* 2nd
* 3rd
    * uno
    * due
    * tre
        * 壱
        * 弐
        * 参
    * quattro

### 番号付きリスト
1. foo
2. bar
3. baz

スペース4つを入れるとブロックっぽくくくられる
これも前後に空行をいれて

    def fib(n)
      @memo = [1,1,2,3]
      @memo[n] || @memo[n] = fib(n-1) + fib(n-2)
    end


画像も表示できるよ！

![](http://cedec.cesa.or.jp/2012/images/speakers/303.jpg)

でもサイズは指定できないから、その時は諦めてimgタグ使ってね

<img src="http://murooka.me/mr.png" width="100">


リンクとか

[3Dげーむ](http://murooka.me/2/pc.html)

引用とか


> すげぇ！<br>
> マジパネェ
>
> 杉本 元気


# でかい見出し
## そこそこな見出し
### 普通の見出し
#### 控えめな見出し
##### 小さな見出し

EOL

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @problem }
    end
  end

  # POST /contests/1/problems
  # POST /contests/1/problems.json
  def create
    @problem = Problem.new(params[:problem])
    @problem.contest_id = params[:contest_id]

    respond_to do |format|
      if @problem.save
        format.html { redirect_to action: 'index' }
        format.json { render json: @problem, status: :created, location: @problem }
      else
        format.html { render action: 'new' }
        format.json { render json: @problem.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /contests/1/problems/1/edit
  def edit
    @problem = Problem.find(params[:id])
  end

  # PUT /contests/1/problems/1
  # PUT /contests/1/problems/1.json
  def update
    @problem = Problem.find(params[:id])

    respond_to do |format|
      if @problem.update_attributes(params[:problem])
        format.html { redirect_to action: 'index' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @problem.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /contests/1/problems/1
  # DELETE /contests/1/problems/1.json
  def destroy
    @problem = Problem.find(params[:id])
    @problem.destroy

    respond_to do |format|
      format.html { redirect_to action: 'index' }
      format.json { head :no_content }
    end
  end

  def download_small
    download(:small)
  end

  def download_large
    download(:large)
  end

  def download(type)
    p = Problem.find(params[:id])
    #head = p.title.gsub(' ', '_') + '_'
    words = p.title.split
    head = words[0] + '_' + words[1] + '_'

    case type
    when :small
      send_data(p.small_input, filename: head + 'small.txt')
    when :large
      send_data(p.large_input, filename: head + 'large.txt')
    end
  end

end
