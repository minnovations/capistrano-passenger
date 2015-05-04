namespace :passenger do
  desc 'Perform initial Passenger setup'
  task setup: [:create_init_script, :start]

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

    on roles(:app) do
      script = <<-eos
start on runlevel [2345]
stop on runlevel [016]
respawn

exec su - --session-command 'cd #{current_path} && #{fetch(:bundle_command)} exec passenger start --port #{port} --environment #{environment} --log-file log/passenger.log --pid-file tmp/passenger.pid --user #{user} #{ssl_options}'
eos
      init_script_file = "/etc/init/#{fetch(:passenger_app_name, fetch(:application))}.conf"
      tmp_file = "#{fetch(:tmp_dir)}/#{Array.new(10) { [*'0'..'9'].sample }.join}"
      upload! StringIO.new(script), tmp_file
      sudo :cp, '-f', tmp_file, init_script_file
      sudo :chmod, 'ugo+r', init_script_file
      execute :rm, '-f', tmp_file
    end
  end

  desc 'Start Passenger'
  task :start do
    on roles(:app) do
      sudo :start, fetch(:passenger_app_name, fetch(:application))
      sleep 10
      sudo :chown, '-R', "#{host.user}:$(id -gn #{host.user})", fetch(:deploy_to)
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

  after 'deploy:publishing', :soft_restart
end
