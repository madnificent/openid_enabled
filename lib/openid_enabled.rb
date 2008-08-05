# OpenidEnabled
module OpenidEnabled
  
  def self.included(mod)
    mod.extend(ClassMethods)
  end
  
  module ClassMethods
    def openid_enabled( name, hash = { } )
      require 'pathname'
      require 'openid'
      require 'openid/store/filesystem'

      normalized_name = name.to_s.underscore

      self.send! "define_method", "openid_session_sym" do 
        (normalized_name + "_openid_url").to_sym 
      end

      self.send! "define_method", "logged_in_" + normalized_name do
        Kernel.const_get(normalized_name.camelize).send("find_by_openid_url", session[openid_session_sym])
      end

      self.send! "define_method", "login_redirect" do
        hash[:login_redirects_to] || url_for( :action => :index )
      end
      self.send! "define_method", "failed_login_redirect" do
        hash[:failed_login_redirects_to] || url_for( :action => :index )
      end

      extend OpenidEnabled::SingletonMethods
      include OpenidEnabled::InstanceMethods
    end

    def talks_openid( name )
      normalized_name = name.to_s.underscore
      openid_session_sym = (normalized_name + "_openid_url").to_sym
      
      self.send! "define_method", "logged_in_" + normalized_name do
        Kernel.const_get(normalized_name.camelize).send("find_by_openid_url", session[openid_session_sym])
      end
    end

    alias_method :has_openid, :openid_enabled
  end
  
  module SingletonMethods
    # No singletonmethods
  end
  
  module InstanceMethods
    # The wonder methods
    def start_login
      begin
        identifier = params[:openid_url]
        if identifier.nil?
          flash[:error] = "OpenID URL not given"
          redirect_to failed_login_redirect
          return
        end
        oidreq = consumer.begin(identifier)
      rescue OpenID::OpenIDError => e
        flash[:error] = "Discovery failed for #{identifier}: #{e}"
        redirect_to failed_login_redirect
        return
      end
      return_to = url_for :action => :complete_login
      realm = url_for :action => :index
      
      if oidreq.send_redirect?(realm, return_to, params[:immediate])
        redirect_to oidreq.redirect_url(realm, return_to, params[:immediate])
      else
        render :text => oidreq.html_markup(realm, return_to, params[:immediate], {'id' => 'openid_form'})
      end
    end
    
    def complete_login
      current_url = url_for :action => :complete_login
      parameters = params.reject{|k,v|request.path_parameters[k]}
      oidresp = consumer.complete(parameters, current_url)
      case oidresp.status
      when OpenID::Consumer::FAILURE
        if oidresp.display_identifier
          flash[:error] = ("Verification of #{oidresp.display_identifier}"\
                           " failed: #{oidresp.message}")
        else
          flash[:error] = "Verification failed: #{oidresp.message}"
        end
      when OpenID::Consumer::SUCCESS
        flash[:notice] = ("Verification of #{oidresp.display_identifier}"\
                          " succeeded.")
        session[openid_session_sym] = oidresp.display_identifier
      when OpenID::Consumer::SETUP_NEEDED
        flash[:notice] = "Immediate request failed - Setup Needed"
      when OpenID::Consumer::CANCEL
        flash[:notice] = "OpenID transaction cancelled."
      else
      end
      redirect_to login_redirect
    end

    def consumer
      if @consumer.nil?
        dir = Pathname.new(RAILS_ROOT).join('db').join('cstore')
        store = OpenID::Store::Filesystem.new(dir)
        @consumer = OpenID::Consumer.new(session, store)
      end
      return @consumer
    end
  end
end
