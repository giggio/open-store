define [
  'backboneConfig'
  './evaluation'
], (Backbone, Evaluation) ->
  class Evaluations extends Backbone.Collection
    initialize: (models, opt) ->
      @orderId = opt.orderId
    model: Evaluation
    url: -> "/api/account/orders/#{@orderId}/evaluation"
