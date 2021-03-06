Future = Npm.require 'fibers/future'

class DirectCollection
  constructor: (@name, @_makeNewID) ->
    unless @_makeNewID
      @_makeNewID = -> Random.id()

  findToArray: (selector, options) =>
    options = {} unless options
    cursor = @_getCollection().find(selector, options)
    blocking(cursor, cursor.toArray)()

  findEach: (selector, options, eachCallback) =>
    if _.isFunction options
      eachCallback = options
      options = {}
    options = {} unless options

    future = new Future()

    callback = (error, document) =>
      # An error might be thrown from the eachCallback, so we skip the rest
      return if future.isResolved()

      if error
        future.throw error
      else if document
        eachCallback document
      else
        future.return()

    errorHandler = (error) =>
      future.throw error if error and not future.isResolved()

    callback = Meteor.bindEnvironment callback, errorHandler, @

    @_getCollection().find(selector, options).each(callback)

    future.wait()
    return

  count: (selector, options) =>
    options = {} unless options
    collection = @_getCollection()
    blocking(collection, collection.count)(selector, options)

  findOne: (selector, options) =>
    options = {} unless options
    collection = @_getCollection()
    blocking(collection, collection.findOne)(selector, options)

  insert: (document) =>
    unless '_id' of document
      document = EJSON.clone document
      document._id = @_makeNewID()
    collection = @_getCollection()
    blocking(collection, collection.insert)(document, w: 1)
    return document._id

  update: (selector, modifier, options) =>
    options = {} unless options
    options.w = 1
    collection = @_getCollection()
    blocking(collection, collection.update)(selector, modifier, options)

  remove: (selector) =>
    collection = @_getCollection()
    blocking(collection, collection.remove)(selector, w: 1)

  renameCollection: (newName, options) =>
    options = {} unless options
    collection = @_getCollection()
    blocking(collection, collection.rename)(newName, options)

  _getCollection: =>
    MongoInternals.defaultRemoteCollectionDriver().mongo._getCollection @name

  @_getDb: ->
    future = new Future()
    MongoInternals.defaultRemoteCollectionDriver().mongo._withDb (db) ->
      future.return db
    future.wait()

  @command: (selector, options) ->
    options = {} unless options
    db = @_getDb()
    blocking(db, db.command)(selector, options)
