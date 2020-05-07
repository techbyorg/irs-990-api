_ = require 'lodash'
Promise = require 'bluebird'
uuid = require 'node-uuid'

cknex = require '../services/cknex'
elasticsearch = require '../services/elasticsearch'

module.exports = class Base
  constructor: ->
    @fieldsWithType = _.reduce @getScyllaTables(), (obj, table) ->
      if table.ignoreUpsert
        return obj
      _.forEach table.fields, (value, key) ->
        obj[key] = {
          type: value?.type or value
          defaultFn: value?.defaultFn
        }
      obj
    , {}

    @fieldsWithDefaultFn = _.pickBy @fieldsWithType, ({type, defaultFn}, key) ->
      defaultFn or (key is 'id' and type in ['uuid', 'timeuuid'])

  batchUpsert: (rows, {ESRefresh} = {}) =>
    ESRows = await Promise.map rows, (row) =>
      @upsert row, {isBatch: true}
    @batchIndex ESRows, {refresh: ESRefresh}

  batchIndex: (rows, {refresh} = {}) =>
    if _.isEmpty @getElasticSearchIndices?()
      Promise.resolve()
    else
      elasticsearch.bulk {
        refresh: refresh
        index: @getElasticSearchIndices?()[0].name
        body: _.flatten _.map rows, (row) =>
          row = @defaultESInput row
          id = row.id
          row = _.pick row, _.keys @getElasticSearchIndices?()[0].mappings
          [{update: {_id: id}}, {doc_as_upsert: true, doc: row}]
      }

  upsertByRow: (row, diff, options = {}) =>
    keyColumns = _.filter _.uniq _.flatten _.map @getScyllaTables(), (table) ->
      table.primaryKey.partitionKey.concat(
        table.primaryKey.clusteringColumns
      )
    primaryKeyValues = _.pick row, keyColumns

    @upsert(
      _.defaults(diff, primaryKeyValues)
      _.defaults options, {skipAdditions: Boolean row}
    )


  # TODO: cleanup isBatch part of this
  # if batching, we skip the ES index, and spit that back so it can be done bulk
  upsert: (row, options = {}) =>
    {prepareFn, isUpdate, skipAdditions, isBatch} = options

    scyllaRow = @defaultInput row, {skipAdditions}
    ESRow = _.defaults {id: scyllaRow.id}, row

    await Promise.all _.filter _.map(@getScyllaTables(), (table) =>
      if table.ignoreUpsert
        return
      @_upsertScyllaRowByTableAndRow table, scyllaRow, options
    ).concat [
      unless isBatch
        @index ESRow
    ]

    await @clearCacheByRow? scyllaRow

    if @streamChannelKey
      if prepareFn
        scyllaRow = await prepareFn(scyllaRow)

      unless isUpdate
        @streamCreate scyllaRow
      res = @defaultOutput scyllaRow
    else
      res = @defaultOutput scyllaRow

    if isBatch
      ESRow
    else
      res


  _upsertScyllaRowByTableAndRow: (table, scyllaRow, options = {}) ->
    {ttl, add, remove} = options

    scyllaTableRow = _.pick scyllaRow, _.keys table.fields

    keyColumns = _.filter table.primaryKey.partitionKey.concat(
      table.primaryKey.clusteringColumns
    )

    if missing = _.find(keyColumns, (column) -> not scyllaTableRow[column])
      return console.log "missing #{missing} in #{table.name} upsert"

    set = _.omit scyllaTableRow, keyColumns

    if _.isEmpty set
      q = cknex().insert scyllaTableRow
      .into table.name
    else
      q = cknex().update table.name
      .set set
      _.forEach keyColumns, (column) ->
        q.andWhere column, '=', scyllaTableRow[column]
    if ttl
      q.usingTTL ttl
    if add
      q.add add
    if remove
      q.remove remove
    q.run()

  getESIndexQuery: (row) =>
    row = @defaultESInput row
    query = {
      index: @getElasticSearchIndices?()[0].name
      id: row.id
      body:
        doc:
          _.pick row, _.keys @getElasticSearchIndices?()[0].mappings
        doc_as_upsert: true
    }

  index: (row) =>
    query = @getESIndexQuery row
    if _.isEmpty(@getElasticSearchIndices?()) or _.isEmpty(query.body.doc)
      Promise.resolve()
    else
      elasticsearch.update query
      .catch (err) =>
        # console.log 'elastic err', @getElasticSearchIndices?()[0].name, err
        throw err

  search: ({query, sort, limit, trackTotalHits}) =>
    limit ?= 50

    {hits} = await elasticsearch.search {
      index: @getElasticSearchIndices()[0].name
      body:
        track_total_hits: trackTotalHits # get accurate "total"
        query:
          # random ordering so they don't clump on map
          function_score:
            query: query
            boost_mode: 'replace'
        sort: sort
        from: 0
        # it'd be nice to have these distributed more evently
        # grab ~2,000 and get random 250?
        # is this fast/efficient enough?
        size: limit
    }

    total = hits.total?.value
    {
      total: total
      rows: _.map hits.hits, ({_id, _source}) =>
        @defaultESOutput _.defaults _source, {id: _id}
    }

  # parts of row -> full row
  getByRow: (row) =>
    scyllaRow = @defaultInput row
    table = @getScyllaTables()[0]
    keyColumns = _.filter table.primaryKey.partitionKey.concat(
      table.primaryKey.clusteringColumns
    )
    q = cknex().select '*'
    .from table.name
    _.forEach keyColumns, (column) ->
      q.andWhere column, '=', scyllaRow[column]
    q.run {isSingle: true}

  # returns row that was deleted
  _deleteScyllaRowByTableAndRow: (table, row) =>
    scyllaRow = @defaultInput row

    keyColumns = _.filter table.primaryKey.partitionKey.concat(
      table.primaryKey.clusteringColumns
    )
    q = cknex().select '*'
    .from table.name
    _.forEach keyColumns, (column) ->
      q.andWhere column, '=', scyllaRow[column]
    response = await q.run({isSingle: true})

    q = cknex().delete()
    .from table.name
    _.forEach keyColumns, (column) ->
      q.andWhere column, '=', scyllaRow[column]
    await q.run()

    response

  # to prevent dupe upserts, elasticsearch id needs to be combination of all
  # of scylla primary key values
  getESIdByRow: (row) =>
    scyllaTable = _.find @getScyllaTables(), ({ignoreUpsert}) ->
      not ignoreUpsert
    keyColumns = _.filter scyllaTable.primaryKey.partitionKey.concat(
      scyllaTable.primaryKey.clusteringColumns
    )
    _.map(keyColumns, (column) ->
      row[column]
    ).join('|').substr(0, 512) # 512b max limit


  deleteByRow: (row) =>
    await Promise.all _.filter _.map(@getScyllaTables(), (table) =>
      if table.ignoreUpsert
        return
      @_deleteScyllaRowByTableAndRow table, row
    ).concat [@deleteESById @getESIdByRow(row)]

    await @clearCacheByRow? row

    if @streamChannelKey
      @streamDeleteById row.id, row
    null

  deleteESById: (id) =>
    if _.isEmpty @getElasticSearchIndices?()
      Promise.resolve()
    else
      elasticsearch.delete {
        index: @getElasticSearchIndices?()[0].name
        id: "#{id}"
      }
      .catch (err) ->
        console.log 'elastic err', err

  defaultInput: (row, {skipAdditions} = {}) =>
    unless skipAdditions
      _.map @fieldsWithDefaultFn, (field, key) ->
        value = row[key]
        if not value and not skipAdditions and field.defaultFn
          row[key] = field.defaultFn()
        else if not value and not skipAdditions and field.type is 'uuid'
          row[key] = cknex.getUuid()
        else if not value and not skipAdditions and field.type is 'timeuuid'
          row[key] = cknex.getTimeUuid()
    _.mapValues row, (value, key) =>
      {type} = @fieldsWithType[key] or {}

      if type is 'json'
        JSON.stringify value
      # else if type is 'timeuuid' and typeof value is 'string'
      #   row[key] = cknex.getTimeUuidFromString(value)
      # else if type is 'uuid' and typeof value is 'string'
      #   row[key] = cknex.getUuidFromString(value)
      else
        value

  defaultOutput: (row) =>
    unless row?
      return null

    _.mapValues row, (value, key) =>
      {type, defaultFn} = @fieldsWithType[key] or {}
      if type is 'json' and value and typeof value is 'object'
        value
      else if type is 'json' and value
        try
          JSON.parse value
        catch
          defaultFn?() or {}
      else if type is 'json'
        defaultFn?() or {}
      else if type is 'counter'
        parseInt value
      else if value and type in ['uuid', 'timeuuid']
        "#{value}"
      else
        value

  defaultESInput: (row) =>
    id = @getESIdByRow row
    if row.id and id isnt row.id
      row.scyllaId = "#{row.id}"
    row.id = id
    _.mapValues row, (value, key) =>
      {type} = @fieldsWithType[key] or {}

      if type is 'json' and typeof value is 'string'
        JSON.parse value
      else
        value

  defaultESOutput: (row) -> row
