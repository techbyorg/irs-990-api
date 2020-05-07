elasticsearch = require 'elasticsearch'

config = require '../config'

client = new elasticsearch.Client {
  host: "#{config.ELASTICSEARCH.HOST}:9200"
  # log: 'trace'
}

module.exports = client
