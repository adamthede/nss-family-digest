require 'digest/md5'

class User < ActiveRecord::Base
  mount_uploader :profile_image, ProfileImageUploader

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :questions
  has_many :groups
  has_many :memberships

  validates_presence_of :email

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
end
