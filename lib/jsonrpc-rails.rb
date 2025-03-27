# frozen_string_literal: true

# Load Rails integration (Railtie, Middleware, etc.)
require_relative "jsonrpc_rails/rails"

# Load core JSON-RPC classes (Request, Response, Error, Notification)
require_relative "json_rpc/json_rpc_error"
require_relative "json_rpc/request"
require_relative "json_rpc/response"
require_relative "json_rpc/notification"

# Define the top-level module for the gem (optional, but good practice)
module JSON_RPC_Rails
  # You might add gem-level configuration or methods here if needed later.
end
