require 'questions'

desc 'Send a random question (Legacy - use question_cycles:activate instead)'
task :questions => :environment do
  if Time.now.monday?
    # Run the question_cycles:activate task instead
    Rake::Task['question_cycles:activate'].invoke
  end
end
