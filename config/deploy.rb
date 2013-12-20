# Bundler
require 'bundler/capistrano'

# TODO: Change this to ruby-docs.com once the new version is live
server 'new.ruby-docs.com', :app, :web, :db, primary: true

set :application,      'rubydocs'
set :repository,       'git@code.krautcomputing.com:manuel/rubydocs.git'

set :scm,              'git'
set :scm_verbose,      true
set :deploy_via,       :remote_cache
set :keep_releases,    3

set :user,             'deploy'
set :use_sudo,         false

set :deploy_to,        "/home/#{user}/#{application}"
set :rails_env,        'production'
set :branch,           'master'

set :shareds, %w(
  config/database.yml
  config/settings.yml
)

default_run_options[:pty] = true

namespace :deploy do
  desc 'Compare deploy branch HEAD with HEAD of same branch on origin to make sure all commits are pushed'
  task :check_revision, roles: :app do
    if %x(git rev-parse #{branch}) == %x(git rev-parse origin/#{branch})
      puts 'Everything up to date, deploying...'
    else
      puts "HEAD in branch #{branch} is not the same as origin/#{branch}. Did you forget to push?"
      exit
    end
  end

  desc 'Setup shared files and folders'
  task :setup_shareds do
    shareds.each do |shared|
      # Create shared folder
      shared_dir = shared =~ /\./ ? File.dirname(shared) : shared
      run "mkdir -p #{shared_path}/#{shared_dir}"

      # Upload file if present
      local_file = if shared == 'config/database.yml'
        "../deploy/#{fetch(:stage)}/database.yml"
      else
        "../../#{shared}"
      end
      file = File.expand_path(local_file, __FILE__)
      put File.read(file), File.join(shared_path, shared) if File.file?(file)

      # Symlink
      run "ln -nfs #{shared_path}/#{shared} #{release_path}/#{shared}"
    end
  end
end

namespace :monit do
  task :restart_services do
    sudo 'monit reload'
    sudo 'monit restart rubydocs_sidekiq'
    run "cd #{current_path} && bundle exec pumactl -S tmp/pids/puma.state phased-restart"
    # TODO: Use Monit's restart command again as soon as Monit supports custom restart commands.
    # http://nongnu.13855.n7.nabble.com/restart-program-directive-td170064.html
    # sudo 'monit restart rubydocs_puma'
  end
end

before 'deploy',                   'deploy:check_revision'
after  'deploy:update',            'deploy:cleanup'
before 'deploy:assets:precompile', 'deploy:setup_shareds'
after  'deploy',                   'deploy:migrate'
after  'deploy',                   'monit:restart_services'