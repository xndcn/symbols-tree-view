{Point, View} = require 'atom'

{TreeView} = require './tree-view'
TagGenerator = require './tag-generator'
TagParser = require './tag-parser'

module.exports =
  class SymbolsTreeView extends View
    @content: ->
      @div class: 'symbols-tree-view tool-panel focusable-panel'

    initialize: ->
      @treeView = new TreeView
      @append(@treeView)

      atom.workspace.onDidChangeActivePaneItem (editor) =>
        @populate()

      @treeView.onSelect ({node, item}) =>
        if item.position.row >= 0 and editor = atom.workspace.getActiveEditor()
          editor.scrollToBufferPosition(item.position, center: true)
          editor.setCursorBufferPosition(item.position)
          editor.moveCursorToFirstCharacterOfLine()

      atom.config.observe 'tree-view.showOnRightSide', (value) =>
        if @hasParent()
          @detach()
          @attach()

    getEditor: -> atom.workspace.getActiveEditor()
    getScopeName: -> atom.workspace.getActiveEditor()?.getGrammar()?.scopeName

    populate: ->
      unless editor = @getEditor()
        @hide()
      else
        filePath = editor.getPath()
        @generateTags(filePath)
        @show()

        editor.onDidSave (state) =>
          @generateTags(filePath)

        editor.onDidChangeCursorPosition ({oldBufferPosition, newBufferPosition}) =>
          if oldBufferPosition.row != newBufferPosition.row
            @focusCurrentCursorTag()

    focusCurrentCursorTag: ->
      if editor = @getEditor()
        row = editor.getCursorBufferPosition().row
        tag = @parser.getNearestTag(row)
        @treeView.select(tag)

    generateTags: (filePath) ->
      new TagGenerator(filePath, @getScopeName()).generate().done (tags) =>
        @parser = new TagParser(tags, @getScopeName())
        root = @parser.parse()
        @treeView.setRoot(root)
        @focusCurrentCursorTag()

    # Returns an object that can be retrieved when package is activated
    serialize: ->

    # Tear down any state and detach
    destroy: ->
      @element.remove()

    attach: ->
      if atom.config.get('tree-view.showOnRightSide')
        @removeClass('panel-right')
        @addClass('panel-left')
        atom.workspaceView.appendToLeft(this)
      else
        @removeClass('panel-left')
        @addClass('panel-right')
        atom.workspaceView.appendToRight(this)

    # Toggle the visibility of this view
    toggle: ->
      if @hasParent()
        @remove()
      else
        @populate()
        @attach()
