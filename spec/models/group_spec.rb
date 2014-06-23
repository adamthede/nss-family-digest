require 'spec_helper'

describe Group, "validations" do
  it { should have_and_belong_to_many(:users) }
end
