# frozen_string_literal: true

class TestingController < ApplicationController
  def index
    # Simulate a successful JSON-RPC response.
    render jsonrpc: { message: "Hello from JSON-RPC!" }, id: 1
  end

  def error_symbol
    # Simulate an error using a symbol
    render jsonrpc: {}, error: :method_not_found, id: 3
  end

  def error_symbol_with_override
    # Simulate an error using a symbol and overriding the message/data
    render jsonrpc: { message: "Custom method not found", data: { info: "more details" } }, error: :method_not_found,
           id: 4
  end

  def error_code
    # Simulate an error using a numeric code (uses default message)
    render jsonrpc: {}, error: -32_600, id: 5 # Invalid Request
  end

  def error_code_with_override
    # Simulate an error using a numeric code and overriding the message/data
    render jsonrpc: { message: "Specific invalid request", data: { field: "xyz" } }, error: -32_600, id: 6
  end

  def rpc_endpoint
    # This action is hit only if the JSON-RPC Validator middleware passes the request.
    # We return a valid JSON-RPC success response, using the ID from the request.
    # The middleware stores the parsed payload (Hash or Array) in the env.
    payload = jsonrpc

    # For simplicity in this test endpoint, we'll just handle single requests for ID extraction.
    # A real endpoint would need more robust handling for batch requests.
    request_id = payload.is_a?(JSON_RPC::Request) ? payload.id : nil

    render jsonrpc: { message: "Request processed successfully" }, id: request_id
  end
end
