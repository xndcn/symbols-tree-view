{CompositeDisposable} = require 'event-kit'

module.exports =
  symbolsTreeView: null

  createView: ->
    unless @symbolsTreeView?
      SymbolsTreeView = require './symbols-tree-view'
      @symbolsTreeView = new SymbolsTreeView(@state)
    @symbolsTreeView

  activate: (@state) ->
    @disposables = new CompositeDisposable

    @disposables.add atom.commands.add('atom-workspace', {
      'symbols-tree-view:toggle': => @createView().toggle()
      'symbols-tree-view:show': => @createView().showView()
      'symbols-tree-view:hide': => @createView().hideView()
    })

    atom.config.observe 'tree-view.showOnRightSide', =>
      if @symbolsTreeView? and @symbolsTreeView.hasParent()
        @symbolsTreeView.remove()
        @symbolsTreeView.populate()
        @symbolsTreeView.attach()

    atom.config.observe "symbols-tree-view.autoToggle", (enabled) =>
      if enabled
        @createView().toggle() unless @symbolsTreeView? and @symbolsTreeView.hasParent()
      else
        @symbolsTreeView.toggle() if @symbolsTreeView? and @symbolsTreeView.hasParent()

  deactivate: ->
    @disposables.dispose()
    @symbolsTreeView?.destroy()
    @symbolsTreeView = null

  serialize: ->
    symbolsTreeViewState: @symbolsTreeView?.serialize() ? @state.symbolsTreeViewState

  getProvider: ->
    { getSuggestionForWord: (textEditor, text, range) =>
      {
        range: range
        callback: () =>
          symbolsTreeview = @createView()
          symbolsTreeview.focusClickedTag.bind(symbolsTreeview)(textEditor, text)
      }
    }
