namespace :passenger do
  desc 'Perform initial Passenger setup'
  task :setup do
    invoke 'passenger:upload_nginx_config_template' if fetch(:passenger_use_nginx_config_template, false) == true
    invoke 'passenger:create_init_script'
    invoke 'passenger:create_log_rotate_script'
    invoke 'passenger:create_symlink_to_application'
    invoke 'passenger:start'
  end

  desc 'Upload Nginx config template'
  task :upload_nginx_config_template do
    config_template_local = fetch(:passenger_nginx_config_template_local, 'config/deploy/nginx_config_template.conf.erb')
    config_template_remote = fetch(:passenger_nginx_config_template_remote, "#{shared_path}/passenger/nginx_config_template.conf.erb")

    on roles(:app) do
      execute :mkdir, '-p', File.dirname(config_template_remote)
      upload! config_template_local, config_template_remote
    end
  end

  desc 'Create Passenger init script'
  task :create_init_script do
    port = fetch(:passenger_port, 80)
    environment = fetch(:stage)
    user = fetch(:passenger_user, 'webapp')

    ssl_certificate = fetch(:passenger_ssl_certificate, nil)
    ssl_certificate_key = fetch(:passenger_ssl_certificate_key, nil)
    if ssl_certificate && ssl_certificate_key
      ssl_options = "--ssl --ssl-certificate #{ssl_certificate} --ssl-certificate-key #{ssl_certificate_key}"
    else
      ssl_options = nil
    end

    if fetch(:passenger_use_nginx_config_template, false) == true
      nginx_config_template_option = "--nginx-config-template #{fetch(:passenger_nginx_config_template_remote, "#{shared_path}/passenger/nginx_config_template.conf.erb")}"
    else
      nginx_config_template_option = nil
    end

    on roles(:app) do
      script = <<-eos
start on runlevel [2345]
stop on runlevel [016]
respawn

exec su - --session-command 'cd #{current_path} && #{fetch(:bundle_command)} exec passenger start --port #{port} --environment #{environment} --log-file #{current_path}/log/passenger.log --pid-file #{current_path}/tmp/passenger.pid --user #{user} #{ssl_options} #{nginx_config_template_option}'
eos
      init_script_file = "/etc/init/#{fetch(:passenger_app_name, fetch(:application))}.conf"
      tmp_file = "#{fetch(:tmp_dir)}/#{Array.new(10) { [*'0'..'9'].sample }.join}"
      upload! StringIO.new(script), tmp_file
      sudo :cp, '-f', tmp_file, init_script_file
      sudo :chmod, 'ugo+r', init_script_file
      execute :rm, '-f', tmp_file
    end
  end

  desc 'Create Passenger log rotate script'
  task :create_log_rotate_script do
    on roles(:app) do
      script = <<-eos
#{fetch(:passenger_log_dir, "#{shared_path}/log")}/*.log {
  daily
  rotate 7
  compress
  copytruncate
  delaycompress
  missingok
  notifempty
}
eos
      log_rotate_script_file = "/etc/logrotate.d/#{fetch(:passenger_app_name, fetch(:application))}"
      tmp_file = "#{fetch(:tmp_dir)}/#{Array.new(10) { [*'0'..'9'].sample }.join}"
      upload! StringIO.new(script), tmp_file
      sudo :cp, '-f', tmp_file, log_rotate_script_file
      sudo :chmod, 'ugo+r', log_rotate_script_file
      execute :rm, '-f', tmp_file
    end
  end

  desc 'Create symlink to application'
  task :create_symlink_to_application do
    on roles([:web, :app, :db]) do
      execute :ln, '-sf', current_path, "~/#{fetch(:passenger_app_name, fetch(:application))}"
    end
  end

  desc 'Start Passenger'
  task :start do
    on roles(:app) do
      sudo :start, fetch(:passenger_app_name, fetch(:application))
      sleep 10
      sudo :chown, '-R', "#{host.user}:$(id -gn #{host.user})", fetch(:deploy_to)
      sudo :chmod, '-R', 'ug+rw', fetch(:deploy_to)
    end
  end

  desc 'Stop Passenger'
  task :stop do
    on roles(:app) do
      sudo :stop, fetch(:passenger_app_name, fetch(:application))
    end
  end

  desc 'Restart Passenger (hard)'
  task :hard_restart do
    on roles(:app) do
      sudo :bash, '-c', "'stop #{fetch(:passenger_app_name, fetch(:application))} ; sleep 1 ; start #{fetch(:passenger_app_name, fetch(:application))}'"
    end
  end

  desc 'Restart Passenger (soft)'
  task :soft_restart do
    on roles(:app) do
      sudo :bash, '-c', "'cd #{current_path} && #{fetch(:bundle_command)} exec passenger-config restart-app #{deploy_to} --ignore-app-not-running ; true'"
    end
  end

  after 'deploy:publishing', :hard_restart
end
