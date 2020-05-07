_ = require 'lodash'
_capitalize = require 'lodash/capitalize'

class FormatService
  fixAllCaps: (str) ->
    str?.toLowerCase().replace(/\w+/g, _capitalize)

module.exports = new FormatService()
