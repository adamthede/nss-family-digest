require 'spec_helper'

# RSpec
RSpec.describe Question, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:question) }
    it { should validate_presence_of(:user) }
  end
end
