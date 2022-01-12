# frozen_string_literal: true

class UsersController < ApplicationController
  skip_before_action :verify_subscription

  def show
    if current_user.id == params[:id]
      @user = User.find(params[:id])
    else
      @user = current_user
    end
  end

  def edit
    @user = current_user
  end

  def update
    @user = User.find(params[:id])
    if @user.update(permit_params)
      redirect_to edit_user_path(@user), notice: "User updated Successfully."
    else
      render :edit
    end
  end

  def switch_to_landlord
    current_user.update(role:'owner')
    redirect_back fallback_location: edit_user_path(current_user), notice: "Account changed to landlord.  Sign up for a listing subscription and list your first property!"
  end

  def delete_image_attachment
    image = ActiveStorage::Attachment.find(params[:image_id])
    image.purge
    redirect_to edit_user_path(params[:user_id])
  end

  private

    def permit_params
      params.require(:user).permit(:first_name, :last_name, :email, :phone_number, :image)
    end
end
