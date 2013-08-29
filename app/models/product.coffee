mongoose  = require 'mongoose'
slug      = require '../helpers/slug'
_         = require 'underscore'
path      = require 'path'
async     = require 'async'
Postman   = require './postman'
postman = new Postman()

productSchema = new mongoose.Schema
  name:           type: String, required: true
  nameKeywords:   [String]
  picture:        String
  price:          Number
  slug:           String
  storeName:      String
  storeSlug:      String
  tags:           [String]
  description:    String
  dimensions:
    height:       Number
    width:        Number
    depth:        Number
  weight:         Number
  shipping:
    applies:      Boolean
    charge:       Boolean
    dimensions:
      height:     Number
      width:      Number
      depth:      Number
    weight:       Number
  hasInventory:   Boolean
  inventory:      Number
  random:         type: Number, required: true, default: -> Math.random()
  comments: [
    body:         type: String, required: true
    date:         type: Date, required: true, default: Date.now
    user:         type: mongoose.Schema.Types.ObjectId, ref: 'user', required: true
    userName:     type: String, required: true
    userEmail:    type: String, required: true
  ]

productSchema.path('name').set (val) ->
  @nameKeywords = if val is '' then [] else val.toLowerCase().split ' '
  @slug = slug val.toLowerCase(), "_"
  val
productSchema.methods.url = -> "#{@storeSlug}##{@slug}"
productSchema.methods.addComment = (comment, cb) ->
  comment.userName = comment.user.name
  comment.userEmail = comment.user.email
  @comments.push comment
  @validate (err) =>
    if err?
      @comments.pop()
      return cb err
    else
      @findAdmins (err, users) =>
        return cb err if err?
        body = "<html>
          <h1>Olá!</h1>
          <div>
            Como você é um dos administradores da loja #{@storeName} estamos te avisando que o produto <strong>#{@name}</strong> recebeu um comentário.<br />
          </div>
          <div>
            Clique <a href='https://www.atelies.com.br/#{@url()}'>aqui</a> para ver o comentário.
          </div>
          <div>&nbsp;</div>
          <div>&nbsp;</div>
          <div>
            Equipe Ateliês
          </div>
          </html>"
        sendMailActions =
          for user in users
            (cb) => postman.sendFromContact user, "Ateliês: O produto #{@name} da loja #{@storeName} recebeu um comentário", body, cb
        async.parallel sendMailActions, cb

productSchema.methods.findAdmins = (cb) ->
  Store.findBySlug @storeSlug, (err, store) =>
    return cb if err?
    User.findAdminsFor store, cb
productSchema.methods.manageUrl = -> "#{@storeSlug}/#{@_id}"
productSchema.methods.pictureThumb = ->
  return undefined unless @picture?
  ext = path.extname @picture
  dir = path.dirname @picture
  name = path.basename @picture, ext
  "#{dir}/#{name}_thumb150x150#{ext}"
productSchema.methods.toSimpleProduct = ->
  _id: @_id, name: @name, picture: @picture, pictureThumb: @pictureThumb(), price: @price,
  storeName: @storeName, storeSlug: @storeSlug,
  url: @url(), tags: if @tags? then @tags.join ', ' else ''
  manageUrl: @manageUrl(), slug: @slug
  description: @description,
  height: @dimensions?.height, width: @dimensions?.width, depth: @dimensions?.depth
  weight: @weight
  shippingApplies: @shipping?.applies, shippingCharge: @shipping?.charge
  shippingHeight: @shipping?.dimensions?.height, shippingWidth: @shipping?.dimensions?.width, shippingDepth: @shipping?.dimensions?.depth
  shippingWeight: @shipping?.weight
  hasInventory: @hasInventory, inventory: @inventory
  comments: _.map(@comments, (c) -> title: c.title, body: c.body, date: c.date, userName: c.userName, userEmail: c.userEmail)
productSchema.methods.toSimplerProduct = ->
  _id: @_id, name: @name, picture: @picture, pictureThumb: @pictureThumb(), price: @price,
  storeName: @storeName, storeSlug: @storeSlug,
  url: @url(), slug: @slug
productSchema.methods.updateFromSimpleProduct = (simple) ->
  simple.hasInventory = false unless simple.hasInventory?
  for attr in ['name', 'price', 'description', 'weight', 'hasInventory', 'inventory']
    if simple[attr]? and simple[attr] isnt ''
      @[attr] = simple[attr]
    else
      @[attr] = undefined
  if simple.tags? and simple.tags isnt ''
    @tags = simple.tags?.split ','
  else
    @tags = []
  @dimensions = {} unless @dimensions?
  for attr in ['height', 'width', 'depth']
    if simple[attr]? and simple[attr] isnt ''
      @dimensions[attr] = simple[attr]
    else
      @dimensions[attr] = undefined
  @shipping = dimensions: {} unless @shipping?
  if simple.shippingHeight? and simple.shippingHeight isnt ''
    @shipping.dimensions.height = simple.shippingHeight
  else
    @shipping.dimensions.height = undefined
  if simple.shippingWidth? and simple.shippingWidth isnt ''
    @shipping.dimensions.width = simple.shippingWidth
  else
    @shipping.dimensions.width = undefined
  if simple.shippingDepth? and simple.shippingDepth isnt ''
    @shipping.dimensions.depth = simple.shippingDepth
  else
    @shipping.dimensions.depth = undefined
  if simple.shippingWeight? and simple.shippingWeight isnt ''
    @shipping.weight = simple.shippingWeight
  else
    @shipping.weight = undefined
  @shipping.applies = !!simple.shippingApplies
  @shipping.charge = !!simple.shippingCharge
productSchema.methods.hasShippingInfo = ->
  shipping = @shipping
  has = shipping.applies and
  shipping.weight? and shipping.dimensions? and
  shipping.weight <= 30 and
  11 <= shipping.dimensions.width <= 105 and
  2 <= shipping.dimensions.height <= 105 and
  16 <= shipping.dimensions.depth <= 105 and
  shipping.dimensions.height + shipping.dimensions.width + shipping.dimensions.depth <= 200
  has

module.exports = Product = mongoose.model 'product', productSchema

Product.findRandom = (howMany, cb) ->
  random = Math.random()
  Product.find({picture: /./, random:$gte:random}).sort('random').limit(howMany).exec (err, products) ->
    return cb err if err?
    if products.length < howMany
      difference = products.length - howMany
      Product.find(picture: /./).sort('random').limit(difference).exec (err, newProducts) ->
        return cb err if err?
        cb null, products.concat newProducts
    else
      cb null, products

Product.findByStoreSlug = (storeSlug, cb) -> Product.find storeSlug: storeSlug, cb
Product.findByStoreSlugAndSlug = (storeSlug, productSlug, cb) -> Product.findOne {storeSlug: storeSlug, slug: productSlug}, cb
Product.searchByName = (searchTerm, cb) ->
  Product.find nameKeywords:searchTerm.toLowerCase(), (err, products) ->
    return cb err if err
    cb null, products
Product.searchByStoreSlugAndByName = (storeSlug, searchTerm, cb) ->
  Product.find storeSlug: storeSlug, nameKeywords:searchTerm.toLowerCase(), (err, products) ->
    return cb err if err
    cb null, products
Product.getShippingWeightAndDimensions = (ids, cb) ->
  Product.find '_id': '$in': ids, '_id shipping', (err, products) ->
    cb err if err?
    cb null, products
Product.pictureDimension = '600x600'
Product.pictureThumbDimension = '150x150'

User      = require './user'
Store     = require './store'
