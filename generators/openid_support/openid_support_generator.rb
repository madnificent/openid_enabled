class OpenidSupportGenerator < Rails::Generator::NamedBase
  
  def manifest
    record do |m|
      m.migration_template 'add_openid_url_migration.rb', "db/migrate", :migration_file_name => "add_openid_url_to_#{singular_name}"
      m.controller_command @args[0], "openid_enabled"
    end
  end

end

class Rails::Generator::Commands::Create
  def controller_command(controller, command, summary = nil)
    summary ||= command
    sentinel = "class #{controller} < ApplicationController"
    
    logger.controller_command "#{controller} :: #{summary}"
    unless options[:pretend]
      gsub_file "app/controllers/#{controller.underscore}.rb", /(#{Regexp.escape(sentinel)})/mi do |match|
        "#{match}\n  #{command}"
      end
    end
  end
end

class Rails::Generator::Commands::Destroy
  def controller_command(controller, command, summary = nil)
    summary ||= command
    logger.controller_command "#{controller} :: #{summary}"
    
    unless options[:pretend]
      gsub_file "app/controllers/#{controller.underscore}.rb", /(#{Regexp.escape(command + "\n")})/mi, ''
    end
    
  end
end
