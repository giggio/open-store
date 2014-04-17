Product         = require '../models/product'
User            = require '../models/user'
Store           = require '../models/store'
_               = require 'underscore'
AccessDenied    = require '../errors/accessDenied'
values          = require '../helpers/values'
RouteFunctions  = require './routeFunctions'
Q               = require 'q'

module.exports = class AdminRoutes
  constructor: (@env) ->
    @_authSiteAdmin 'siteAdmin', 'storesForAuthorization', 'updateStoreFlyerAuthorization', 'stores'
  _.extend @::, RouteFunctions::

  handleError: @::_handleError.partial 'siteAdmin'

  siteAdmin: (req, res) ->
    req.user.toSimpleUser (user) ->
      res.render 'siteAdmin/siteAdmin', user: user

  storesForAuthorization: (req, res) ->
    isFlyerAuthorized = switch req.params.isFlyerAuthorized
      when undefined then undefined
      when 'true' then true
      else false
    Store.findSimpleByFlyerAuthorization isFlyerAuthorized, (err, stores) =>
      return @handleError req, res, err if err?
      res.json stores

  updateStoreFlyerAuthorization: (req, res) ->
    Store.findById req.params._id, (err, store) ->
      return @handleError req, res, err if err?
      isFlyerAuthorized = req.params.isFlyerAuthorized is 'true'
      store.isFlyerAuthorized = isFlyerAuthorized
      store.save()
      store.sendMailAfterFlyerAuthorization req.user, (err) ->
        return @handleError req, res, err if err?
        res.json 200

  stores: (req, res) ->
    Q.ninvoke Store, 'find'
    .then (stores) ->
      for store in stores
        do (store) ->
          simple = store.toSimple()
          Q.ninvoke User, "findAdminsFor", store
          .then (users) ->
            user = users[0]
            simple.ownerName = user?.name
            simple.ownerEmail = user?.email
            simple
    .then (simpleStoresPromises) -> Q.all simpleStoresPromises
    .then (simpleStores) ->
      Store.ordersPerStore()
      .then (ordersSummariesPerStore) ->
        for orderSummary in ordersSummariesPerStore
          store = _.find simpleStores, (s) -> s._id.equals orderSummary._id
          store.numberOfOrders = orderSummary.value
        undefined
        Store.productsPerStore()
        .then (productsPerStore) ->
          for product in productsPerStore
            store = _.find simpleStores, (s) -> s.slug is product._id
            store.numberOfProducts = product.value
      .then -> res.json simpleStores
    .catch (err) => @handleError req, res, err
