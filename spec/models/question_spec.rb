require 'spec_helper'

describe Question, "validations" do
  it { should validate_presence_of(:question) }
  it { should belong_to(:user) }
  it { should validate_presence_of(:user) }
end
