require 'questions'

desc 'Send a random question'
task :questions => :environment do
  if Time.now.monday?
    Questions.run!
  end
end
