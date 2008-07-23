# OpenidEnabled
module OpenidEnabled
  
  def self.included(mod)
    mod.extend(ClassMethods)
  end
  
  module ClassMethods
    def openid_enabled
      require 'pathname'
      require 'openid'
      require 'openid/store/filesystem'

      extend OpenidEnabled::SingletonMethods
      include OpenidEnabled::InstanceMethods
    end
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
          redirect_to :action => 'index'
          return
        end
        oidreq = consumer.begin(identifier)
      rescue OpenID::OpenIDError => e
        flash[:error] = "Discovery failed for #{identifier}: #{e}"
        redirect_to :action => 'index'
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
      session_key = (self.class.to_s.underscore + "_openid_url").to_sym
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
        session[session_key] = oidresp.display_identifier
      when OpenID::Consumer::SETUP_NEEDED
        flash[:notice] = "Immediate request failed - Setup Needed"
      when OpenID::Consumer::CANCEL
        flash[:notice] = "OpenID transaction cancelled."
      else
      end
      redirect_to url_for( :action => :index )
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
