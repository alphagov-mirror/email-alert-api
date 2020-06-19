source "https://rubygems.org"

gem "rails", "~> 6"

gem "aws-sdk-s3", "~> 1"
gem "bootsnap", "~> 1", require: false
gem "faraday", "~> 1"
gem "gds-api-adapters", "~> 67"
gem "gds-sso", "~> 15"
gem "govuk_app_config", "~> 2"
gem "govuk_document_types", "~> 0"
gem "govuk_sidekiq", "~> 3"
gem "json-schema", "~> 2"
gem "jwt", "~> 2"
gem "nokogiri", "~> 1"
gem "notifications-ruby-client", "~> 5"
gem "pg", "~> 1"
gem "plek", "~> 3"
gem "ratelimit", "~> 1"
gem "redcarpet", "~> 3"
gem "sidekiq-scheduler", "~> 3"
gem "with_advisory_lock", "~> 4"

group :test do
  gem "climate_control"
  gem "equivalent-xml"
  gem "factory_bot_rails"
  gem "timecop"
  gem "webmock"
end

group :development, :test do
  gem "listen"
  gem "pry-byebug"
  gem "rspec-rails"
  gem "rubocop-govuk"
end
