Promise = require 'bluebird'
_ = require 'lodash'

CacheService = require './cache'
elasticsearch = require './elasticsearch'
config = require '../config'

###
to migrate tables
post http://localhost:9200/_reindex
{
	"source": {"index": "campgrounds", "type": "campgrounds"}, "dest": {"index": "campgrounds_new", "type": "campgrounds_new"},
	  "script": {
	    "inline": "ctx._source.remove('forecast')",
	    "lang": "painless"
	  }
}

{
	"dest": {"index": "campgrounds", "type": "campgrounds"}, "source": {"index": "campgrounds_new", "type": "campgrounds_new"},
	  "script": {
	    "inline": "ctx._source.remove('forecast')",
	    "lang": "painless"
	  }
}


###

class ElasticsearchSetupService
  setup: (indices) =>
    CacheService.lock 'elasticsearch_setup9', =>
      Promise.each indices, @createIndexIfNotExist
    , {expireSeconds: 300}

  createIndexIfNotExist: (index) ->
    console.log 'create index', index
    elasticsearch.indices.create {
      index: index.name
      body:
        mappings:
          properties:
            index.mappings
        settings:
          number_of_shards: 3
          number_of_replicas: 2
      }
      .catch (err) ->
        # console.log 'caught', err
        # add any new mappings
        Promise.all _.map index.mappings, (value, key) ->
          elasticsearch.indices.putMapping {
            index: index.name
            body:
              properties:
                "#{key}": value
          }
        .catch -> null
    # Promise.resolve null

module.exports = new ElasticsearchSetupService()
