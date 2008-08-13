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
      openid_session_sym = (normalized_name + "_openid_url").to_sym  # this is the session symbol that contains the currently active openid_url

      # helper-method to find the user that is currently logged in
      self.send! "define_method", "logged_in_" + normalized_name do
        Kernel.const_get(normalized_name.camelize).send("find_by_openid_url", session[openid_session_sym])
      end

      # Returns the url to redirect to after a successfull identification.  The standard-value is calculated by the given hash and the standard values.
      # When overriding this method, the openid_url of the user that just logged-in is given.
      self.send! "define_method", "login_redirect" do |openid_url|
        hash[:login_redirects_to] || url_for( :action => :index )
      end
      # Returns the url to redirect to after a failed identification.  The standard-value is calculated by the given hash and the standard values.
      # Feel free to override this for custom behavior
      # The error is nil (in which case no openid_url was given)
      #              OpenID::OpenIDError (in which case the OpenID service could not be found)
      #              OpenID::Consumer::FOO in which FOO is one of %w{FAILURE SUCCESS SETUP_NEEDED CANCEL}
      self.send! "define_method", "failed_login_redirect" do |error|
        hash[:failed_login_redirects_to] || url_for( :action => :index )
      end

      # This action is called to start a login.  The openid_url must be set in params[:openid_url].  This will forward the user to the openid service, which will call complete_login of the same controller.
      self.send! "define_method", "start_login" do
        begin
          identifier = params[:openid_url]
          if identifier.nil?
            flash[:error] = "OpenID URL not given"
            redirect_to ( params[:failed_login_redirects_to] || failed_login_redirect( nil ) )
            return
          end
          oidreq = consumer.begin(identifier)
        rescue OpenID::OpenIDError => e
          flash[:error] = "Discovery failed for #{identifier}: #{e}"
          redirect_to ( params[:failed_login_redirects_to] || failed_login_redirect( e ) )
          return
        end

        # individual-form redirection is handled here
        # TODO: convert this to sweetness, it's easy in lisp, there is probably a nice way to do it in rails to (needs expansion of an array or something of the likes)
        return_to = nil
        if params[:login_redirects_to]
          if params[:failed_login_redirects_to]
            return_to = url_for :action => :complete_login, :login_redirect => params[:login_redirects_to], :failed_login_redirect => params[:failed_login_redirects_to]
          else
            return_to = url_for :action => :complete_login, :login_redirect => params[:login_redirects_to]
          end
        else
          if params[:failed_login_redirects_to]
            return_to = url_for :action => :complete_login, :failed_login_redirect => params[:failed_login_redirects_to]
          else
            return_to = url_for :action => :complete_login
          end
        end

        realm = url_for :action => :index
        
        if oidreq.send_redirect?(realm, return_to, params[:immediate])
          redirect_to oidreq.redirect_url(realm, return_to, params[:immediate])
        else
          render :text => oidreq.html_markup(realm, return_to, params[:immediate], {'id' => 'openid_form'})
        end
      end

      # The OpenID service will redirect the client to here after requesting for authorisation.  This action will then send the client further to his distination.
      self.send! "define_method", "complete_login" do
        current_url = url_for :action => :complete_login
        parameters = params.reject{|k,v|request.path_parameters[k]}
        oidresp = consumer.complete(parameters, current_url)
        case oidresp.status
        when OpenID::Consumer::SUCCESS
          flash[:notice] = ("Verification of #{oidresp.display_identifier}"\
                            " succeeded.")
          session[openid_session_sym] = oidresp.display_identifier
          redirect_to params[:login_redirect] || login_redirect( oidresp.display_identifier )
        when OpenID::Consumer::FAILURE
          if oidresp.display_identifier
            flash[:error] = ("Verification of #{oidresp.display_identifier}"\
                             " failed: #{oidresp.message}")
          else
            flash[:error] = "Verification failed: #{oidresp.message}"
          end
          redirect_to params[:failed_login_redirect] || failed_login_redirect( oidresp.status )
        when OpenID::Consumer::SETUP_NEEDED
          flash[:notice] = "Immediate request failed - Setup Needed"
          redirect_to params[:failed_login_redirect] || failed_login_redirect( oidresp.status )
        when OpenID::Consumer::CANCEL
          flash[:notice] = "OpenID transaction cancelled."
          redirect_to params[:failed_login_redirect] || failed_login_redirect( oidresp.status )
        else
          redirect_to params[:failed_login_redirect] || failed_login_redirect( oidresp.status )
        end
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
