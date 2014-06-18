require 'spec_helper'

describe User, "validations" do
  it { should validate_presence_of(:email) }
  it { should validate_presence_of(:password) }
end

describe User, "validating uniqueness of email addresses" do
  it { should validate_uniqueness_of(:email) }
end
