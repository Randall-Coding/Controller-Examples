class AlliesController < ApplicationController
  include AlliesHelper
  layout 'portal'

  before_action :require_ally_owner, except: [:index,:full_index,:new,:create, :create_many]
  before_action :user_onboarded?

  skip_before_action :verify_authenticity_token, only: [:create_many]

  def index
    @allies = current_user.allies_in_cohort
    @current_template = current_user.current_template
    @allies_hash = {}
    @allies.each do |ally|
      @allies_hash[ally.id] = ally.attributes.symbolize_keys
    end
  end

  def full_index
    @allies = current_user.allies
  end

  def show
    @ally = current_user.allies.find(params[:ally_id])
  end

  def new
    @ally = Ally.new
    render '_new.html.erb'
  end

  def create
    if (current_user.allies_in_cohort.count >= 5)
      respond_to do |format|
        format.html { redirect_to allies_path, alert:'5 ally maximum per cohort' ,status:501 }
        format.json { render json: {message:"Reached 5 ally maximum per cohort"}, status:501 }
      end
      return
    end

    @ally = Ally.new(
      firstname:params[:firstname] ,
      lastname: params[:lastname],
      email: params[:email] ,
      image: params[:image] || 'https://avatars1.githubusercontent.com/u/39175191?s=52&v=4',
      phone: params[:phone],
      position: params[:position],
      company: params[:company],
      user_id: current_user.id
    )
    if @ally.save
      respond_to do |format|
        format.html{ redirect_to allies_path, notice: "New ally created"}
        format.json{ render json: {message: "New ally created",ally_id: @ally.id}, status: 200}
      end
    else
      respond_to do |format|
        flash.now[:alert] = "Ally could not save: #{@ally.errors.full_messages}"
        format.html { redirect_to allies_path }
        format.json { render json: {message: 'Ally could not save'}, status:500}
      end
    end
  end

  def create_many
    params[:allies].each do |ally|
      name_count = ally[:name].split(' ').count
      firstname = ally[:name].split(' ')[0]
      lastname = name_count  == 2 ? ally[:name].split(' ')[1] : nil
      Ally.create(firstname: firstname,lastname: lastname, email:ally[:email],user_id:current_user.id)
    end
    respond_to do |format|
      format.html {render_page_not_found}
      format.json {render json: {'message':'referrals created'}, status:200}
    end
  end

  def edit
    @ally = current_user.allies.find(params[:ally_id])
  end

  def update
    @ally = current_user.allies.find(params[:ally_id])

    @ally.firstname = params[:firstname] || @ally.image
    @ally.lastname = params[:lastname]|| @ally.image
    @ally.email = params[:email] || @ally.image
    @ally.image = params[:image] || @ally.image
    @ally.phone = params[:phone]|| @ally.image
    @ally.position = params[:position]|| @ally.image
    @ally.company = params[:company]|| @ally.image
    @ally.user_id = current_user.id

    if @ally.save
      redirect_to ally_path(@ally), notice: "Ally updated"
    else
      flash.now[:alert] = "Ally could not update: #{@ally.errors.full_messages}"
      redirect_to new_ally_path
    end
  end

  def destroy
    @ally = current_user.allies.find(params[:ally_id])

    if @ally.destroy
      respond_to do |format|
        format.html{redirect_to allies_path, notice: "Ally deleted"}
        format.json{render json:{message:"Ally deleted",ally_id: @ally.id}, status:200}
    end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = "Ally could not delete: #{@ally.errors.full_messages}"
          redirect_to allies_path
        end
        format.json{render json:{message:"Failed to delete ally",ally_id: @ally.id}, status:500}
      end
    end
  end
end
