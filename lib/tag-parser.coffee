{Point} = require 'atom'

module.exports =
  class TagParser
    constructor: (tags, grammar) ->
      @tags = tags
      @grammar = grammar

      #splitSymbol = '::' for c/c++, and '.' for others.
      if @grammar == 'source.c++' or @grammar == 'source.c' or
         @grammar == 'source.cpp'
        @splitSymbol = '::'
      else
        @splitSymbol = '.'

    splitParentTag: (parentTag) ->
      index = parentTag.indexOf(':')

      type: parentTag.substr(0, index)
      parent: parentTag.substr(index+1)

    splitNameTag: (nameTag) ->
      index = nameTag.lastIndexOf(@splitSymbol)
      if index >= 0
        return nameTag.substr(index+@splitSymbol.length)
      else
        return nameTag

    buildMissedParent: (parents) ->
      parentTags = Object.keys(parents)
      parentTags.sort (a, b) =>
        {typeA, parent: nameA} = @splitParentTag(a)
        {typeB, parent: nameB} = @splitParentTag(b)

        if nameA < nameB
          return -1
        else if nameA > nameB
          return 1
        else
          return 0

      for now, i in parentTags
        {type, parent: name} = @splitParentTag(now)

        if parents[now] is null
          parents[now] = {
            name: name,
            type: type,
            position: null,
            parent: null
          }

          @tags.push(parents[now])

          if i >= 1
            pre = parentTags[i-1]
            {type, parent: name} = @splitParentTag(pre)
            if now.indexOf(name) >= 0
              parents[now].parent = pre
              parents[now].name = @splitNameTag(parents[now].name)

    parse: ->
      roots = []
      parents = {}
      types = {}

      # sort tags by row number
      @tags.sort (a, b) =>
        return a.position.row - b.position.row

      # try to find out all tags with parent information
      for tag in @tags
        parents[tag.parent] = null if tag.parent

      # try to build up relationships between parent information and the real tag
      for tag in @tags
        if tag.parent
          {type, parent} = @splitParentTag(tag.parent)
          key = tag.type + ':' + parent + @splitSymbol + tag.name
        else
          key = tag.type + ':' + tag.name
        parents[key] = tag

      # try to build up the missed parent
      @buildMissedParent(parents)

      for tag in @tags
        if tag.parent
          parent = parents[tag.parent]
          unless parent.position
            parent.position = new Point(tag.position.row-1)

      @tags.sort (a, b) =>
        return a.position.row - b.position.row

      for tag in @tags
        tag.label = tag.name
        tag.icon = "icon-#{tag.type}"
        if tag.parent
          parent = parents[tag.parent]
          parent.children ?= []
          parent.children.push(tag)
        else
          roots.push(tag)
        types[tag.type] = null

      return {root: {label: 'root', icon: null, children: roots}, types: Object.keys(types)}

    getNearestTag: (row) ->
      left = 0
      right = @tags.length-1
      while left <= right
        mid = (left + right) // 2
        midRow = @tags[mid].position.row

        if row < midRow
          right = mid - 1
        else
          left = mid + 1

      nearest = left - 1
      return @tags[nearest]
