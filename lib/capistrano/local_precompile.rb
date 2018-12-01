namespace :load do
  task :defaults do
    set :precompile_env,   fetch(:rails_env) || 'production'
    set :assets_dir,       "public/assets"
    set :packs_dir,        "public/packs"
    set :rsync_cmd,        "rsync -av --delete"
    set :assets_role,      "web"
    set :assets_cleanup,    true

    after "bundler:install", "deploy:assets:prepare"
    after "deploy:assets:prepare", "deploy:assets:rsync"
    after "deploy:assets:rsync", "deploy:assets:cleanup"
  end
end

namespace :deploy do
  namespace :assets do
    desc "Remove all local precompiled assets"
    task :cleanup do
      if fetch(:assets_cleanup)
        run_locally do
          with rails_env: fetch(:precompile_env) do
            execute "rm", "-rf", fetch(:assets_dir)
            execute "rm", "-rf", fetch(:packs_dir)
          end
        end
      end
    end

    desc "Actually precompile the assets locally"
    task :prepare do
      run_locally do
        execute "bundle exec rake assets:clean RAILS_ENV=#{fetch(:precompile_env)} NODE_ENV=#{fetch(:precompile_env)}"
        execute "bundle exec rake webpacker:compile RAILS_ENV=#{fetch(:precompile_env)} NODE_ENV=#{fetch(:precompile_env)}"
        execute "bundle exec rake assets:precompile RAILS_ENV=#{fetch(:precompile_env)} NODE_ENV=#{fetch(:precompile_env)} WEBPACKER_PRECOMPILE=no"
      end
    end

    desc "Performs rsync to app servers"
    task :rsync do
      on roles(fetch(:assets_role)) do |server|
        run_locally do
          execute "#{fetch(:rsync_cmd)} ./#{fetch(:assets_dir)}/ #{server.user}@#{server.hostname}:#{release_path}/#{fetch(:assets_dir)}/" if Dir.exists?(fetch(:assets_dir))
          execute "#{fetch(:rsync_cmd)} ./#{fetch(:packs_dir)}/ #{server.user}@#{server.hostname}:#{release_path}/#{fetch(:packs_dir)}/" if Dir.exists?(fetch(:packs_dir))
        end
      end
    end
  end
end
