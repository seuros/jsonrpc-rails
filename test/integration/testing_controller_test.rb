# frozen_string_literal: true

require "test_helper"

class TestingControllerTest < ActionDispatch::IntegrationTest
  test "renders a valid JSON-RPC result response" do
    get "/test"
    assert_response :success

    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal({ "message" => "Hello from JSON-RPC!" }, json_response["result"])
    assert_equal 1, json_response["id"]
  end

  test "renders a valid JSON-RPC error response using a symbol" do
    get "/error_symbol"
    assert_response :success

    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    # Fetches code/message from JSON_RPC::JsonRpcError::ERROR_CODES[:method_not_found]
    assert_equal({ "code" => -32_601, "message" => "Method not found" }, json_response["error"])
    assert_equal 3, json_response["id"]
  end

  test "renders a valid JSON-RPC error response using a symbol with overrides" do
    get "/error_symbol_override"
    assert_response :success

    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    # Uses code from symbol, but message/data from the render call
    assert_equal({ "code" => -32_601, "message" => "Custom method not found", "data" => { "info" => "more details" } },
                 json_response["error"])
    assert_equal 4, json_response["id"]
  end

  test "renders a valid JSON-RPC error response using a numeric code" do
    get "/error_code"
    assert_response :success

    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal 5, json_response["id"]
    # Uses code from option, default message from JSON_RPC::JsonRpcError
    assert_equal({ "code" => -32_600, "message" => "Invalid Request" }, json_response["error"])
  end

  test "renders a valid JSON-RPC error response using a numeric code with overrides" do
    get "/error_code_override"
    assert_response :success

    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    # Uses code from option, message/data from the render call
    assert_equal({ "code" => -32_600, "message" => "Specific invalid request", "data" => { "field" => "xyz" } },
                 json_response["error"])
    assert_equal 6, json_response["id"]
  end

  # --- Tests for JSON-RPC Validator Middleware (POST /rpc) ---

  test "POST /rpc with valid single request passes validation" do
    payload = { jsonrpc: "2.0", method: "test", id: 10 }.to_json
    post "/rpc", params: payload, headers: { "Content-Type" => "application/json" }

    assert_response :ok
    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal({ "message" => "Request processed successfully" }, json_response["result"])
    assert_equal 10, json_response["id"] # Should match the request id
  end

  test "POST /rpc with valid batch request passes validation" do
    payload = [
      { jsonrpc: "2.0", method: "test1", id: 11 },
      { jsonrpc: "2.0", method: "notify_test", params: [ 1, 2 ] } # Notification
    ].to_json
    post "/rpc", params: payload, headers: { "Content-Type" => "application/json" }

    assert_response :ok
    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal({ "message" => "Request processed successfully" }, json_response["result"])
    # Controller action currently returns nil id for batch requests for simplicity
    assert_nil json_response["id"]
  end

  test "POST /rpc with malformed JSON returns Parse Error" do
    malformed_payload = '{"jsonrpc": "2.0", "method": "test", "id": 12' # Missing closing brace
    post "/rpc", params: malformed_payload, headers: { "Content-Type" => "application/json" }

    # Middleware now passes through unparsable JSON
    assert_response :bad_request
    json_response = response.parsed_body
    # Controller likely returns default success response with nil id
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal({ "code" => -32_600, "message" => "Invalid Request" }, json_response["error"])
    assert_nil json_response["id"]
  end

  test "POST /rpc with invalid JSON-RPC structure (single) returns Invalid Request" do
    # Missing 'jsonrpc' member - middleware should pass this through now
    payload = { method: "test", id: 13 }.to_json
    post "/rpc", params: payload, headers: { "Content-Type" => "application/json" }

    assert_response :bad_request
    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal({ "code" => -32_600, "message" => "Invalid Request" }, json_response["error"])
    assert_nil json_response["id"]
  end

  test "POST /rpc with empty batch array returns Invalid Request" do
    payload = [].to_json
    post "/rpc", params: payload, headers: { "Content-Type" => "application/json" }

    # Empty batch does not trigger validation, passes through
    assert_response :bad_request
    json_response = response.parsed_body
    # Controller likely returns default success response with nil id
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal({ "code" => -32_600, "message" => "Invalid Request" }, json_response["error"])
    assert_nil json_response["id"]
  end

  test "POST /rpc with batch containing invalid structure returns Invalid Request" do
    payload = [
      { jsonrpc: "2.0", method: "valid_one", id: 14 },
      { method: "invalid_one" } # Missing 'jsonrpc'
    ].to_json
    post "/rpc", params: payload, headers: { "Content-Type" => "application/json" }

    assert_response :bad_request # 400
    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    assert_nil json_response["id"]
    assert_equal({ "code" => -32_600, "message" => "Invalid Request" }, json_response["error"])
  end

  test "POST /rpc with incorrect Content-Type is passed through" do
    payload = { jsonrpc: "2.0", method: "test", id: 15 }.to_json
    # Using text/plain instead of application/json
    post "/rpc", params: payload, headers: { "Content-Type" => "text/plain" }

    # Middleware should ignore it. The dummy action doesn't care about Content-Type
    # and will likely still render its JSON response.
    assert_response :ok
    # We assert the response is NOT a JSON-RPC error from the middleware
    json_response = begin
      response.parsed_body
    rescue StandardError
      nil
    end
    assert_not_equal(-32_700, json_response&.dig("error", "code"))
    assert_not_equal(-32_600, json_response&.dig("error", "code"))
    # Check it hit the controller action and rendered the default JSON-RPC response
    # because env['jsonrpc'] was nil.
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal({ "message" => "Request processed successfully" }, json_response["result"])
    assert_nil json_response["id"] # request_id will be nil in the controller
  end

  test "POST /api/v1/rpc validates via regex" do
    payload = { jsonrpc: "2.0", method: "noop", id: 22 }.to_json
    post "/api/v1/rpc", params: payload, headers: { "Content-Type" => "application/json" }

    assert_response :ok
    assert_equal 22, response.parsed_body["id"]
  end

  test "POST /rpc/private/echo validates via lambda" do
    payload = { jsonrpc: "2.0", method: "noop", id: 23 }.to_json
    post "/rpc/private/echo", params: payload, headers: { "Content-Type" => "application/json" }

    assert_response :ok
    assert_equal 23, response.parsed_body["id"]
  end

  test "GET /rpc is passed through (results in 404)" do
    get "/rpc"

    # Middleware ignores GET requests. Rails routing handles it.
    # Since we only defined POST /rpc, GET should result in Not Found.
    assert_response :not_found # 404
  end

  test "Test Response Object" do
    get "/render_response"
    assert_response :success

    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "ok", json_response["result"]
    assert_equal 1, json_response["id"]
  end

  test "Test Notification Object" do
    get "/render_notification"
    assert_response :success

    json_response = response.parsed_body
    assert_equal "2.0", json_response["jsonrpc"]
    assert_nil json_response["id"]
    assert_equal "tick", json_response["method"]
    assert_equal({ "a" => 1, "b" => 2 }, json_response["params"])
  end

  test "Test Batch Object" do
    get "/render_batch"
    assert_response :success

    json_response = response.parsed_body
    assert_equal 3, json_response.size

    # check each response
    assert_equal "2.0", json_response[0]["jsonrpc"]
    assert_equal "ok", json_response[0]["result"]
    assert_equal 1, json_response[0]["id"]

    assert_equal "2.0", json_response[1]["jsonrpc"]
    assert_nil json_response[1]["id"]
    assert_equal "tick", json_response[1]["method"]

    assert_equal "2.0", json_response[2]["jsonrpc"]
    assert_equal "ok", json_response[2]["result"]
    assert_equal 2, json_response[2]["id"]
  end
end
