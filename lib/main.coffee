SymbolsTreeView = require './symbols-tree-view'

module.exports =
  config:
    autoToggle:
      type: 'boolean'
      default: false
      description: 'If this option is enabled then symbols-tree-view will auto open when you open files.'
    scrollAnimation:
      type: 'boolean'
      default: true
      description: 'If this option is enabled then when you click the item in symbols-tree it will scroll to the destination gradually.'
    autoHide:
      type: 'boolean'
      default: false
      description: 'If this option is enabled then symbols-tree-view is always hidden unless mouse hover over it.'

  symbolsTreeView: null

  activate: (state) ->
    @symbolsTreeView = new SymbolsTreeView(state.symbolsTreeViewState)
    atom.commands.add 'atom-workspace', 'symbols-tree-view:toggle': => @symbolsTreeView.toggle()

    atom.config.observe 'tree-view.showOnRightSide', (value) =>
      if @symbolsTreeView.hasParent()
        @symbolsTreeView.remove()
        @symbolsTreeView.populate()
        @symbolsTreeView.attach()

    atom.config.observe "symbols-tree-view.autoToggle", (enabled) =>
      if enabled
        @symbolsTreeView.toggle() unless @symbolsTreeView.hasParent()
      else
        @symbolsTreeView.toggle() if @symbolsTreeView.hasParent()

  deactivate: ->
    @symbolsTreeView.destroy()

  serialize: ->
    symbolsTreeViewState: @symbolsTreeView.serialize()
