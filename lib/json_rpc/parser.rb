# frozen_string_literal: true

module JSON_RPC
  module Parser
    # Convert one JSON-RPC hash into a typed object.
    def self.object_from_hash(h)
      # Order matters: responses have id *plus* result/error,
      # so check for those keys first.
      if h.key?("result") || h.key?("error")
        Response.from_h(h)
      elsif h.key?("id")
        Request.from_h(h)          # request (id may be nil)
      else
        Notification.from_h(h)     # no id ⇒ notification
      end
    end

    # Convert raw JSON string into typed object(s).
    def self.array_from_json(json)
      raw = ActiveSupport::JSON.decode(json)
      case raw
      when Hash  then object_from_hash(raw)
      when Array then raw.map { |h| object_from_hash(h) }
      else            raw # let validator scream later
      end
    end
  end
end
