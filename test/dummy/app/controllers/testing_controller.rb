
class TestingController < ApplicationController
  def index
    # Simulate a successful JSON-RPC response.
    render jsonrpc: { message: "Hello from JSON-RPC!" }, id: 1
  end

  def error
    # Simulate an error JSON-RPC response.
    render jsonrpc: { code: -32603, message: "Internal error" }, error: true, id: 2
  end
end
