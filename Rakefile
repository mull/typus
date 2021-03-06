require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rdoc/task'

task :default => :test

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/app/controllers/**/*_test.rb',
                          'test/app/models/**/*_test.rb',
                          'test/app/mailers/**/*_test.rb',
                          'test/config/*_test.rb',
                          'test/lib/**/*_test.rb']
  t.verbose = true
end

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Typus'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

RUBIES = %w[1.8.7 ree 1.9.2 jruby].join(",")

namespace :setup do

  desc "Setup test environment"
  task :test_environment do
    system "rvm install #{RUBIES}"
  end

  desc "Setup CI Joe"
  task :cijoe do
    system "git config --replace-all cijoe.runner 'rake test:rubies'"
  end

end

namespace :test do

  task :rubies do
    system "rvm #{RUBIES} rake"
  end

end

namespace :submodules do

  desc "Update submodules"
  task :update do
    system "git pull && git submodule update --init"
  end

  desc "Upgrade submodules"
  task :upgrade do
    system "git submodule foreach 'git pull origin master'"
    system "git ci -m 'Updated submodules' ."
  end

end