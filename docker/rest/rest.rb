#!/usr/bin/env ruby

require 'json'
require_relative './xenapi.rb'
require_relative './messages.rb'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/namespace'

# Class: API
# Inherits from Sinatra::Application, the Application core.
class API < Sinatra::Base
  register Sinatra::JSON
  register Sinatra::Namespace

  configure do
    set :show_exceptions, false
    set :bind, '0.0.0.0'
  end

  # Retry code
  # Auto Retry connect
  # Assume the XenAPI is Dead first
  exception = true

  xenapi = XenApi.new(ENV['XAPI_PATH'], ENV['XAPI_PORT'], ENV['XAPI_SSL'].to_s.eql?('true') ? true : false)
  begin
    xenapi.session_login(ENV['XAPI_USER'], ENV['XAPI_PASS'])
  rescue Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED => _
    # Uh Oh the API is dead, retry
    retry
  else
    # OK the XenAPI is alive, gogogo
    exception = false
  end

  get '/' do
    if exception == false
      200
    else
      503
    end
  end

  namespace '/vm' do
    # Show the records in the database
    get '/' do
      json xenapi.vm_list_all
    end

    get '/byuser/:userid' do |userid|
      json xenapi.vm_search_by_tag('userid:' + userid)
    end

    get '/bytag/:tag' do |tag|
      json xenapi.vm_search_by_tag(tag)
    end

    get '/templates' do
      json xenapi.vm_list_all_templates
    end

    get '/templates/bytag/:tag' do |tag|
      json xenapi.vm_search_templates_by_tag(tag)
    end

    get '/templates/:uuid' do |uuid|
      json xenapi.vm_get_template_record(uuid)
    end

    get '/:uuid' do |uuid|
      json xenapi.vm_get_record(uuid)
    end

    get '/:uuid/metrics' do |uuid|
      json xenapi.vm_get_guest_metrics(uuid)
    end

    get '/:uuid/ip' do |uuid|
      json xenapi.vm_get_guest_metrics_network(uuid)
    end

    get '/:uuid/tags' do |uuid|
      json xenapi.vm_get_tags(uuid)
    end

    get '/:uuid/vifs' do |uuid|
      json xenapi.vm_get_vifs(uuid, true)
    end
  end

  namespace '/net' do
    get '/' do
      json xenapi.network_list
    end

    get '/xencenter' do
      json xenapi.network_get_xc
    end

    get '/auto' do
      json xenapi.network_get_default
    end

    get '/byuser/:userid' do |userid|
      json xenapi.network_search_by_tag('userid:' + userid)
    end

    get '/bytag/:tag' do |tag|
      json xenapi.network_search_by_tag(tag)
    end

    get '/:uuid' do |uuid|
      json xenapi.network_get_detail(uuid)
    end

    get '/:uuid/tags' do |uuid|
      json xenapi.network_get_tags(uuid)
    end
  end

  namespace '/vif' do
    get '/' do
      json xenapi.vif_list
    end

    get '/:uuid' do |uuid|
      json xenapi.vif_get_detail(uuid)
    end
  end

  namespace '/block' do
    namespace '/vdi' do
      get '/' do
        json xenapi.vdi_list('include')
      end

      get '/iso' do
        json xenapi.vdi_list('only')
      end

      get '/disk' do
        json xenapi.vdi_list('exclude')
      end

      get '/xs-tools' do
        json xenapi.vdi_list_tools
      end

      get '/byuser/:userid' do |userid|
        json xenapi.vdi_search_by_tag('userid:' + userid)
      end

      get '/bytag/:tag' do |tag|
        json xenapi.vdi_search_by_tag(tag)
      end

      get '/:uuid' do |uuid|
        json xenapi.vdi_get_record(uuid)
      end

      get '/:uuid/tags' do |uuid|
        json xenapi.vdi_get_tags(uuid)
      end
    end

    namespace '/vbd' do
      get '/' do
        json xenapi.vbd_list
      end

      get '/:uuid' do |uuid|
        json xenapi.vbd_get_detail2(uuid)
      end
    end
  end

  error 404 do
    'Not Found'
  end

  error do
    json env['sinatra.error']
  end
end

API.run!
