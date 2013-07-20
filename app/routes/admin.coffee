Product         = require '../models/product'
User            = require '../models/user'
Store           = require '../models/store'
Order           = require '../models/order'
_               = require 'underscore'
everyauth       = require 'everyauth'
AccessDenied    = require '../errors/accessDenied'
values          = require '../helpers/values'
correios        = require 'correios'
RouteFunctions  = require './routeFunctions'
FileUploader    = require '../helpers/amazonFileUploader'
async           = require 'async'

class Routes
  constructor: (@env) ->
    @_auth 'admin'
    @_authVerified 'adminStoreCreate'
    @_authSeller 'adminStoreCreate', 'adminStoreUpdate', 'adminProductUpdate', 'adminProductDelete', 'adminProductCreate', 'adminStoreUpdateSetAutoCalculateShippingOff', 'adminStoreUpdateSetAutoCalculateShippingOn', 'adminStoreUpdateSetPagseguroOff', 'adminStoreUpdateSetPagseguroOn', 'storeProduct', 'storeProducts', 'orders', 'order'
  
  admin: (req, res) ->
    return res.redirect 'notseller' unless req.user.isSeller
    req.user.populate 'stores', (err, user) ->
      res.render 'admin', stores: _.map(user.stores, (s) -> s.toSimple()), user: req.user.toSimpleUser()

  adminStoreCreate: (req, res) ->
    body = req.body
    name = body.name
    Store.nameExists name, (err, itExists) ->
      return res.json 409, error: user: "Loja já existe com esse nome." if itExists
      store = req.user.createStore()
      store.updateFromSimple body
      store.autoCalculateShipping = body.autoCalculateShipping
      if body.pagseguro
        store.pmtGateways.pagseguro = {} unless store.pmtGateways.pagseguro?
        store.pmtGateways.pagseguro.email = body.pagseguroEmail
        store.pmtGateways.pagseguro.token = body.pagseguroToken
      saveIf = (cb) =>
        if req.files?
          uploader = new FileUploader()
          createAction = (field) =>
            (cb) =>
              return cb() unless req.files[field]?
              onlineName = uploader.randomName "#{store.slug}/store", req.files[field].name
              uploader.upload onlineName, req.files[field], (err, fileUrl) ->
                return cb err if err?
                store[field] = fileUrl
                cb()
          actions = [ createAction('homePageImage'), createAction('banner'), createAction('flyer') ]
          async.parallel actions, cb
        else
          cb()
      saveIf (err) =>
        return res.json 400, error: uploadError: err if err?
        store.save (err) ->
          return res.json 400, error: saveError: err if err?
          req.user.save (err) ->
            if err?
              store.remove()
              return res.json 400, error: userSaveError: err
            res.json 201, store
  
  adminStoreUpdate: (req, res) ->
    Store.findById req.params.storeId, (err, store) ->
      dealWith err
      throw new AccessDenied() unless req.user.hasStore store
      checkIfNameCanBelongToStore = (cb) ->
        if store.name isnt req.body.name
          Store.nameExists req.body.name, (err, itExists) ->
            return res.json 409, error: user: "Loja já existe com esse nome." if itExists
            cb()
        else
          cb()
      checkIfNameCanBelongToStore =>
        store.updateFromSimple req.body
        saveIf = (cb) =>
          if req.files?
            uploader = new FileUploader()
            createAction = (field) =>
              (cb) =>
                return cb() unless req.files[field]?
                onlineName = uploader.randomName "#{store.slug}/store", req.files[field].name
                uploader.upload onlineName, req.files[field], (err, fileUrl) ->
                  return cb err if err?
                  deleteIf = (cbDelete) =>
                    if store[field]?
                      uploader.delete store[field], (err) => cbDelete()
                    else
                      cbDelete()
                  deleteIf =>
                    store[field] = fileUrl
                    cb()
            actions = [ createAction('homePageImage'), createAction('banner'), createAction('flyer') ]
            async.parallel actions, cb
          else
            cb()
        saveIf (err) =>
          return res.json 400, err if err?
          store.save (err) ->
            if err?
              return res.json 400
            res.send 200, store
  adminStoreUpdateSetAutoCalculateShippingOff: (req, res) -> @_adminStoreUpdateSetAutoCalculateShipping req, res, off
  adminStoreUpdateSetAutoCalculateShippingOn: (req, res) -> @_adminStoreUpdateSetAutoCalculateShipping req, res, on
  _adminStoreUpdateSetAutoCalculateShipping: (req, res, autoCalculateShipping) ->
    Store.findById req.params.storeId, (err, store) ->
      dealWith err
      throw new AccessDenied() unless req.user.hasStore store
      store.setAutoCalculateShipping autoCalculateShipping, (set) ->
        if set
          store.save (err) ->
            return res.json 400 if err?
            res.send 204
        else
          res.send 409
  adminStoreUpdateSetPagseguroOff: (req, res) -> @_adminStoreUpdateSetPagseguro req, res, off
  adminStoreUpdateSetPagseguroOn: (req, res) -> @_adminStoreUpdateSetPagseguro req, res, email: req.body.email, token: req.body.token
  _adminStoreUpdateSetPagseguro: (req, res, set) ->
    Store.findById req.params.storeId, (err, store) ->
      dealWith err
      throw new AccessDenied() unless req.user.hasStore store
      store.setPagseguro set
      store.save (err) ->
        return res.json 400 if err?
        res.send 204

  adminProductUpdate: (req, res) ->
    Product.findById req.params.productId, (err, product) ->
      dealWith err
      Store.findBySlug product.storeSlug, (err, store) ->
        dealWith err
        throw new AccessDenied() unless req.user.hasStore store
        product.updateFromSimpleProduct req.body
        saveProduct = =>
          product.save (err) ->
            res.send 204
        file = req.files?.picture
        if file?
          uploader = new FileUploader()
          onlineName = uploader.randomName "#{req.params.storeSlug}/products", file.name
          uploader.upload onlineName, file, (err, fileUrl) ->
            originalPicture = product.picture
            product.picture = fileUrl
            if originalPicture
              uploader.delete originalPicture, (err) ->
                saveProduct()
            else
              saveProduct()
        else
          saveProduct()
  
  adminProductDelete: (req, res) ->
    Product.findById req.params.productId, (err, product) ->
      dealWith err
      Store.findBySlug product.storeSlug, (err, store) ->
        dealWith err
        throw new AccessDenied() unless req.user.hasStore store
        product.remove (err) ->
          res.send 204
  
  adminProductCreate: (req, res) ->
    Store.findBySlug req.params.storeSlug, (err, store) ->
      dealWith err
      throw new AccessDenied() unless req.user.hasStore store
      product = new Product()
      product.updateFromSimpleProduct req.body
      product.storeName = store.name
      product.storeSlug = store.slug
      file = req.files?.picture
      saveIf = (cb) =>
        if file?
          uploader = new FileUploader()
          onlineName = uploader.randomName "#{req.params.storeSlug}/products", file.name
          uploader.upload onlineName, file, (err, fileUrl) ->
            res.json 400, err if err?
            product.picture = fileUrl
            cb()
        else
          cb()
      saveIf =>
        product.save (err) =>
          res.send 201, product.toSimpleProduct()
  
  storeProducts: (req, res) ->
    Product.findByStoreSlug req.params.storeSlug, (err, products) ->
      dealWith err
      viewModelProducts = _.map products, (p) -> p.toSimpleProduct()
      res.json viewModelProducts
  
  storeProduct: (req, res) ->
    Product.findById req.params.productId, (err, product) ->
      dealWith err
      if product?
        res.json product.toSimpleProduct()
      else
        res.send 404

  orders: (req, res) ->
    user = req.user
    Order.getSimpleByStores user.stores, (err, orders) ->
      return res.json 400, err if err?
      res.json orders

  order: (req, res) ->
    Order.findSimpleWithItemsBySellerAndId req.user, req.params._id, (err, order) ->
      return res.json 400, err if err?
      res.json order
  
_.extend Routes::, RouteFunctions::

module.exports = Routes
