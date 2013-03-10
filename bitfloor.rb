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
    BUY = 0
    SELL = 1
  
    # create order objects
    def initialize(data)
      @data = {product_id: 1}.merge data
    end

    # list existing orders?
    def self.open_orders
      Remote.send('/orders').map { |data| Order.new data }
    end

    # save a local order to bitfloor
    def save
      result = Remote.send '/order/new', @data
      @data.merge! result
    end
    
    def saved?
      @data.has_key 'timestamp'
    end

    # cancel an existing order on bitfloor
    def cancel
      Remote.send '/order/cancel', slice(:order_id, :product_id)
    end

    # retrieve details from bitfloor for a specific order
    def details
      result = Remote.send '/order/details', slice(:order_id)
      @data.merge! result
    end

    # allows direct method like access to individual fields of an order object without the need for individual methods.
    # example: some_order.status would return the status of the order object some_order
    def method_missing(method_name)
      super unless @data.has_key(method_name)
      @data[method_name]
    end
    
  private
    
    def slice(*keys)
      result = {}
      keys.each { |key| result[key] = @data[key] if @data.has_key?(key) }
      result
    end
  end

  # list account balances
  class Accounts
    def self.list
      Remote.send('/accounts')
    end
  end

  # interact with bitfloor withdrawl requests
  class Withdrawl
    # create withdrawl objects
    def initialize(currency, amount, method, destination = nil)
      @data = {
        currency: currency,
        amount: amount,
        method: method
      }
      
      @data.merge!(destination: destination) unless destination.nil?
    end

    # send withdrawl requests to bitfloor
    def save
      Remote.send '/withdraw', @data
    end
  end
  
  # creates groups of orders to buy or sell a given ammount at the best available prices based on existing market data.
  # if not told otherwise with arguments MarketOrder assumes the user is buying btc with usd
  # work in progress
  class MarketOrder
    attr_reader :orders
    
    def initialize(amount, side = 0, product = 1)
      orders = [] # for storing the individual orders created by this market order
      market_order_balance = amount
      while market_order_balance > 0 do
        best_offer = MarketData.l1[:ask][0] # temporary- going to need more work to allow market orders to sell btc
        best_offer_size = MarketData.l1[:ask][1]
        if best_offer_size*best_offer <= market_order_balance
          order_size = best_offer_size
        else
          order_size = market_order_balance
        end
        market_order = Order.new product_id: product, size: order_size, price: best_offer, side: side
        market_order.save #attempt to save order
        if market_order.saved? == true #see if it worked and act accordingly
          market_order_balance = market_order_balance - market_order.size*market_order.price
        else
          puts 'market order failed (responce info here)'
        end
        market_order >> orders #push this order into 'orders' for later refrence.
      end
    end
  end
  
  # gets usable marketdata from bitfloor.
  class MarketData
    # get l1 book from bitfloor
    def self.l1(product = 1)
      responce = RestClient.get "https://api.bitfloor.com/book/L1/#{product}"
      JSON.parse responce, symbolize_names: true
    end
    # get l2 book from bitfloor
    def self.l2(product = 1)
      responce = RestClient.get "https://api.bitfloor.com/book/L2/#{product}"
      JSON.parse responce, symbolize_names: true
    end
    
    # get most resent tick (on execution) from bitfloor
    def self.tick(product = 1)
      responce = RestClient.get "https://api.bitfloor.com/ticker/#{product}"
      JSON.parse responce, symbolize_names: true
    end
    # get day info for past 24hrs from bitfloor
    def self.day_info(product = 1)
      responce = RestClient.get "https://api.bitfloor.com/day-info/#{product}"
      JSON.parse responce, symbolize_names: true
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
      puts sign # debugging stuff delet line later
      puts config('url') # debugging stuff delete line later

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
      JSON.parse response, symbolize_names: true
    end
  end
end

if $0 == __FILE__
  order = BitFloor::Order.new :product_id => 1, :size => 5, :price => 8.70, :side => 0 # < 1.9
  order = BitFloor::Order.new product_id: 1, size: 5, price: 8.70, side: 0 # >= 1.9
  # BitFloor::Remote.send '/order/new', "product_id" => 1, "size" => 5, "price" => 8.70, "side" => 0
end
