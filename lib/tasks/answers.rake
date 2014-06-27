require 'answers'

desc "Send Weekly Digest of Answers"
task :answers => :environment do
  Answers.send!
end
