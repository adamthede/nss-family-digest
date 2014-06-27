require 'answers'

desc "Send Weekly Digest of Answers"
task :answers => :environment do
  if Time.now.friday?
    Answers.send!
  end
end
