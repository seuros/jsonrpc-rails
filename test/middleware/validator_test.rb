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
        @app = build_app
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

      def test_strict_content_type_rejects_non_json_and_missing_content_types
        @app = build_app(require_json_content_type: true)

        [ "text/plain", nil ].each do |content_type|
          headers = {}
          headers["CONTENT_TYPE"] = content_type if content_type
          post "/", params: '{"jsonrpc":"2.0","method":"ping"}', headers: headers

          assert_response :unsupported_media_type
          assert_nil @mock_app.last_env
          assert_equal(-32_000, response.parsed_body.dig("error", "code"))
          assert_equal "Unsupported Media Type: Content-Type must be application/json",
                       response.parsed_body.dig("error", "message")
        end
      end

      def test_strict_content_type_rejects_json_subtypes
        @app = build_app(require_json_content_type: true)

        raw_post "/", '{"jsonrpc":"2.0","method":"ping"}',
                 "CONTENT_TYPE" => "application/json-patch+json"

        assert_response :unsupported_media_type
        assert_nil @mock_app.last_env
        assert_equal(-32_000, response.parsed_body.dig("error", "code"))
      end

      def test_json_content_type_allows_parameters_but_not_prefixed_subtypes
        payload = { "jsonrpc" => "2.0", "method" => "ping" }.to_json

        raw_post "/", payload, "CONTENT_TYPE" => "application/json; charset=utf-8"
        assert_response :success
        assert_instance_of JSON_RPC::Notification, @mock_app.last_env[:jsonrpc]

        raw_post "/", payload, "CONTENT_TYPE" => "application/json-patch+json"
        assert_response :success
        assert_nil @mock_app.last_env[:jsonrpc]
      end

      def test_valid_single_request_passes_through
        payload = { "jsonrpc" => "2.0", id: 1, method: "subtract", params: [ 42, 23 ] }
        raw_post "/", payload.to_json

        assert_response :success
        env_payload = @mock_app.last_env[JSONRPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
        assert_equal payload, env_payload.to_h
      end

      def test_request_with_null_id_passes_through_as_a_request
        payload = { "jsonrpc" => "2.0", "id" => nil, "method" => "ping" }
        raw_post "/", payload.to_json

        assert_response :success
        env_payload = @mock_app.last_env[JSONRPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
        assert_instance_of JSON_RPC::Request, env_payload
        assert_nil env_payload.id
      end

      def test_request_and_response_with_fractional_ids_pass_through
        request_payload = { "jsonrpc" => "2.0", "id" => 1.5, "method" => "ping" }
        raw_post "/", request_payload.to_json

        assert_response :success
        assert_equal 1.5, @mock_app.last_env[:jsonrpc].id

        response_payload = { "jsonrpc" => "2.0", "id" => 2.5, "result" => true }
        raw_post "/", response_payload.to_json

        assert_response :success
        assert_equal 2.5, @mock_app.last_env[:jsonrpc].id
      end

      def test_valid_result_and_error_responses_pass_through
        payloads = [
          { "jsonrpc" => "2.0", "id" => 1, "result" => nil },
          {
            "jsonrpc" => "2.0",
            "id" => nil,
            "error" => { "code" => -32_601, "message" => "Method not found", "data" => { "method" => "missing" } }
          }
        ]

        payloads.each do |payload|
          raw_post "/", payload.to_json

          assert_response :success
          env_payload = @mock_app.last_env[JSONRPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
          assert_instance_of JSON_RPC::Response, env_payload
          assert_equal payload, env_payload.to_h.deep_stringify_keys
        end
      end

      def test_extension_members_are_accepted_but_conflicting_envelope_members_are_rejected
        payloads = [
          { "jsonrpc" => "2.0", "id" => 1, "method" => "ping", "traceId" => "request-1" },
          { "jsonrpc" => "2.0", "method" => "notify", "traceId" => "notification-1" },
          { "jsonrpc" => "2.0", "id" => 2, "result" => {}, "traceId" => "response-1" },
          {
            "jsonrpc" => "2.0",
            "id" => 3,
            "error" => { "code" => -32_000, "message" => "failed", "traceId" => "error-1" },
            "traceId" => "response-2"
          }
        ]

        payloads.each do |payload|
          raw_post "/", payload.to_json
          assert_response :success
        end

        conflicting = { "jsonrpc" => "2.0", "id" => 4, "method" => "ping", "result" => {} }
        raw_post "/", conflicting.to_json
        assert_response :bad_request
      end

      def test_invalid_response_structures_return_invalid_request
        payloads = [
          { "jsonrpc" => "2.0", "result" => true },
          { "jsonrpc" => "2.0", "id" => 1, "result" => true, "error" => { "code" => -1, "message" => "bad" } },
          { "jsonrpc" => "2.0", "id" => 1, "error" => { "code" => "-1", "message" => "bad" } },
          { "jsonrpc" => "2.0", "id" => 1, "error" => { "code" => -1, "message" => 123 } }
        ]

        payloads.each do |payload|
          raw_post "/", payload.to_json

          assert_response :bad_request
          assert_equal(-32_600, JSON.parse(response.body).dig("error", "code"))
        end
      end

      def test_single_request_invalid_structure
        bad_payloads = [
          { "jsonrpc" => "1.0", "method" => "foo", "id" => 1 },
          { "jsonrpc" => "2.0", "id" => 1 },
          { "jsonrpc" => "2.0", "method" => 123, "id" => 1 },
          { "jsonrpc" => "2.0", "method" => "foo", "params" => 123, "id" => 1 },
          { "jsonrpc" => "2.0", "method" => "foo", "id" => {} }
        ]

        bad_payloads.each do |bad|
          raw_post "/", bad.to_json
          assert_response :bad_request
          response_json = JSON.parse(response.body)
          expected_id = bad["id"] if bad["id"].is_a?(String) || bad["id"].is_a?(Numeric)
          if expected_id
            assert_equal expected_id, response_json["id"], "Failed to preserve ID for: #{bad.inspect}"
          else
            assert_nil response_json["id"], "Failed to clear invalid ID for: #{bad.inspect}"
          end
          assert_equal(-32_600, response_json["error"]["code"], "Failed for: #{bad.inspect}")
          assert_equal("Invalid Request", response_json["error"]["message"], "Failed for: #{bad.inspect}")
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
           { "jsonrpc" => "2.0", "method" => "invalid", "id" => 6, "result" => true } ]
        ]

        batches.each do |batch|
          raw_post "/", batch.to_json
          assert_response :bad_request
          response_json = JSON.parse(response.body)
          # For batch requests with invalid structure, the ID should be nil
          assert_nil response_json["id"], "Failed for batch: #{batch.inspect}"
          assert_equal(-32_600, response_json["error"]["code"], "Failed for batch: #{batch.inspect}")
          assert_equal("Invalid Request", response_json["error"]["message"], "Failed for batch: #{batch.inspect}")
        end
      end

      def test_valid_batch_request
        payload = [
          { "jsonrpc" => "2.0", method: "notify_sum", params: [ 1, 2, 4 ] },
          { "jsonrpc" => "2.0", id: "abc", method: "subtract", params: [ 42, 23 ] },
          { "jsonrpc" => "2.0", id: "result", result: 19 }
        ]
        raw_post "/", payload.to_json
        assert_response :success
        stored = @mock_app.last_env[JSONRPC_Rails::Middleware::Validator::ENV_PAYLOAD_KEY]
        assert_equal payload, stored.map(&:to_h)
      end

      def test_reject_batch_policy_rejects_an_otherwise_valid_batch
        @app = build_app(batch_policy: :reject)
        payload = [ { "jsonrpc" => "2.0", "id" => 1, "method" => "ping" } ]

        raw_post "/", payload.to_json

        assert_response :bad_request
        assert_nil @mock_app.last_env
        assert_equal(-32_600, JSON.parse(response.body).dig("error", "code"))
      end

      def test_invalid_batch_policy_is_rejected_at_initialization
        error = assert_raises(ArgumentError) do
          JSONRPC_Rails::Middleware::Validator.new(@mock_app, "/", batch_policy: :sometimes)
        end

        assert_match(/batch_policy/, error.message)
      end

      def test_callable_payload_validator_receives_raw_payload
        seen_payloads = []
        validator = lambda do |payload|
          seen_payloads << payload
          payload["method"] == "allowed"
        end
        @app = build_app(payload_validator: validator)

        raw_post "/", { "jsonrpc" => "2.0", "id" => 1, "method" => "blocked" }.to_json
        assert_response :bad_request

        allowed = { "jsonrpc" => "2.0", "id" => 2, "method" => "allowed" }
        raw_post "/", allowed.to_json
        assert_response :success
        assert_equal [ "blocked", "allowed" ], seen_payloads.map { |payload| payload["method"] }
      end

      def test_object_payload_validator_can_implement_valid
        validator = Object.new
        validator.define_singleton_method(:valid?) { |payload| payload["method"] == "allowed" }
        @app = build_app(payload_validator: validator)

        raw_post "/", { "jsonrpc" => "2.0", "method" => "blocked" }.to_json

        assert_response :bad_request
        assert_equal(-32_600, JSON.parse(response.body).dig("error", "code"))
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

      def test_error_preserves_request_id_for_invalid_single_request
        # Test with string ID
        payload = { "jsonrpc" => "1.0", "method" => "foo", "id" => "test-123" }
        raw_post "/", payload.to_json
        assert_response :bad_request
        response_json = JSON.parse(response.body)
        assert_equal "test-123", response_json["id"], "Error response should preserve string ID"
        assert_equal(-32_600, response_json["error"]["code"])

        # Test with numeric ID
        payload = { "jsonrpc" => "1.0", "method" => "foo", "id" => 456 }
        raw_post "/", payload.to_json
        assert_response :bad_request
        response_json = JSON.parse(response.body)
        assert_equal 456, response_json["id"], "Error response should preserve numeric ID"
        assert_equal(-32_600, response_json["error"]["code"])

        # Test with null ID
        payload = { "jsonrpc" => "1.0", "method" => "foo", "id" => nil }
        raw_post "/", payload.to_json
        assert_response :bad_request
        response_json = JSON.parse(response.body)
        assert_nil response_json["id"], "Error response should preserve null ID"
        assert_equal(-32_600, response_json["error"]["code"])

        # Test with missing ID (notification)
        payload = { "jsonrpc" => "1.0", "method" => "foo" }
        raw_post "/", payload.to_json
        assert_response :bad_request
        response_json = JSON.parse(response.body)
        assert_nil response_json["id"], "Error response should have null ID for notifications"
        assert_equal(-32_600, response_json["error"]["code"])
      end

      def test_malformed_json_returns_parse_error
        raw_post "/", '{"jsonrpc":"2.0","id":"malformed-123","method":"test",}'
        assert_response :bad_request
        response_json = JSON.parse(response.body)
        assert_nil response_json["id"]
        assert_equal(-32_700, response_json["error"]["code"])
        assert_equal "Parse error", response_json["error"]["message"]
      end

      def test_validator_processes_valid_requests
        # Test that valid requests are passed through with jsonrpc_params set
        payload = { "jsonrpc" => "2.0", "method" => "test", "id" => 123 }
        raw_post "/", payload.to_json

        assert_response :success
        assert_not_nil @mock_app.last_env[:jsonrpc]
        assert_equal "test", @mock_app.last_env[:jsonrpc].method
        assert_equal 123, @mock_app.last_env[:jsonrpc].id
      end

      def test_path_matching_with_string
        # Test that the validator only processes matching paths
        mock = MockApp.new
        @app = Rack::Builder.new do
          use JSONRPC_Rails::Middleware::Validator, "/api/rpc"
          run mock
        end.to_app

        # Should not process non-matching path
        raw_post "/other/path", '{"invalid":"json"}'
        assert_response :success
        assert_nil mock.last_env[:jsonrpc]

        # Should process matching path
        raw_post "/api/rpc", '{"invalid":"json"}'
        assert_response :bad_request
        response_json = JSON.parse(response.body)
        assert_nil response_json["id"]
        assert_equal(-32_600, response_json["error"]["code"])
      end

      private

      def build_app(**options)
        mock_app = @mock_app
        Rack::Builder.new do
          use JSONRPC_Rails::Middleware::Validator, %r{\A/}, **options
          run mock_app
        end.to_app
      end
    end
  end
end
