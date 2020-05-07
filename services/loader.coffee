DataLoader = require 'dataloader'

module.exports = {
  # https://github.com/graphql/dataloader/issues/158
  withContext: (batchFunc, opts) ->
    store = new WeakMap()
    (ctx) ->
      loader = store.get(ctx)
      unless loader
        console.log 'new loader'
        loader = new DataLoader (keys) ->
          batchFunc keys, ctx
        , opts
        store.set ctx, loader
      loader
}
