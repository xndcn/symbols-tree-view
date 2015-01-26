{Point} = require 'atom'
{View} = require 'atom-space-pen-views'
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

      @treeView.onSelect ({node, item}) =>
        if item.position.row >= 0 and editor = atom.workspace.getActiveTextEditor()
          editor.scrollToBufferPosition(item.position, center: true)
          editor.setCursorBufferPosition(item.position)
          editor.moveToFirstCharacterOfLine()

      @onChangeSide = atom.config.observe 'tree-view.showOnRightSide', (value) =>
        if @hasParent()
          @remove()
          @populate()
          @attach()

    getEditor: -> atom.workspace.getActiveTextEditor()
    getScopeName: -> atom.workspace.getActiveTextEditor()?.getGrammar()?.scopeName

    populate: ->
      unless editor = @getEditor()
        @hide()
      else
        filePath = editor.getPath()
        @generateTags(filePath)
        @show()

        @onEditorSave = editor.onDidSave (state) =>
          @generateTags(filePath)

        @onChangeRow = editor.onDidChangeCursorPosition ({oldBufferPosition, newBufferPosition}) =>
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
      @onEditorChange = atom.workspace.onDidChangeActivePaneItem (editor) =>
        @removeEventForEditor()
        @populate()

      if atom.config.get('tree-view.showOnRightSide')
        @panel = atom.workspace.addLeftPanel(item: this)
      else
        @panel = atom.workspace.addRightPanel(item: this)

    removeEventForEditor: ->
      @onEditorSave.dispose() if @onEditorSave
      @onChangeRow.dispose() if @onChangeRow

    remove: ->
      super
      @onEditorChange.dispose() if @onEditorChange
      @removeEventForEditor()
      @panel.destroy()

    # Toggle the visibility of this view
    toggle: ->
      if @hasParent()
        @remove()
      else
        @populate()
        @attach()
