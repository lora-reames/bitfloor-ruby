#!/usr/bin/env ruby

# classes and methods to communitcate with the bitfloor bitcoin exchange service via their REST API
require 'rubygems'
require 'bundler/setup'

require 'rest_client'
require 'querystring'

require 'json'
require 'openssl'
require 'yaml'
require 'base64'

module BitFloor
  # interact with orders on bitfloor
  class Order
    # create order objects
    def initialize(data, id = nil)
      @data = data
      @id = id
    end

    # list existing orders?
    def self.open_orders
      Remote.send('/orders')
    end

    # save a local order to bitfloor
    def save
      Remote.send('/order/new')
    end

    # cancel an existing order on bitfloor
    def cancel
      Remote.send('/order/cancel')
    end

    # retrieve details from bitfloor for a specific order
    def details
      Remote.send('/order/details')
    end

    def method_missing(method_name, *args, &block)
      @data = pull unless @data.responds_to? :fetch
      @data[method_name]
    end
  private

    # pull will retieve order details from bitfloor	
    def pull
    end
  end

  # sample ignore
  # order = Order.new '/order/details', 1
  # order.status

  class Accounts
    def self.list
      Remote.send('/accounts')
    end
  end

  # interact with bitfloor withdrawl requests
  class Withdrawl
    # create withdrawl objects
    def initialize(currency, ammount, method, destination = nil)
      @currency = currency
      @ammount = ammount
      @method = method
    end

    # push withdrawl requests to bitfloor
    def push
    end
  end

  class Remote
    def self.config(key)
      @env ||= ENV['RUBY_ENV'] || 'development'
      @config ||= YAML.load_file 'config.yml'
      @config[@env][key]
    end

    def self.headers(body)
      sec_key = Base64.strict_decode64(config('secret'))
      hmac = OpenSSL::HMAC.new sec_key, OpenSSL::Digest::Digest.new('SHA512')
      sign = Base64.strict_encode64(hmac.update(body).digest)
      puts sign

      {
        'Content-Type'  => 'application/x-www-form-urlencoded',
        'bitfloor-key'  => config('key'),
        'bitfloor-sign' => sign
      }
    end

    def self.send(suburl, payload = {})
      @remote ||= RestClient::Resource.new config('url'), verify_ssl: OpenSSL::SSL::VERIFY_NONE

      body = QueryString.stringify(payload.merge 'nonce' => Time.now.to_i)

      response = @remote[suburl].post body, headers(body)
      JSON.parse response
    end
  end
end
