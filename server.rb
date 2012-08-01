require "rubygems"
require "bundler/setup"

require "sinatra"

require "json"

post '/:resource' do
  puts params[:resource]
  puts request.to_yaml
  {'status' => "Success"}.to_json
end
