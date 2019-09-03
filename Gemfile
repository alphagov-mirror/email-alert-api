source 'https://rubygems.org'

gem 'pg', '~> 1.1'
gem 'rails', '~> 5.2'

gem 'activerecord-import', '~> 1.0'
gem 'bootsnap', require: false
gem 'with_advisory_lock', '~> 4.0'

gem 'aws-sdk-s3', '~> 1'
gem 'faraday', '0.15.4'
gem 'foreman', '~> 0.85'
gem 'gds-api-adapters', '~> 60.0'
gem 'gds-sso', '~> 14.1'
gem 'govuk_app_config', '~> 1.20'
gem 'govuk_document_types', '~> 0.9.2'
# This is pinned < 2 until gds-sso supports JWT > 2
gem 'json-schema', '~> 2.8.1'
gem 'jwt', '~> 2.2'
gem 'nokogiri', '~> 1.10'
gem 'notifications-ruby-client', '~> 4.0'
gem 'plek', '~> 3.0'
gem 'redcarpet', '~> 3.5'

gem 'govuk_sidekiq', '~> 3.0'
gem 'ratelimit', '~> 1.0'
gem 'sidekiq-scheduler', '~> 3.0'

group :test do
  gem 'climate_control'
  gem 'equivalent-xml'
  gem 'factory_bot_rails'
  gem 'timecop'
  gem 'webmock'
end

group :development, :test do
  gem 'govuk-lint', '~> 3.11'
  gem 'listen', '3.1.5'
  gem 'pry-byebug'
  gem 'rspec-rails', '3.8.2'
  gem 'ruby-prof', '~> 1.0'
end
