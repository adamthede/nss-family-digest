require 'spec_helper'

describe User, "validations" do
  it { should validate_presence_of(:email) }
  it { should validate_presence_of(:password) }
end

describe User, "validating uniqueness of email addresses" do
  it { should validate_uniqueness_of(:email) }
end

describe User do

  describe "#gravatar_url" do
    context 'with a valid email address' do
      let!(:adam) { Fabricate(:user, email: "adam@cityofthedes.com") }
      it "should match the correct url" do
        adam.gravatar_url.should == "http://www.gravatar.com/avatar/282155455047932483e1c5c23a38e420"
      end
    end

    context "with an email that has uppercase characters" do
      let!(:adam) { Fabricate(:user, email: "Adam@cityofthedes.com") }
      it "should match the correct url" do
        adam.gravatar_url.should == "http://www.gravatar.com/avatar/282155455047932483e1c5c23a38e420"
      end
    end

    context "with an email that has white space after" do
      let!(:adam) { Fabricate(:user, email: "adam@cityofthedes.com  ") }
      it "should match the correct url" do
        adam.gravatar_url.should == "http://www.gravatar.com/avatar/282155455047932483e1c5c23a38e420"
      end
    end
  end
end
