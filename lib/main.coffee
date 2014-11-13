SymbolsTreeView = require './symbols-tree-view'

module.exports =
  symbolsTreeView: null

  activate: (state) ->
    @symbolsTreeView = new SymbolsTreeView(state.symbolsTreeViewState)
    atom.commands.add 'atom-workspace', 'symbols-tree-view:toggle': => @symbolsTreeView.toggle()

  deactivate: ->
    @symbolsTreeView.destroy()

  serialize: ->
    symbolsTreeViewState: @symbolsTreeView.serialize()
