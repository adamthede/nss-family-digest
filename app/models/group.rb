class Group < ApplicationRecord
  belongs_to :leader, :class_name => :User, :foreign_key => 'user_id'
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  # Primary association for library/available questions through group_questions
  has_many :group_questions, dependent: :destroy
  has_many :available_questions, through: :group_questions, source: :question

  # Existing associations for historical/answered questions
  has_many :question_records
  has_many :questions, through: :question_records  # Original association
  has_many :recorded_questions, through: :question_records, source: :question  # Alias for clarity

  has_many :group_question_tags, dependent: :destroy
  has_many :tags, through: :group_question_tags

  validates_presence_of :leader

  def self.add_question_to_group(group, question)
    # First check if the association already exists
    existing = group.group_questions.find_by(question: question)
    return existing if existing

    # If not, create a new association
    group.group_questions.create!(question: question)
  end

  def active_memberships
    memberships.active
  end

  def active_users
    users.joins(:memberships).where(memberships: { group_id: id, active: true }).distinct
  end

  def inactive_memberships
    memberships.inactive
  end

  def inactive_users
    users.joins(:memberships).where(memberships: { group_id: id, active: false }).distinct
  end

  def activate_user!(user)
    memberships.find_by!(user: user).activate!
  end

  def deactivate_user!(user)
    memberships.find_by!(user: user).deactivate!
  end

  def leader?(user)
    leader == user
  end

  def can_manage_members?(user)
    leader?(user)
  end

  def toggle_member_status!(user, active_status, current_user)
    raise "Not authorized to manage members" unless can_manage_members?(current_user)
    membership = memberships.find_by!(user: user)
    active_status ? membership.activate! : membership.deactivate!
  end

  # Returns users ordered by active status and email
  # @param include_leader [Boolean] whether to include the group leader in the results
  # @return [ActiveRecord::Relation] ordered list of users with their membership status
  def ordered_group_members(include_leader: true)
    scope = users
      .select('users.*, memberships.active as membership_active')
      .joins(:memberships)
      .where(memberships: { group_id: id })
      .order('memberships.active DESC, users.email ASC')
      .distinct

    scope = scope.where.not(id: user_id) unless include_leader
    scope
  end

end
