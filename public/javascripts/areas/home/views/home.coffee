define [
  'jquery'
  'backbone'
  'handlebars'
  '../models/productsHome'
  'text!./templates/home.html'
], ($, Backbone, Handlebars, ProductsHome, homeTemplate) ->
  class Home extends Backbone.View
    template: homeTemplate
    initialize: (opt) ->
      @products = opt.products
    render: ->
      @$el.empty()
      productsHome = new ProductsHome()
      productsHome.reset @products
      context = Handlebars.compile @template
      @$el.html context productsHome: productsHome.toJSON()