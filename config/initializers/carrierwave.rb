CarrierWave.configure do |config|
  if Rails.env.test?
    config.storage = :file
    config.enable_processing = false
  elsif Rails.env.development?
    config.storage = :file
    config.enable_processing = true
  else
    config.storage = :aws
    config.aws_bucket = ENV['S3_BUCKET_NAME']
    config.aws_acl = 'private'

    config.aws_credentials = {
      access_key_id: ENV['S3_KEY'],
      secret_access_key: ENV['S3_SECRET'],
      region: ENV['AWS_REGION']
    }
    config.fog_directory  = ENV['S3_BUCKET_NAME']              # required
  end
end
