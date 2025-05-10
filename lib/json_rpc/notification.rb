# frozen_string_literal: true

module JSON_RPC
  # Represents a JSON-RPC notification.
  Notification = Data.define(:method, :params) do
    # Initializes a new Notification.
    #
    # @param method [String] The method name.
    # @param params [Hash, Array, nil] The parameters (optional). Structured value.
    def initialize(method:, params: nil)
      # Basic validation could be added here if needed, e.g., method is a non-empty string.
      super
    end

    def self.from_h(h)
      new(method: h["method"], params: h["params"])
    end

    # Returns a hash representation of the notification, ready for JSON serialization.
    #
    # @return [Hash] The hash representation.
    def to_h
      hash = {
        "jsonrpc" => "2.0",
        method: method
      }
      # Include params only if it's not nil, as per JSON-RPC spec
      hash[:params] = params unless params.nil?
      hash
    end

    def as_json(*) = to_h
  end
end
