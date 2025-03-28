# frozen_string_literal: true

require "test_helper"
require "rack/test"
require "jsonrpc_rails/middleware/validator" # Make sure middleware is loaded

# Simple Rack app to terminate the stack
class MockApp
  def call(env)
    # Store the env for inspection and return a simple success response
    @last_env = env
    [ 200, { "Content-Type" => "text/plain" }, [ "OK" ] ]
  end

  attr_reader :last_env
end

class JSON_RPC_Rails::Middleware::ValidatorTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    @mock_app = MockApp.new
    # Build the Rack app stack with the validator middleware
    @app = JSON_RPC_Rails::Middleware::Validator.new(@mock_app)
  end

  def app
    @app
  end

  # --- Test Cases ---

  def test_get_request_passes_through
    get "/"
    assert last_response.ok?
    assert_equal "OK", last_response.body
    assert_nil @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
  end

  def test_post_without_json_content_type_passes_through
    post "/", { data: "value" }.to_json, { "CONTENT_TYPE" => "text/plain" }
    assert last_response.ok?
    assert_equal "OK", last_response.body
    assert_nil @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
  end

  def test_invalid_json_passes_through
    # Unparsable JSON should skip validation and pass through
    post "/", '{"jsonrpc": "2.0", "method": "test", "params": [1, 2', { "CONTENT_TYPE" => "application/json" }
    assert last_response.ok? # Should pass through to mock app
    assert_equal "OK", last_response.body
    assert_nil @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY] # No payload stored
  end

  def test_valid_single_request_passes_through
    payload = { "jsonrpc" => "2.0", "method" => "subtract", "params" => [ 42, 23 ], "id" => 1 }
    post "/", payload.to_json, { "CONTENT_TYPE" => "application/json" }

    assert last_response.ok?, "Expected OK response, got #{last_response.status}"
    assert_equal "OK", last_response.body
    # Verify payload is stored in env for the downstream app
    refute_nil @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
    assert_equal payload, @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
  end

  def test_single_request_invalid_structure
    # Payloads with 'jsonrpc' but failing strict validation should return 400
    invalid_rpc_payloads = [
      { "jsonrpc" => "1.0", "method" => "foo", "id" => 1 },               # Wrong jsonrpc version
      { "jsonrpc" => "2.0", "id" => 1 },                                  # Missing method
      { "jsonrpc" => "2.0", "method" => 123, "id" => 1 },                 # Method not a string
      { "jsonrpc" => "2.0", "method" => "foo", "params" => 123, "id" => 1 }, # Params not array/object
      { "jsonrpc" => "2.0", "method" => "foo", "id" => {} }               # ID not string/number/null
    ]
    # Payloads missing 'jsonrpc' should pass through
    passthrough_payloads = [
      { "method" => "foo", "id" => 1 }                                  # Missing jsonrpc
    ]

    expected_error_body = { "jsonrpc" => "2.0", "error" => { "code" => -32600, "message" => "Invalid Request" }, "id" => nil }

    invalid_rpc_payloads.each do |payload|
      post "/", payload.to_json, { "CONTENT_TYPE" => "application/json" }
      assert_equal 400, last_response.status, "[Should Fail] Failed for payload: #{payload.inspect}"
      assert_equal "application/json", last_response.content_type, "[Should Fail] Failed for payload: #{payload.inspect}"
      assert_equal expected_error_body, JSON.parse(last_response.body), "[Should Fail] Failed for payload: #{payload.inspect}"
    end

    passthrough_payloads.each do |payload|
      post "/", payload.to_json, { "CONTENT_TYPE" => "application/json" }
      assert last_response.ok?, "[Should Pass Through] Failed for payload: #{payload.inspect}"
      assert_equal "OK", last_response.body, "[Should Pass Through] Failed for payload: #{payload.inspect}"
      assert_nil @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY], "[Should Pass Through] Failed for payload: #{payload.inspect}"
    end
  end

  def test_single_request_with_extraneous_key_returns_error
    payload = { "jsonrpc" => "2.0", "method" => "foo", "id" => 1, "extra_key" => "disallowed" }
    expected_error_body = { "jsonrpc" => "2.0", "error" => { "code" => -32600, "message" => "Invalid Request" }, "id" => nil }

    post "/", payload.to_json, { "CONTENT_TYPE" => "application/json" }
    assert_equal 400, last_response.status
    assert_equal "application/json", last_response.content_type
    assert_equal expected_error_body, JSON.parse(last_response.body)
  end

  # TODO: Test single request with invalid param types -> Invalid Request -32600 (Covered by invalid structure test)
  # TODO: Test single request with invalid id types -> Invalid Request -32600 (Covered by invalid structure test)

  def test_valid_batch_request_passes_through
    payload = [
      { "jsonrpc" => "2.0", "method" => "notify_sum", "params" => [ 1, 2, 4 ] },
      { "jsonrpc" => "2.0", "method" => "subtract", "params" => [ 42, 23 ], "id" => "abc" }
    ]
    post "/", payload.to_json, { "CONTENT_TYPE" => "application/json" }

    assert last_response.ok?, "Expected OK response, got #{last_response.status}"
    assert_equal "OK", last_response.body
    # Verify payload is stored in env
    refute_nil @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
    assert_equal payload, @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
  end

  def test_empty_batch_request_passes_through
    # Empty batch does not meet criteria (all Hashes AND any jsonrpc), should pass through
    payload = []
    post "/", payload.to_json, { "CONTENT_TYPE" => "application/json" }
    assert last_response.ok? # Should pass through
    assert_equal "OK", last_response.body
    assert_nil @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
  end

  def test_batch_with_invalid_element_returns_error
    payload = [
      { "jsonrpc" => "2.0", "method" => "valid_one", "id" => 1 },
      { "method" => "invalid_one" } # Missing jsonrpc
    ]
    expected_error_body = { "jsonrpc" => "2.0", "error" => { "code" => -32600, "message" => "Invalid Request" }, "id" => nil }

    post "/", payload.to_json, { "CONTENT_TYPE" => "application/json" }
    assert_equal 400, last_response.status
    assert_equal "application/json", last_response.content_type
    assert_equal expected_error_body, JSON.parse(last_response.body)
  end

  def test_single_request_object_treated_as_single_request
    # Test sending a single valid request object (which is not an array)
    payload = { "jsonrpc" => "2.0", "method" => "foo", "id" => 1 }
    # This is a valid single request, so it should pass validation.

    post "/", payload.to_json, { "CONTENT_TYPE" => "application/json" }

    # Assert it behaves like a valid single request
    assert last_response.ok?, "Expected OK response, got #{last_response.status}"
    assert_equal "OK", last_response.body
    refute_nil @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
    assert_equal payload, @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
  end

  def test_batch_with_invalid_element_structure
    # Batches that trigger validation (all Hashes, any jsonrpc) but contain an invalid element should error
    invalid_rpc_batches = [
      # Batch containing an element missing jsonrpc (but another element has it, triggering validation)
      [ { "jsonrpc" => "2.0", "method" => "valid" }, { "method" => "invalid", "id" => 1 } ],
      # Batch containing an element with wrong jsonrpc version
      [ { "jsonrpc" => "2.0", "method" => "valid" }, { "jsonrpc" => "1.0", "method" => "invalid", "id" => 2 } ],
      # Batch containing an element missing method
      [ { "jsonrpc" => "2.0", "method" => "valid" }, { "jsonrpc" => "2.0", "id" => 3 } ],
      # Batch containing an element with non-string method
      [ { "jsonrpc" => "2.0", "method" => "valid" }, { "jsonrpc" => "2.0", "method" => 123, "id" => 4 } ],
      # Batch containing an element with invalid params type
      [ { "jsonrpc" => "2.0", "method" => "valid" }, { "jsonrpc" => "2.0", "method" => "invalid", "params" => 1, "id" => 5 } ],
      # Batch containing an element with invalid id type
      [ { "jsonrpc" => "2.0", "method" => "valid" }, { "jsonrpc" => "2.0", "method" => "invalid", "id" => {} } ],
      # Batch containing an element with extraneous key
      [ { "jsonrpc" => "2.0", "method" => "valid" }, { "jsonrpc" => "2.0", "method" => "invalid", "id" => 6, "extra" => true } ]
    ]
    # Batches that do NOT trigger validation should pass through
    passthrough_batches = [
      # Array contains non-hash element
      [ { "jsonrpc" => "2.0", "method" => "valid" }, "not a hash" ],
      # Array contains only hashes, but NONE have 'jsonrpc' key
      [ { "method" => "foo", "id" => 1 }, { "method" => "bar", "id" => 2 } ]
    ]


    expected_error_body = { "jsonrpc" => "2.0", "error" => { "code" => -32600, "message" => "Invalid Request" }, "id" => nil }

    invalid_rpc_batches.each do |payload|
      post "/", payload.to_json, { "CONTENT_TYPE" => "application/json" }
      assert_equal 400, last_response.status, "[Should Fail] Failed for payload: #{payload.inspect}"
      assert_equal "application/json", last_response.content_type, "[Should Fail] Failed for payload: #{payload.inspect}"
      assert_equal expected_error_body, JSON.parse(last_response.body), "[Should Fail] Failed for payload: #{payload.inspect}"
    end

    passthrough_batches.each do |payload|
       post "/", payload.to_json, { "CONTENT_TYPE" => "application/json" }
       assert last_response.ok?, "[Should Pass Through] Failed for payload: #{payload.inspect}"
       assert_equal "OK", last_response.body, "[Should Pass Through] Failed for payload: #{payload.inspect}"
       assert_nil @mock_app.last_env[JSON_RPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY], "[Should Pass Through] Failed for payload: #{payload.inspect}"
    end
  end
end
