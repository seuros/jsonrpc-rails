# frozen_string_literal: true

require "test_helper"

module JSON_RPC
  class ResponseTest < ActiveSupport::TestCase
    test "initializes with result" do
      response = Response.new(id: 1, result: "success")
      assert_equal 1, response.id
      assert_equal "success", response.result
      assert_nil response.error
    end

    test "initializes with error as JsonRpcError object" do
      error = JsonRpcError.new(:internal_error, message: "Something went wrong")
      response = Response.new(id: 1, error: error)

      assert_equal 1, response.id
      assert_nil response.result
      assert_equal({ code: -32_603, message: "Something went wrong" }, response.error)
    end

    test "initializes with error as symbol" do
      response = Response.new(id: 1, error: :method_not_found)

      assert_equal 1, response.id
      assert_nil response.result
      assert_equal({ code: -32_601, message: "Method not found" }, response.error)
    end

    test "initializes with error as hash" do
      error_hash = { code: -32_603, message: "Custom error", data: { details: "test" } }
      response = Response.new(id: 1, error: error_hash)

      assert_equal 1, response.id
      assert_nil response.result
      assert_equal error_hash, response.error
    end

    test "handles unexpected error format gracefully" do
      response = Response.new(id: 1, error: "invalid error format")

      assert_equal 1, response.id
      assert_nil response.result
      assert_equal({ code: -32_603, message: "Invalid error format provided" }, response.error)
    end

    test "raises error when both result and error are provided" do
      assert_raises(ArgumentError) do
        Response.new(id: 1, result: "success", error: :internal_error)
      end
    end

    test "raises error when neither result nor error provided for non-null id" do
      assert_raises(ArgumentError) do
        Response.new(id: 1)
      end
    end

    test "to_h includes error when present" do
      response = Response.new(id: 1, error: :internal_error)
      hash = response.to_h

      assert_equal "2.0", hash["jsonrpc"]
      assert_equal 1, hash[:id]
      assert_equal({ code: -32_603, message: "Internal error" }, hash[:error])
      assert_nil hash[:result]
    end

    test "to_h includes result when successful" do
      response = Response.new(id: 1, result: { data: "test" })
      hash = response.to_h

      assert_equal "2.0", hash["jsonrpc"]
      assert_equal 1, hash[:id]
      assert_equal({ data: "test" }, hash[:result])
      assert_nil hash[:error]
    end

    test "to_h includes null result when successful with nil result" do
      response = Response.new(id: 1, result: nil)
      hash = response.to_h

      assert_equal "2.0", hash["jsonrpc"]
      assert_equal 1, hash[:id]
      assert_nil hash[:result]
      assert_key hash, :result
      assert_nil hash[:error]
    end

    test "from_h creates response from hash" do
      hash = { "id" => 42, "result" => "success" }
      response = Response.from_h(hash)

      assert_equal 42, response.id
      assert_equal "success", response.result
      assert_nil response.error
    end

    private

    def assert_key(hash, key)
      assert hash.key?(key), "Expected hash to have key #{key.inspect}"
    end
  end
end
