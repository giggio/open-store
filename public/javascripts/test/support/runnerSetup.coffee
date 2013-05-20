require '../../../../test/support/_specHelper'
global.requirejs = require "requirejs"
os = require 'os'
path = require 'path'

process.addListener 'uncaughtException', (error) -> console.log "Error happened:\n#{error.stack}"

initDOM = ->
  jsdom = require("jsdom")
  global.window = window = jsdom.jsdom().createWindow("<html><body></body></html>")
  window.XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest
  window.XMLHttpRequest.prototype.withCredentials = false
  global.location = window.location
  global.navigator = window.navigator
  global.XMLHttpRequest = window.XMLHttpRequest
  global.document = window.document
  global.addEventListener = window.addEventListener #for coffeescript compatibility
  unless window.localStorage?
    LocalStorage = require('node-localstorage').LocalStorage
    window.localStorage = new LocalStorage(path.join os.tmpdir(), '.localstorage-test')
    global.localStorage = window.localStorage

configureRequireJS = ->
  requirejs.config
    baseUrl: path.join __dirname, '..', ".."
    nodeRequire: require
  require '../../bootstrap'

initDOM()
configureRequireJS()
requirejs 'test/support/_specHelper'