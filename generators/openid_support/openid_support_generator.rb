class OpenidSupportGenerator < Rails::Generator::NamedBase

  def controller_base_plural
    @args[0].gsub("Controller", "").underscore
  end
  
  def manifest
    record do |m|
      m.migration_template 'add_openid_url_migration.rb', "db/migrate", :migration_file_name => "add_openid_url_to_#{singular_name}"
      m.controller_command @args[0], "openid_enabled \"#{class_name}\""
      m.resource_route table_name.to_sym, { :collection => { :start_login => :get , :complete_login => :get } }
      m.template "_login_form.html.rb", "/app/views/#{controller_base_plural}/_login_form.html.erb", { :controller_base_plural => controller_base_plural }
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
  
  def resource_route( resource, route )
    logger.add_resource_route "map.resources #{resource.inspect}, #{route.inspect}"
    unless options[:pretend]
      base = "map.resources #{resource.inspect}"
      base_regexp = Regexp.escape(base)
      gsub_file 'config/routes.rb', /#{base_regexp}[^\n]*/mi do |match|
        matching_routes = match.scan( /#{base_regexp}\s*,([^\n]+)/ )
        extra = (matching_routes[0] && matching_routes[0][0] && eval("{#{matching_routes[0][0]}}")) || { }
        route.each_pair do |route_key, commands|
          extra[route_key] ||= { }
          commands.each_pair do |key, val|
            extra[route_key][key] = val
          end
        end
        "#{base}, #{extra.inspect.to_s.scan(/^\{(.+)\}$/mi)[0][0].gsub('=>', ' => ')}"
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

  def resource_route( resource, route )
    logger.delete_resource_route "map.resources #{resource.inspect}, #{route.inspect}"

    unless options[:pretend]
      base = "map.resources #{resource.inspect}"
      base_regexp = Regexp.escape(base)
      gsub_file 'config/routes.rb', /#{base_regexp}[^\n]*/mi do |match|
        matching_routes = match.scan( /#{base_regexp}\s*,([^\n]+)/ )
        extra = (matching_routes[0] && matching_routes[0][0] && eval("{#{matching_routes[0][0]}}")) || { }
        extra.delete_if do |main_key, main_val|
          items_to_delete = route[main_key] || { }
          main_val.delete_if do |inner_key, inner_val|
            items_to_delete[inner_key]
          end
          main_val.empty?
        end
        if extra.empty?
          base
        else
          "#{base}, #{extra.inspect.to_s.scan(/^\{(.+)\}$/mi)[0][0].gsub('=>', ' => ')}"
        end
      end
    end
  end
  
end
