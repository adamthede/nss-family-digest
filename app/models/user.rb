require 'digest/md5'

class User < ActiveRecord::Base
  mount_uploader :profile_image, ProfileImageUploader
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :questions
  has_and_belongs_to_many :groups

  after_create :send_welcome_email

  def send_welcome_email
    UserMailer.welcome_email(self).deliver
  end

  def gravatar_url
    md5 = Digest::MD5.new
    hash = md5.hexdigest(email.strip.downcase)
    return 'http://www.gravatar.com/avatar/' + hash
  end
end
