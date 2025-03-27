require "test_helper"

class TestingControllerTest < ActionDispatch::IntegrationTest
  test "renders a valid JSON-RPC result response" do
    get "/test"
    assert_response :success

    json_response = JSON.parse(@response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal({ "message" => "Hello from JSON-RPC!" }, json_response["result"])
    assert_equal 1, json_response["id"]
  end

  test "renders a valid JSON-RPC error response" do
    get "/error"
    assert_response :success

    json_response = JSON.parse(@response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal({ "code" => -32603, "message" => "Internal error" }, json_response["error"])
    assert_equal 2, json_response["id"]
  end
end
