Rails.application.routes.draw do
  get "/test", to: "testing#index"
  get "/error", to: "testing#error"
end
