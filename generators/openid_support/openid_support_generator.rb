class OpenidSupportGenerator < Rails::Generator::NamedBase
  
  def manifest
    record do |m|
      m.migration_template 'add_openid_url_migration.rb', "db/migrate", :migration_file_name => "add_openid_url_to_#{singular_name}"
    end
  end

end
