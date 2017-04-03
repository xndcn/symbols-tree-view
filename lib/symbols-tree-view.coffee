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
      @autoHideTypes = atom.config.get('symbols-tree-view.zAutoHideTypes')

      @treeView.onSelect ({node, item}) =>
        if item.position.row >= 0 and editor = atom.workspace.getActiveTextEditor()
          screenPosition = editor.screenPositionForBufferPosition(item.position)
          screenRange = new Range(screenPosition, screenPosition)
          {top, left, height, width} = editor.element.pixelRectForScreenRange(screenRange)
          bottom = top + height
          desiredScrollCenter = top + height / 2
          unless editor.element.getScrollTop() < desiredScrollCenter < editor.element.getScrollBottom()
            desiredScrollTop =  desiredScrollCenter - editor.element.getHeight() / 2

          from = {top: editor.element.getScrollTop()}
          to = {top: desiredScrollTop}

          step = (now) ->
            editor.element.setScrollTop(now)

          done = ->
            editor.scrollToBufferPosition(item.position, center: true)
            editor.setCursorBufferPosition(item.position)
            editor.moveToFirstCharacterOfLine()

          jQuery(from).animate(to, duration: @animationDuration, step: step, done: done)

      atom.config.observe 'symbols-tree-view.scrollAnimation', (enabled) =>
        @animationDuration = if enabled then 300 else 0

      @minimalWidth = 5
      @originalWidth = atom.config.get('symbols-tree-view.defaultWidth')
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
      if (editor = @getEditor()) and @parser?
        row = editor.getCursorBufferPosition().row
        tag = @parser.getNearestTag(row)
        @treeView.select(tag)

    focusClickedTag: (editor, text) ->
      console.log "clicked: #{text}"
      if editor = @getEditor()
        tag =  (t for t in @parser.tags when t.name is text)[0]
        @treeView.select(tag)
        # imho, its a bad idea =(
        jQuery('.list-item.list-selectable-item.selected').click()

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
        @sortByNameScopes = atom.config.get('symbols-tree-view.sortByNameScopes')
        if @sortByNameScopes.indexOf(@getScopeName()) != -1
          @cachedStatus[editor].nowSortStatus[0] = true
          @treeView.sortByName()
        {@nowTypeStatus, @nowSortStatus} = @cachedStatus[editor]

      @contextMenu.addMenu(type, @nowTypeStatus[type], toggleTypeVisible) for type in types
      @contextMenu.addSeparator()
      @contextMenu.addMenu('sort by name', @nowSortStatus[0], toggleSortByName)

    updatePane : ->
      if @hasParent()
        @remove()
        @populate()
        @attach()

    generateTags: (filePath) ->
      new TagGenerator(filePath, @getScopeName()).generate().done (tags) =>
        @parser = new TagParser(tags, @getScopeName())
        {root, types} = @parser.parse()
        @treeView.setRoot(root)
        @updateContextMenu(types)
        @focusCurrentCursorTag()

        if (@autoHideTypes)
          for type in types
            if(@autoHideTypes.indexOf(type) != -1)
              @treeView.toggleTypeVisible(type)
              @contextMenu.toggle(type)


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

    # Show view if hidden
    showView: ->
      if not @hasParent()
        @populate()
        @attach()

    # Hide view if visisble
    hideView: ->
      if @hasParent()
        @remove()
