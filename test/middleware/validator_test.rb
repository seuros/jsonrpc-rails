# frozen_string_literal: true

require "test_helper"
require "jsonrpc_rails/middleware/validator"

module JSONRPC_Rails
  module Middleware
    class ValidatorTest < ActionDispatch::IntegrationTest
      class MockApp
        def call(env)
          @last_env = env
          [ 200, { "Content-Type" => "text/plain" }, [ "OK" ] ]
        end

        attr_reader :last_env
      end

      def setup
        mock = MockApp.new
        @mock_app = mock
        @app = Rack::Builder.new do
          use JSONRPC_Rails::Middleware::Validator, %r{\A/}
          run mock
        end.to_app
      end

      def raw_post(path, json, headers = {})
        post path,
             params: json,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "ACCEPT" => "application/json"
             }.merge(headers)
      end

      def test_get_request_passes_through
        get "/"
        assert_response :success
        assert_nil @mock_app.last_env[JSONRPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
      end

      def test_post_without_json_content_type_passes_through
        post "/", params: { foo: "bar" }.to_json, headers: { "CONTENT_TYPE" => "text/plain" }
        assert_response :success
        assert_nil @mock_app.last_env[JSONRPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
      end

      def test_valid_single_request_passes_through
        payload = { "jsonrpc" => "2.0", id: 1, method: "subtract", params: [ 42, 23 ] }
        raw_post "/", payload.to_json

        assert_response :success
        env_payload = @mock_app.last_env[JSONRPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
        assert_equal payload, env_payload.to_h
      end

      def test_single_request_invalid_structure
        bad_payloads = [
          { "jsonrpc" => "1.0", "method" => "foo", "id" => 1 },
          { "jsonrpc" => "2.0", "id" => 1 },
          { "jsonrpc" => "2.0", "method" => 123, "id" => 1 },
          { "jsonrpc" => "2.0", "method" => "foo", "params" => 123, "id" => 1 },
          { "jsonrpc" => "2.0", "method" => "foo", "id" => {} }
        ]

        error = { "jsonrpc" => "2.0", "error" => { "code" => -32_600, "message" => "Invalid Request" }, "id" => nil }

        bad_payloads.each do |bad|
          raw_post "/", bad.to_json
          assert_response :bad_request
          assert_equal error, JSON.parse(response.body), "Failed for: #{bad.inspect}"
        end
      end

      def test_batch_with_invalid_element_structure
        batches = [
          [ { "jsonrpc" => "2.0", "method" => "valid" }, { "method" => "invalid" } ],
          [ { "jsonrpc" => "2.0", "method" => "valid" }, { "jsonrpc" => "1.0", "method" => "invalid", "id" => 2 } ],
          [ { "jsonrpc" => "2.0", "method" => "valid" }, { "jsonrpc" => "2.0", "id" => 3 } ],
          [ { "jsonrpc" => "2.0", "method" => "valid" }, { "jsonrpc" => "2.0", "method" => 123, "id" => 4 } ],
          [ { "jsonrpc" => "2.0", "method" => "valid" },
           { "jsonrpc" => "2.0", "method" => "invalid", "params" => 1, "id" => 5 } ],
          [ { "jsonrpc" => "2.0", "method" => "valid" }, { "jsonrpc" => "2.0", "method" => "invalid", "id" => {} } ],
          [ { "jsonrpc" => "2.0", "method" => "valid" },
           { "jsonrpc" => "2.0", "method" => "invalid", "id" => 6, "extra" => true } ]
        ]

        error = { "jsonrpc" => "2.0", "error" => { "code" => -32_600, "message" => "Invalid Request" }, "id" => nil }

        batches.each do |batch|
          raw_post "/", batch.to_json
          assert_response :bad_request
          assert_equal error, JSON.parse(response.body), "Failed for batch: #{batch.inspect}"
        end
      end

      def test_valid_batch_request
        payload = [
          { "jsonrpc" => "2.0", method: "notify_sum", params: [ 1, 2, 4 ] },
          { "jsonrpc" => "2.0", id: "abc", method: "subtract", params: [ 42, 23 ] }
        ]
        raw_post "/", payload.to_json
        assert_response :success
        stored = @mock_app.last_env[JSONRPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
        assert_equal payload, stored.map(&:to_h)
      end

      def test_empty_batch_request_returns_error
        raw_post "/", [].to_json
        assert_response :bad_request
        assert_equal({ "jsonrpc" => "2.0", "id" => nil, "error" => { "code" => -32_600, "message" => "Invalid Request" } },
                     JSON.parse(response.body))
      end

      def test_matchers_work
        [ [ "/rpc", [ "/rpc" ] ],
         [ "/api/v2/rpc", [ %r{\A/api/v\d+/rpc\z} ] ],
         [ "/rpc/private/foo", [ ->(p) { p.start_with?("/rpc/private") } ] ] ].each do |path, matcher|
          @app = JSONRPC_Rails::Middleware::Validator.new(@mock_app, matcher)
          post path, params: { jsonrpc: "2.0", method: "ping" }.to_json,
                     headers: { "CONTENT_TYPE" => "application/json" }
          assert_response :success
        end
      end
    end
  end
end
