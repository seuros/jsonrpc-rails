# jsonrpc-rails

[![Gem Version](https://badge.fury.io/rb/jsonrpc-rails.svg)](https://badge.fury.io/rb/jsonrpc-rails)

**jsonrpc-rails** is a Railtie-based gem that brings JSON-RPC 2.0 support to your Rails application.
It integrates into Rails, allowing you to render JSON-RPC responses and validate incoming requests.

## Features

- **Rails Integration:** Easily integrate JSON-RPC 2.0 support via a Rails Railtie.
- **Custom Renderer:** Render responses with `render jsonrpc:`, automatically wrapping data in the JSON-RPC 2.0 envelope.
- **Error Handling:** Built-in support for both success and error responses according to the JSON-RPC 2.0 specification.
- **Request Validation:** Includes middleware (`JSONRPC_Rails::Middleware::Validator`) to strictly validate incoming JSON-RPC 2.0 requests (single and batch) against the specification structure.
- **Rails 8+ Compatibility:** Designed specifically for Rails 8 and later versions.

## Installation

Add the following line to your application's Gemfile:

```ruby
gem 'jsonrpc-rails'
```

Then run:

```bash
bundle install
```

Or install it directly via:

```bash
gem install jsonrpc-rails
```

## Usage

### Rendering Responses

Once installed, **jsonrpc-rails** registers a custom renderer with Rails. 

Enable validation where you need it

Add this to config/application.rb (or an environment file):
```ruby
# Validate only the JSON‑RPC endpoints you expose
config.jsonrpc_rails.validated_paths = [
"/rpc",                    # exact string
%r{\A/api/v\d+/rpc\z},     # regexp
->(p) { p.start_with? "/rpc/private" } # lambda / proc
]
```

Leave the array empty (default) and the middleware is effectively off.
Use [/.*\z/] if you really want it on everywhere.

In your controllers, you can render JSON-RPC responses like so:

```ruby
class TestController < ApplicationController
  def index
    # Render a successful JSON-RPC response
    render jsonrpc: { message: "Hello from JSON-RPC!" }, id: 1
  end

  def error_code
    # Render an error using a numeric code (uses default message for standard codes)
    render jsonrpc: {}, error: -32600, id: 5 # Invalid Request
  end

  def error_code_override
    # Render an error using a numeric code, overriding the message and adding data
    render jsonrpc: { message: "Specific invalid request", data: { field: "xyz" } }, error: -32600, id: 6
  end
end
```

The renderer wraps your data in the JSON-RPC 2.0 envelope:
- **Success Response:**
  ```json
  { "jsonrpc": "2.0", "result": { }, "id": 1 }
  ```
- **Error Response (using numeric code):**
  ```json
  { "jsonrpc": "2.0", "error": { "code": -32600, "message": "Invalid Request" }, "id": 5 }
  ```
- **Error Response (using numeric code with override):**
  ```json
  { "jsonrpc": "2.0", "error": { "code": -32600, "message": "Specific invalid request", "data": { "field": "xyz" } }, "id": 6 }
  ```

To render an error response, pass a numeric error code or a predefined Symbol to the `error:` option:
- **Numeric Code:** Pass the integer code directly (e.g., `error: -32600`). If the code is a standard JSON-RPC error code (`-32700`, `-32600` to `-32603`, `-32000`), a default message will be used (as shown in the `error_code` example).
- **Symbol:** Pass a symbol corresponding to a standard error (e.g., `error: :invalid_request`). The gem will look up the code and default message. (See `lib/json_rpc/json_rpc_error.rb` for available symbols).

You can override the default `message` or add `data` for either method by providing them in the main hash passed to `render jsonrpc:`, as demonstrated in the `error_code_override` example.

### Handling Requests

The gem automatically inserts `JSONRPC_Rails::Middleware::Validator` into your application's middleware stack. This middleware performs the following actions for incoming **POST** requests with `Content-Type: application/json`:

1.  **Parses** the JSON body. Returns a JSON-RPC `Parse error (-32700)` if parsing fails.
2.  **Validates** the structure against the JSON-RPC 2.0 specification (single or batch). It performs strict validation, ensuring `jsonrpc: "2.0"`, a string `method`, optional `params` (array/object), optional `id` (string/number/null), and **no extraneous keys**. Returns a JSON-RPC `Invalid Request (-32600)` error if validation fails. **Note:** For batch requests, if *any* individual request within the batch is structurally invalid, the entire batch is rejected with a single `Invalid Request (-32600)` error.
3.  **Stores** the validated, parsed payload (the original Ruby Hash or Array) in `request.env[:jsonrpc]` if validation succeeds.
4.  **Passes** the request to the next middleware or your controller action.

In your controller action, you can access the validated payload like this:

```ruby
# app/controllers/my_api_controller.rb
class MyApiController < ApplicationController
  # POST /rpc
  def process
    if jsonrpc_batch?
      # ── batch ───────────────────────────────────────────────────────────────
      responses = jsonrpc.filter_map { |req| handle_single_request(req) } # strip nil (notifications)

      if responses.empty?
        head :no_content
      else
        # respond with an array of hashes; to_h keeps the structs internal
        render json: responses.map(&:to_h), status: :ok
      end
    else
      # ── single ──────────────────────────────────────────────────────────────
      response = handle_single_request(jsonrpc)

      if response # request (has id)
        render jsonrpc:  response.result,
               id:       response.id,
               error:    response.error
      else        # notification
        head :no_content
      end
    end
  end

  private

  # Map one JSON_RPC::Request|Notification → Response|nil
  def handle_single_request(req)
    # Notifications have id == nil.  Return nil = no response.
    return nil if req.id.nil?

    result_or_error =
            case req.method
            when "add"
              add(*Array(req.params))
            when "subtract"
              subtract(*Array(req.params))
            else
              method_not_found
            end

    build_response(req.id, result_or_error)
  end

  # ───────────────── helper methods ──────────────────────────────────────────
  def add(*nums)
    return invalid_params unless nums.all? { |n| n.is_a?(Numeric) }
    nums.sum
  end

  def subtract(a = nil, b = nil)
    return invalid_params unless a.is_a?(Numeric) && b.is_a?(Numeric)
    a - b
  end

  def invalid_params
    JSON_RPC::JsonRpcError.build(:invalid_params)
  end

  def method_not_found
    JSON_RPC::JsonRpcError.build(:method_not_found)
  end

  def build_response(id, outcome)
    if outcome.is_a?(JSON_RPC::JsonRpcError)
      JSON_RPC::Response.new(id: id, error: outcome)
    else
      JSON_RPC::Response.new(id: id, result: outcome)
    end
  end
end
```

## Testing

A dummy Rails application is included within the gem (located in `test/dummy`) to facilitate testing. You can run the tests from the **project root directory** by executing:

```bash
bundle exec rake test
```

The provided tests ensure that the renderer, middleware, and basic integration function correctly.

## Contributing

Contributions are very welcome! Feel free to fork the repository, make improvements, and submit pull requests. For bug reports or feature requests, please open an issue on GitHub:

[https://github.com/seuros/jsonrpc-rails](https://github.com/seuros/jsonrpc-rails)

## License

This gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

Happy coding with JSON-RPC in Rails!
