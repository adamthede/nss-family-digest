require 'spec_helper'

describe Group, "validations" do
  it { should belong_to(:leader) }
end
