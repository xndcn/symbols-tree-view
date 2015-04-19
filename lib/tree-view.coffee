{$, $$, View, ScrollView} = require 'atom-space-pen-views'
{Emitter} = require 'event-kit'

module.exports =
  TreeNode: class TreeNode extends View
    @content: ({label, icon, children}) ->
      if children
        @li class: 'list-nested-item list-selectable-item', =>
          @div class: 'list-item', =>
            @span class: "icon #{icon}", label
          @ul class: 'list-tree', =>
            for child in children
              @subview 'child', new TreeNode(child)
      else
        @li class: 'list-item list-selectable-item', =>
          @span class: "icon #{icon}", label

    initialize: (item) ->
      @emitter = new Emitter
      @item = item
      @item.view = this

      @on 'dblclick', @dblClickItem
      @on 'click', @clickItem

    isCollapsed: ->
      return @hasClass('collapsed')

    setCollapsed: ->
      @toggleClass('collapsed') if @item.children

    collapse: ->
      @addClass('collapsed') if @item.children

    uncollapse:->
      @removeClass('collapsed')

    setSelected: ->
      @addClass('selected')

    onDblClick: (callback) ->
      @emitter.on 'on-dbl-click', callback
      if @item.children
        for child in @item.children
          child.view.onDblClick callback

    onSelect: (callback) ->
      @emitter.on 'on-select', callback
      if @item.children
        for child in @item.children
          child.view.onSelect callback

    clickItem: (event) =>
      if @item.children
        selected = @hasClass('selected')
        @removeClass('selected')
        $target = @find('.list-item:first')
        left = $target.position().left
        right = $target.children('span').position().left
        width = right - left
        @toggleClass('collapsed') if event.offsetX <= width
        @addClass('selected') if selected
        return false if event.offsetX <= width

      @emitter.emit 'on-select', {node: this, item: @item}
      return false

    selectItem: ->
      @emitter.emit 'on-select', {node: this, item: @item}

    dblClickItem: (event) =>
      @emitter.emit 'on-dbl-click', {node: this, item: @item}
      return false


  TreeView: class TreeView extends ScrollView
    @content: ->
      @div class: '-tree-view-', tabindex:-1, =>
        @ul class: 'list-tree has-collapsable-children', outlet: 'root'

    initialize: ->
      super
      @emitter = new Emitter

    deactivate: ->
      @remove()

    onSelect: (callback) =>
      @emitter.on 'on-select', callback

    setRoot: (root, ignoreRoot=true) ->
      @tagList = root
      @rootNode = new TreeNode(root)

      @rootNode.onDblClick ({node, item}) =>
        node.setCollapsed()
      @rootNode.onSelect ({node, item}) =>
        @clearSelect()
        node.setSelected()
        @emitter.emit 'on-select', {node, item}

      @root.empty()
      @root.append $$ ->
        @div =>
          if ignoreRoot
            for child in root.children
              @subview 'child', child.view
          else
            @subview 'root', @rootNode

    traversal: (root, doing) =>
      doing(root.item)
      if root.item.children
        for child in root.item.children
          @traversal(child.view, doing)

    toggleTypeVisible: (type) =>
      @traversal @rootNode, (item) =>
        if item.type == type
          item.view.toggle()

    sortByName: (ascending=true) =>
      @traversal @rootNode, (item) =>
        item.children?.sort (a, b) =>
          if ascending
            return a.name.localeCompare(b.name)
          else
            return b.name.localeCompare(a.name)
      @setRoot(@rootNode.item)

    sortByRow: (ascending=true) =>
      @traversal @rootNode, (item) =>
        item.children?.sort (a, b) =>
          if ascending
            return a.position.row - b.position.row
          else
            return b.position.row - a.position.row
      @setRoot(@rootNode.item)


    collapseActiveItem: ->
      @activeItem.view.collapse()

    uncollapseActiveItem: ->
      @activeItem.view.uncollapse()

    clearSelect: ->
      $('.list-selectable-item').removeClass('selected')

    selectNext: ->
      @selectTag @getNextTag(@activeItem)


    selectPrev: ->
      @selectTag @getPrevTag(@activeItem)


    selectTag: (tag)->
      if tag
         @select tag
         tag.view.selectItem()

    getNextTag: (item) ->
      return if !item

      if item.children and !item.view.isCollapsed()
         return item.children[0]
      else
         while parent = item.parentNode || @tagList
            ind = parent.children.indexOf(item) + 1
            if ind < parent.children.length
               return parent.children[ind]
            else
               return if parent.label == 'root'
               item = parent

    getPrevTag: (item) ->
       return if !item

       parent = item.parentNode || @tagList
       ind = parent.children.indexOf(item) - 1
       if 0 <= ind
          item = parent.children[ind]
          while item.children && !item.view.isCollapsed()
             [..., item] = item.children

          return item
       else
          return parent if parent.label != 'root'

    select: (item) ->
      @clearSelect()
      item?.view.setSelected()
      @activeIndex = @tagList.children.indexOf(item)
      @activeItem = item
