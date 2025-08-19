# frozen_string_literal: true

class Contact
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :subject, :string
  attribute :content, :string
  attribute :username, :string

  validates :subject, presence: true, length: { maximum: 200 }
  validates :content, presence: true, length: { maximum: 5000 }
end
