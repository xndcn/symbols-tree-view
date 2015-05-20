{Point, Range} = require 'atom'
{$, jQuery, View} = require 'atom-space-pen-views'
{TreeView} = require './tree-view'
TagGenerator = require './tag-generator'
TagParser = require './tag-parser'
SymbolsContextMenu = require './symbols-context-menu'

module.exports =
  class SymbolsTreeView extends View
    @content: ->
      @div class: 'symbols-tree-view tool-panel focusable-panel'

    initialize: ->
      @treeView = new TreeView
      @append(@treeView)

      @cachedStatus = {}
      @contextMenu = new SymbolsContextMenu

      @treeView.onSelect ({node, item}) =>
        if item.position.row >= 0 and editor = atom.workspace.getActiveTextEditor()
          screenPosition = editor.screenPositionForBufferPosition(item.position)
          screenRange = new Range(screenPosition, screenPosition)
          {top, left, height, width} = editor.pixelRectForScreenRange(screenRange)
          bottom = top + height
          desiredScrollCenter = top + height / 2
          unless editor.getScrollTop() < desiredScrollCenter < editor.getScrollBottom()
            desiredScrollTop =  desiredScrollCenter - editor.getHeight() / 2

          from = {top: editor.getScrollTop()}
          to = {top: desiredScrollTop}

          step = (now) ->
            editor.setScrollTop(now)

          done = ->
            editor.scrollToBufferPosition(item.position, center: true)
            editor.setCursorBufferPosition(item.position)
            editor.moveToFirstCharacterOfLine()

          jQuery(from).animate(to, duration: @animationDuration, step: step, done: done)

      atom.config.observe 'symbols-tree-view.scrollAnimation', (enabled) =>
        @animationDuration = if enabled then 300 else 0

      @minimalWidth = 5
      @originalWidth = 200
      atom.config.observe 'symbols-tree-view.autoHide', (autoHide) =>
        unless autoHide
          @width(@originalWidth)
        else
          @width(@minimalWidth)

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
          filePath = editor.getPath()
          @generateTags(filePath)

        @onChangeRow = editor.onDidChangeCursorPosition ({oldBufferPosition, newBufferPosition}) =>
          if oldBufferPosition.row != newBufferPosition.row
            @focusCurrentCursorTag()

    focusCurrentCursorTag: ->
      if editor = @getEditor()
        row = editor.getCursorBufferPosition().row
        tag = @parser.getNearestTag(row)
        @treeView.select(tag)

    updateContextMenu: (types) ->
      @contextMenu.clear()
      editor = @getEditor()?.id

      toggleTypeVisible = (type) =>
        @treeView.toggleTypeVisible(type)
        @nowTypeStatus[type] = !@nowTypeStatus[type]

      toggleSortByName = =>
        @nowSortStatus[0] = !@nowSortStatus[0]
        if @nowSortStatus[0]
          @treeView.sortByName()
        else
          @treeView.sortByRow()
        for type, visible of @nowTypeStatus
          @treeView.toggleTypeVisible(type) unless visible
        @focusCurrentCursorTag()

      if @cachedStatus[editor]
        {@nowTypeStatus, @nowSortStatus} = @cachedStatus[editor]
        for type, visible of @nowTypeStatus
          @treeView.toggleTypeVisible(type) unless visible
        @treeView.sortByName() if @nowSortStatus[0]
      else
        @cachedStatus[editor] = {nowTypeStatus: {}, nowSortStatus: [false]}
        @cachedStatus[editor].nowTypeStatus[type] = true for type in types
        {@nowTypeStatus, @nowSortStatus} = @cachedStatus[editor]

      @contextMenu.addMenu(type, @nowTypeStatus[type], toggleTypeVisible) for type in types
      @contextMenu.addSeparator()
      @contextMenu.addMenu('sort by name', @nowSortStatus[0], toggleSortByName)

    generateTags: (filePath) ->
      new TagGenerator(filePath, @getScopeName()).generate().done (tags) =>
        @parser = new TagParser(tags, @getScopeName())
        {root, types} = @parser.parse()
        @treeView.setRoot(root)
        @updateContextMenu(types)
        @focusCurrentCursorTag()

    # Returns an object that can be retrieved when package is activated
    serialize: ->

    # Tear down any state and detach
    destroy: ->
      @element.remove()

    attach: ->
      if atom.config.get('tree-view.showOnRightSide')
        @panel = atom.workspace.addLeftPanel(item: this)
      else
        @panel = atom.workspace.addRightPanel(item: this)
      @contextMenu.attach()
      @contextMenu.hide()

    attached: ->
      @onChangeEditor = atom.workspace.onDidChangeActivePaneItem (editor) =>
        @removeEventForEditor()
        @populate()

      @onChangeAutoHide = atom.config.observe 'symbols-tree-view.autoHide', (autoHide) =>
        unless autoHide
          @off('mouseenter mouseleave')
        else
          @mouseenter (event) =>
            @stop()
            @animate({width: @originalWidth}, duration: @animationDuration)

          @mouseleave (event) =>
            @stop()
            if atom.config.get('tree-view.showOnRightSide')
              @animate({width: @minimalWidth}, duration: @animationDuration) if event.offsetX > 0
            else
              @animate({width: @minimalWidth}, duration: @animationDuration) if event.offsetX <= 0

      @on "contextmenu", (event) =>
        left = event.pageX
        if left + @contextMenu.width() > atom.getSize().width
          left = left - @contextMenu.width()
        @contextMenu.css({left: left, top: event.pageY})
        @contextMenu.show()
        return false #disable original atom context menu

    removeEventForEditor: ->
      @onEditorSave?.dispose()
      @onChangeRow?.dispose()

    detached: ->
      @onChangeEditor?.dispose()
      @onChangeAutoHide?.dispose()
      @removeEventForEditor()
      @off "contextmenu"

    remove: ->
      super
      @panel.destroy()

    # Toggle the visibility of this view
    toggle: ->
      if @hasParent()
        @remove()
      else
        @populate()
        @attach()
