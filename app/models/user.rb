require 'digest/md5'

class User < ApplicationRecord
  include AnalyticsHelper
  mount_uploader :profile_image, ProfileImageUploader

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :questions
  has_many :groups
  has_many :memberships
  has_many :visits, class_name: 'Ahoy::Visit'
  has_many :events, class_name: 'Ahoy::Event'
  has_many :messages, class_name: 'Ahoy::Message'
  has_many :answers, dependent: :destroy
  has_many :question_records, through: :answers

  validates_presence_of :email

  # Ensures only one user can have global_admin true
  validates :global_admin, uniqueness: true, if: :global_admin?

  after_create :send_welcome_email
  # after_update :send_confirmation_email

  def self.find_or_create_by_email(email)
    user = User.where(email: email).first_or_create do |user|
      user.email = email
      user.password = Devise.friendly_token[0,20]
    end
    user
  end

  def send_welcome_email
    UserMailer.welcome_email(self).deliver
  end

  def send_confirmation_email
    UserMailer.confirmation_email(self).deliver
  end

  def gravatar_url
    md5 = Digest::MD5.new
    hash = md5.hexdigest(email.strip.downcase)
    return 'http://www.gravatar.com/avatar/' + hash
  end

  # Helper method to check global admin privileges
  def global_admin?
    global_admin
  end
end
