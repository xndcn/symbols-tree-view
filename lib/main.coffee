SymbolsTreeView = require './symbols-tree-view'

module.exports =
  configDefaults:
    autoToggle: false
    scrollAnimation: true

  symbolsTreeView: null

  activate: (state) ->
    @symbolsTreeView = new SymbolsTreeView(state.symbolsTreeViewState)
    atom.commands.add 'atom-workspace', 'symbols-tree-view:toggle': => @symbolsTreeView.toggle()

    @symbolsTreeView.toggle() if atom.config.get("symbols-tree-view.autoToggle")

  deactivate: ->
    @symbolsTreeView.destroy()

  serialize: ->
    symbolsTreeViewState: @symbolsTreeView.serialize()
