Promise = require 'bluebird'
_ = require 'lodash'

CacheService = require './cache'
cknex = require './cknex'
cassandra = require 'cassandra-driver'
config = require '../config'

# TODO

class ScyllaSetupService
  setup: (tables) =>
    CacheService.lock 'scylla_setup1', =>
      Promise.all [
        @createKeyspaceIfNotExists 'monocle'
      ]
      .then =>
        if config.ENV is config.ENVS.DEV and false
          createTables = _.map _.filter(tables, ({name}) ->
            name.indexOf('user') isnt -1
          )
          Promise.each createTables, @createTableIfNotExist
        else
          Promise.each tables, @createTableIfNotExist
    , {expireSeconds: 300}

  createKeyspaceIfNotExists: (keyspaceName) ->
    cknex.getClient().execute """
    CREATE KEYSPACE IF NOT EXISTS #{keyspaceName} WITH replication = {
      'class': 'NetworkTopologyStrategy', 'datacenter1': '3'
    } AND durable_writes = true;
    """

  addColumnToQuery: (q, type, key) ->
    if typeof type is 'object'
      try
        if type.type is 'json'
          type.type = 'text'
        if type.subType2
          q[type.type] key, type.subType, type.subType2
        else
          q[type.type] key, type.subType
      catch err
        console.log type.type, err
    else
      try
        if type is 'json'
          type = 'text'
        q[type] key
      catch err
        console.log key
        throw err

  ###
  materializedViews:
  fields or *, primaryKey, withClusteringOrderBy
  ###
  createTableIfNotExist: (table) =>
    console.log 'create', table.name
    primaryColumns = _.filter(
      table.primaryKey.partitionKey.concat(table.primaryKey.clusteringColumns)
    )
    {primaryFields, normalFields} = _.reduce table.fields, (obj, type, key) ->
      if key in primaryColumns
        obj.primaryFields.push {key, type}
      else
        obj.normalFields.push {key, type}
      obj
    , {primaryFields: [], normalFields: []}

    # add primary fields, set as primary, set order
    q = cknex(table.keyspace).createColumnFamilyIfNotExists table.name

    _.map primaryFields, ({key, type}) =>
      @addColumnToQuery q, type, key

    if table.primaryKey.clusteringColumns
      q.primary(
        table.primaryKey.partitionKey, table.primaryKey.clusteringColumns
      )
    else
      q.primary table.primaryKey.partitionKey

    if table.withClusteringOrderBy
      unless _.isArray table.withClusteringOrderBy[0]
        table.withClusteringOrderBy = [table.withClusteringOrderBy]
      _.map table.withClusteringOrderBy, (orderBy) ->
        q.withClusteringOrderBy(
          orderBy[0]
          orderBy[1]
        )

    q.run()
    .then =>
      # add any new columns
      Promise.each normalFields, ({key, type}) =>
        q = cknex(table.keyspace).alterColumnFamily(table.name)
        @addColumnToQuery q, type, key
        q.run().catch -> null
    .then =>
      Promise.all _.map table.materializedViews, (view, name) ->
        {fields, primaryKey, withClusteringOrderBy, notNullFields} = view
        fieldsStr = if fields then "\"#{fields.join('","')}\"" else '*'
        notNullFields = _.flatten _.map primaryKey, (arr) -> arr
        if notNullFields
          whereStr = 'WHERE '
          _.map notNullFields, (field, i) ->
            whereStr += "\"#{field}\" IS NOT NULL"
            if i < notNullFields.length - 1
              whereStr += ' AND '
        else
          whereStr = ''

        if primaryKey.clusteringColumns
          keyStr = "PRIMARY KEY(
            (\"#{primaryKey.partitionKey.join('","')}\"),
            \"#{primaryKey.clusteringColumns.join('","')}\")"
        else
          keyStr = "PRIMARY KEY((\"#{primaryKey.partitionKey.join('","')}\"))"

        if withClusteringOrderBy and typeof withClusteringOrderBy[0] is 'object'
          orderByStr = "WITH CLUSTERING ORDER BY ("
          _.map withClusteringOrderBy, (orderBy, i) ->
            orderByStr += "\"#{orderBy[0]}\" #{orderBy[1]}"
            if i < withClusteringOrderBy.length - 1
              orderByStr += ', '
          orderByStr += ')'
        else if withClusteringOrderBy
          orderByStr = "WITH CLUSTERING ORDER BY (
                          \"#{withClusteringOrderBy[0]}\"
                          #{withClusteringOrderBy[1]})"
        else
          orderByStr = ''

        query = "CREATE MATERIALIZED VIEW #{table.keyspace}.\"#{name}\" AS
          SELECT #{fieldsStr} FROM #{table.keyspace}.\"#{table.name}\"
          #{whereStr}
          #{keyStr}
          #{orderByStr};"
        cknex.getClient().execute query
        .catch (err) ->
          unless err.code is 9216
            throw err
      , {concurrency: 1}

module.exports = new ScyllaSetupService()
