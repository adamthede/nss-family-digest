require 'answers'

desc "Send Weekly Digest of Answers (Legacy - use question_cycles:digest instead)"
task :answers => :environment do
  if Time.now.friday?
    # Run the question_cycles:digest task instead
    Rake::Task['question_cycles:digest'].invoke
  end
end
