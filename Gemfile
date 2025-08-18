# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'addressable'
gem 'benchmark'
gem 'bootstrap', '~> 4.6.2'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 5.0'
gem 'csv'
gem 'd3-rails'
gem 'dartsass-sprockets' # Sass engine (required by bootstrap
gem 'devise'
gem 'dkim', '~> 1.1'
gem 'font_awesome5_rails', '~> 1.5'
gem 'httparty', '~> 0.23'
gem 'image_processing', '~> 1.2'
gem 'inline_svg', '~> 1.8'
gem 'irb'
gem 'rdoc'
gem 'redis', '~> 4.8'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.11'
gem 'jquery-rails'
gem 'miga-base', '~> 1.3'
gem 'mutex_m'
gem 'pdf-reader'
gem 'pg'
gem 'puma', '~> 5.6'
gem 'rails', '~> 6.1'
gem 'redcarpet', '~> 3.5'
gem 'redirect_safely', '~> 1.0'
gem 'rexml'
gem 'roo', '~> 2.9.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
gem 'serrano', '~> 1.0'
# simple_form 5.3.0 introduced a bug that prevents custom inputs from being
# loaded (see https://github.com/heartcombo/simple_form/issues/1824)
gem 'simple_form', '~> 5.2.0'
gem 'sqlite3'
gem 'strain-code', '~> 0.3'
# Turbolinks makes navigating your web application faster.
# Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
gem 'webpacker'
gem 'whenever', require: false
gem 'wicked_pdf'
gem 'will_paginate'
gem 'will_paginate-bootstrap4'
gem 'wkhtmltopdf-binary', '<= 0.12.6.6' # TODO Temporary fix for large gem
gem 'yui-compressor', '>= 0.12'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger
  # console
  gem 'byebug', platforms: %i[mri windows]
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '~> 2.13'
  gem 'selenium-webdriver'
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the
  # background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  # Access an IRB console on exception pages or by using <%= console %> anywhere
  # in the code.
  gem 'web-console', '>= 3.3.0'
end

group :rubocop do
  gem 'rubocop', '~> 1.62', require: false
  gem 'rubocop-packaging', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
end
