# frozen_string_literal: true

require "test_helper"
require "rack/lint"
require "jsonrpc_rails/middleware/validator"

module JSONRPC_Rails
  module Middleware
    class ValidatorRackLintTest < ActionDispatch::IntegrationTest
      class MockApp
        def initialize
          @calls = []
        end

        def call(env)
          @calls << env.dup
          [ 200, { "content-type" => "application/json" }, [ '{"result": "ok"}' ] ]
        end

        attr_reader :calls

        def last_env
          @calls.last
        end
      end

      class InputReadingApp
        def initialize
          @calls = []
        end

        def call(env)
          # This app reads rack.input to simulate downstream middleware behavior
          body = env["rack.input"].read
          env["rack.input"].rewind  # This should work after our fix
          @calls << { body: body, env: env.dup }
          [ 200, { "content-type" => "application/json" }, [ '{"result": "ok"}' ] ]
        end

        attr_reader :calls
      end

      def setup
        @mock_app = MockApp.new
        @validator = JSONRPC_Rails::Middleware::Validator.new(@mock_app, [ %r{\A/} ])
        @lint_wrapped = Rack::Lint.new(@validator)
      end

      def test_rack_lint_wrapper_compatibility
        # This test specifically checks that the validator works with Rack::Lint
        # which wraps env["rack.input"] in a Rack::Lint::Wrapper::InputWrapper
        # that doesn't implement the rewind method

        env = rack_env_for_json_post('{"jsonrpc": "2.0", "method": "test", "id": 1}')

        # This should not raise NoMethodError: undefined method 'rewind'
        assert_nothing_raised do
          status, _headers, _body = @lint_wrapped.call(env)
          assert_equal 200, status
        end

        # Verify the request was processed correctly
        assert_not_nil @mock_app.last_env
        assert_not_nil @mock_app.last_env[:jsonrpc]
        assert_equal "test", @mock_app.last_env[:jsonrpc].method
        assert_equal 1, @mock_app.last_env[:jsonrpc].id
      end

      def test_downstream_can_read_input_after_validation_with_lint
        # Test that downstream middleware can still read rack.input after
        # our validator has consumed and replaced it, even with Rack::Lint

        input_reader = InputReadingApp.new
        validator = JSONRPC_Rails::Middleware::Validator.new(input_reader, [ %r{\A/} ])
        lint_wrapped = Rack::Lint.new(validator)

        json_payload = '{"jsonrpc": "2.0", "method": "downstream_test", "id": 42}'
        env = rack_env_for_json_post(json_payload)

        # This should work without errors
        assert_nothing_raised do
          status, _headers, _body = lint_wrapped.call(env)
          assert_equal 200, status
        end

        # Verify downstream app received the correct body
        assert_equal 1, input_reader.calls.size
        call_data = input_reader.calls.first
        assert_equal json_payload, call_data[:body]

        # Verify the jsonrpc object was created correctly
        jsonrpc_obj = call_data[:env][:jsonrpc]
        assert_not_nil jsonrpc_obj
        assert_equal "downstream_test", jsonrpc_obj.method
        assert_equal 42, jsonrpc_obj.id
      end

      def test_invalid_json_handling_with_rack_lint
        # Test that invalid JSON handling works correctly with Rack::Lint

        env = rack_env_for_json_post('{"invalid json":}')

        assert_nothing_raised do
          status, _headers, body = @lint_wrapped.call(env)
          assert_equal 400, status

          response_data = JSON.parse(body.to_enum.first)
          assert_equal(-32600, response_data["error"]["code"])
          assert_equal("Invalid Request", response_data["error"]["message"])
        end
      end

      def test_empty_body_handling_with_rack_lint
        # Test that empty body handling works with Rack::Lint

        env = rack_env_for_json_post("")

        assert_nothing_raised do
          status, _headers, _body = @lint_wrapped.call(env)
          assert_equal 400, status
        end
      end

      def test_large_payload_handling_with_rack_lint
        # Test that larger payloads work correctly (ensuring StringIO handles size properly)

        large_payload = {
          "jsonrpc" => "2.0",
          "method" => "process_large_data",
          "params" => {
            "data" => "x" * 10000,  # 10KB of data
            "metadata" => {
              "fields" => Array.new(100) { |i| "field_#{i}" }
            }
          },
          "id" => "large_test"
        }.to_json

        env = rack_env_for_json_post(large_payload)

        assert_nothing_raised do
          status, _headers, _body = @lint_wrapped.call(env)
          assert_equal 200, status
        end

        # Verify the large payload was processed correctly
        jsonrpc_obj = @mock_app.last_env[:jsonrpc]
        assert_equal "process_large_data", jsonrpc_obj.method
        assert_equal "large_test", jsonrpc_obj.id
        assert_equal 10000, jsonrpc_obj.params["data"].length
      end

      def test_batch_request_with_rack_lint
        # Test batch requests work with Rack::Lint

        batch_payload = [
          { "jsonrpc" => "2.0", "method" => "batch_test_1", "id" => 1 },
          { "jsonrpc" => "2.0", "method" => "batch_test_2", "id" => 2 },
          { "jsonrpc" => "2.0", "method" => "notification_test" }
        ].to_json

        env = rack_env_for_json_post(batch_payload)

        assert_nothing_raised do
          status, _headers, _body = @lint_wrapped.call(env)
          assert_equal 200, status
        end

        # Verify batch was processed correctly
        batch_objects = @mock_app.last_env[:jsonrpc]
        assert_equal 3, batch_objects.length
        assert_equal "batch_test_1", batch_objects[0].method
        assert_equal "batch_test_2", batch_objects[1].method
        assert_equal "notification_test", batch_objects[2].method
      end

      private

      def rack_env_for_json_post(json_body, path = "/")
        {
          "REQUEST_METHOD" => "POST",
          "PATH_INFO" => path,
          "QUERY_STRING" => "",
          "SCRIPT_NAME" => "",
          "CONTENT_TYPE" => "application/json",
          "CONTENT_LENGTH" => json_body.bytesize.to_s,
          "SERVER_PROTOCOL" => "HTTP/1.1",
          "rack.input" => StringIO.new(json_body.dup.force_encoding("ASCII-8BIT")),
          "rack.url_scheme" => "http",
          "rack.version" => [ 1, 6 ],
          "rack.errors" => StringIO.new,
          "SERVER_NAME" => "localhost",
          "SERVER_PORT" => "80",
          "HTTP_HOST" => "localhost"
        }
      end
    end
  end
end
