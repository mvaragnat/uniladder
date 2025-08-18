# frozen_string_literal: true

class ContactsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(contact_params)

    if @contact.valid?
      ContactMailer.notify(@contact.subject, @contact.content).deliver_now
      redirect_to root_path, notice: t('contact.create.success')
    else
      flash.now[:alert] = t('contact.create.failure')
      render :new, status: :unprocessable_entity
    end
  end

  private

  def contact_params
    params.expect(contact: %i[subject content])
  end
end
