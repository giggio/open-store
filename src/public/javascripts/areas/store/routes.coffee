define [
  'jquery'
  './views/store'
  './views/product'
  './views/cart'
],($, StoreView, ProductView, CartView) ->
  home: ->
    storeView = new StoreView el:$ "#app-container"
    storeView.render()
  product: (slug) ->
    storeSlug = location.pathname.match(/^\/([^#]*)/)[1]
    productView = new ProductView el:$ '#app-container'
    productView.render slug
  cart: ->
    cartView = new CartView el:$ '#app-container'
    cartView.render()