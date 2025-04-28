# frozen_string_literal: true

require_relative "jsonrpc_rails/railtie"

require_relative "json_rpc/json_rpc_error"
require_relative "json_rpc/request"
require_relative "json_rpc/response"
require_relative "json_rpc/notification"

# Define the top-level module for the gem (optional, but good practice)
module JSONRPC_Rails
  # You might add gem-level configuration or methods here if needed later.
end
