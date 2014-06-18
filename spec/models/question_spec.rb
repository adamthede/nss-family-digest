require 'spec_helper'

describe Question, "validations" do
  it { should validate_presence_of(:question) }
end
