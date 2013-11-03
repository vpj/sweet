delegateEventSplitter = /^(\S+)\s*(.*)$/

class View
 constructor: ->
  @_viewId = _.uniqueId 'view'
  @_init.apply @, arguments
  @_setupElement()

 _events: {}
 _attrs: {}
 _initFuncs: []

 @events: (events) ->
  @::_events = _.clone @::_events
  for k, v of events
   @::_events[k] = v

 @attributes: (attributes) ->
  @::_attrs = _.clone @::_attrs
  for k, v of attributes
   @::_attrs[k] = v

 @initialize: (func) ->
  @::_initFuncs = _.clone @::_initFuncs
  @::_initFuncs.push func

 @include: (obj) ->
  for k, v of obj when not @::[k]?
   @::[k] = v

 tagName: 'div'
 $: (selector) -> @$el.find selector

 _init: ->
  for init in @_initFuncs
   init.apply @, arguments

 render: -> null

 setElement: (element, delegate) ->
  @undelegateEvents() if @$el?
  @$el = $ element
  @el = @$el[0]

  @delegateEvents() unless delegate is off

 delegateEvents: ->
  @undelegateEvents()

  for key, method of @_events
   [key, eventName, selector] = key.match delegateEventSplitter
   method = _.bind this[method], this
   eventName += '.delegateEvents' + @_viewId
   if selector is ""
    @$el.on eventName, method
   else
    @$el.on eventName, selector, method

 undelegateEvents: ->
  @$el.off '.delegateEvents' + @_viewId

 _setupElement: ->
  if not @el
   attrs = _.clone @_attrs
   attrs.id = @id if @id?
   attrs.class = @className if @className

   $el = ($ "<#{@tagName}>").attr attrs
   @setElement $el
  else
   @setElement @el

window.Sweet =
 View: View
