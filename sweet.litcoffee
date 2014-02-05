#Sweet.js

##Sweet.Base
Introduces class level function initialize and include. This class is the base class of all other classes in Sweet.JS

    class Base
     constructor: ->
      @_init.apply @, arguments

     _initFuncs: []

####Register initialize functions.
All initializer funcitons in subclasses  will be called with the constructor arguments.

     @initialize: (func) ->
      @::_initFuncs = _.clone @::_initFuncs
      @::_initFuncs.push func

     _init: ->
      for init in @_initFuncs
       init.apply @, arguments

####Include objects.
You can include objects by registering them with @include. This tries to solve the problem of single inheritence.

     @include: (obj) ->
      for k, v of obj when not @::[k]?
       @::[k] = v


##Sweet.Model
Model lets you set default key value set, and it will extend the object parsed to it in the same structure as defaults

    class Model extends Base
     _defaults: {}

####Register default key value set.
Subclasses will include and can override default key-values of parent classes

     @defaults: (defaults) ->
      @::_defaults = _.clone @::_defaults
      for k, v of defaults
       @::_defaults[k] = v

Build a model with the structure of defaults.

     @initialize (options) ->
      @values = {}
      for k, v of @_defaults
       if options[k]?
        @values[k] = options[k]
       else
        @values[k] = v

####Returns key value set

     toJSON: ->
      return _.clone @values

####Get value of a given key

     get: (key) -> @values[key]

####Set a key value combination

     set: (key, value) -> @value[key] = value if @_defaults[key]?


##Sweet.View

Wraps around a dom element, to handle events, rendering, attributes, etc

    class View extends Base
     delegateEventSplitter: /^(\S+)\s*(.*)$/

     @initialize ->
      @_viewId = _.uniqueId 'view'
      @_setupElement()

     _events: {}
     _attrs: {}

####Register events

`"click .btn": "open"`
This will call `@open` on `click` event occurs for `.btn`.
You can add or override events in subclasses.

     @events: (events) ->
      @::_events = _.clone @::_events
      for k, v of events
       @::_events[k] = v

####Register attributes
This will set attributes of the com element

     @attributes: (attributes) ->
      @::_attrs = _.clone @::_attrs
      for k, v of attributes
       @::_attrs[k] = v

####Tag of the dom element

     tagName: 'div'

####Jquery selector on dom element

     $: (selector) -> @$el.find selector

####Render

     render: -> null

####Sets the dom element

You can specify a dom element using @el

     setElement: (element, delegate) ->
      @undelegateEvents() if @$el?
      @$el = $ element
      @el = @$el[0]

      @delegateEvents() unless delegate is off

####Setup events

     delegateEvents: ->
      @undelegateEvents()

      for key, method of @_events
       [key, eventName, selector] = key.match @delegateEventSplitter
       method = _.bind this[method], this
       eventName += '.delegateEvents' + @_viewId
       if selector is ""
        @$el.on eventName, method
       else
        @$el.on eventName, selector, method

####Remove events

     undelegateEvents: ->
      @$el.off '.delegateEvents' + @_viewId

####Initilize dom element

     _setupElement: ->
      if not @el
       attrs = _.clone @_attrs
       attrs.id = @id if @id?
       attrs.class = @className if @className

       $el = ($ "<#{@tagName}>").attr attrs
       @setElement $el
      else
       @setElement @el

##Sweet.Router

Routing with hash tags or pushState

    class Router extends Base
     optionalParam: /\((.*?)\)/g
     namedParam: /(\(\?)?:\w+/g
     splatParam: /\*\w+/g
     escapeRegExp: /[\-{}\[\]+?.,\\\^$|#\s]/g

     @initialize ->
      @_bindRoutes()
      @_event = null
      @_history = []

     _routes: {}

####Register router
`'analyse/:analysis': 'onAnalyse'`
`dashboard': ['auth', 'dashboard']`
This will match urls of the form `analyse/\*` and call method @onAnalyse with the parameter.
Second route will first call @auth and and call @dashboard only if it returns true
The most specific route should be at bottom
Routers can added or overridden in subclasses

     @routes: (routes) ->
      @::_routes = _.clone @::_routes
      for k, v of routes
       @::_routes[k] = v

####Starts routing
Option silent will not trigger an event for the current url

     start: (options) ->
      Sweet.history.start options
      fragment = Sweet.history.getFragment()

      if options?.silent is on
       @_history.push fragment: fragment, title: document.title

####Goes to previous page if exists

     back: ->
      if @_history.length > 1
       Sweet.history.back()

####Whether it is possible to go to previous page

     canBack: ->
      if @_history.length > 1 and Sweet.history.canBack()
       return true
      else
       return false

####Registers a route

     route: (route, name) ->
      (route = @_routeToRegExp route) if not _.isRegExp route

Registers the route with Sweet.history

      Sweet.history.route route, (fragment, event) =>
       args = @_extractParameters route, fragment
       @_event = event

Handle state

       if @_event?.type is "popstate"
        @_history.pop()
        if @_history.length is 0
         @_history.push fragment: fragment, title: document.title, state: @getState()
       else
        @_history.push fragment: fragment, title: document.title, state: @getState()

Calls callbacks in order

       callbacks = name
       callbacks = [callbacks] if not Array.isArray callbacks

       for callback in callbacks
        callback = @[callback]
        break unless callback.apply this, args

####Gets the current HTML5 History state

     getState: ->
      if @_event?.originalEvent?.state?
       return @_event.originalEvent.state
      else
       return null

####Navigate to a new URL, while setting HTML5 History state

     navigate: (fragment, options) ->
      options = {} unless options
      if options.replace
       @_history.pop()
      if not options.trigger
       @_history.push fragment: fragment, title: options.title, state: options.state

      Sweet.history.navigate fragment, options

Bind routes

     _bindRoutes: ->
      for route, name of @_routes
       @route route, name

Convert a route string into a regular expression, suitable for matching

     _routeToRegExp: (route) ->
      route = route.replace @escapeRegExp, '\\$&'
                   .replace @noptionalParam, '(?:$1)?'
                   .replace @namedParam, (match, optional) ->
                     if optional then match else '([^\/]+)'
                   .replace @splatParam, '(.*?)'

       return new RegExp "^#{route}$"

Extract parameters from a route regex and URL

     _extractParameters: (route, fragment) ->
      params = route.exec(fragment).slice(1)
      return _.map params, (param) ->
       if param then decodeURIComponent(param) else null

## History class

    class History extends Base

Strip leading hash/slash and trailing space

     routeStripper: /^[#\/]|\s+$/g

Strip leading and trailing slashes

     rootStripper: /^\/+|\/+$/g

Remove trailing slash

     trailingSlash: /\/$/

Strip urls of hash and query

     pathStripper: /[?#].*$/

     @initialize ->
      @handlers = []
      _.bindAll this, 'checkUrl'
      @history = window.history
      @location = window.location
      @stateList = []

Hash check interval

     interval: 50

Get hash value

     getHash: ->
      match = @location.href.match /#(.*)$/
      return (if match? then match[1] else '')

Get emulated state

     getEmulateState: ->
      if @stateList.length > 0
       return @stateList[@stateList.length - 1]
      else
       return {fragment: ""}

     popEmulateState: -> @stateList.pop()

     pushEmulateState: (state, title, fragment) ->
      @stateList.push
       state: state
       title: title
       fragment: fragment

Get the URL fragment

     getFragment: (fragment, forcePushState) ->
      if not fragment?
       if @_emulateState
        fragment = @getEmulateState().fragment
       else if @_hasPushState or not @_wantsHashChange or forcePushState
        fragment = @location.pathname
        root = @root.replace @trailingSlash, ''
        if (fragment.indexOf root) is 0
         fragment = fragment.slice root.length
       else
        fragment = @getHash()

      return fragment.replace @routeStripper, ''

####Goto the previous page

     back: ->
      if @_emulateState is on
       @popEmulateState()
       @loadUrl null, null
      else
       @history?.back?()

####Can back?

     canBack: ->
      if @_emulateState is on
       return @stateList.length > 1
      else
       return @history?.back?

####Start listening to events

     start: (options) ->
      History.started = true

      @options = _.extend {root: '/'}, @options, options
      @root = @options.root
      @_emulateState = @options.emulateState is on
      @_wantsHashChange = @_emulateState is off and @options.hashChange isnt off
      @_wantsPushState = @_emulateState is off and @options.pushState is on
      @_hasPushState = @_wantsPushState is on and @history?.pushState?
      if @_emulateState and @options.start?
       @pushEmulateState @options.start.state, @options.start.title, @options.start.fragment

      @fragment = @getFragment()

Normalize root to always include a leading and trailing slash.

      @root = "/#{@root}/".replace @rootStripper, '/'

Depending on whether we're using pushState or hashes, and whether
'onhashchange' is supported, determine how we check the URL state.

      if @_hasPushState
       $(window).on 'popstate', @checkUrl
      else if @_wantsHashChange and window.onhashchange?
       @(window).on 'hashchange', @checkUrl
      else if @_wantsHashChange
       @_checkUrlInterval = setInterval @checkUrl, @interval

      if not @options.silent
       @loadUrl null, null

####Add a listener to a router

     route: (route, callback) ->
      @handlers.unshift route: route, callback: callback

Check current url for changes

     checkUrl: (e) ->
      fragment = @getFragment()
      return if fragment is @fragment
      @loadUrl fragment, e

Call callbacks of matching route

     loadUrl: (fragment, e) ->
      fragment = @fragment = @getFragment fragment
      return _.any this.handlers, (handler) ->
       if handler.route.test fragment
        handler.callback fragment, e
        return true
       else
        return false

####Navigate to a URL
Triggers a route is option trigger is on
Replaces the url is option replace is on
Sets state and title

     navigate: (fragment, options) ->
      return false if not History.started

      fragment = @getFragment(fragment or '')
      url = @root + fragment

Strip the fragment of the query and hash for matching.

      fragment = fragment.replace @pathStripper, ''

      return if @fragment is fragment
      @fragment = fragment

Don't include a trailing slash on the root.

      if fragment is '' and url isnt '/'
       url = url.slice 0, -1

If pushState is available, we use it to set the fragment as a real URL.

      if @_emulateState
       if options.replace is on
        @popEmulateState()
       state = {}
       state = options.state if options.state?
       title = ''
       title = options.title if options.title?
       @pushEmulateState state, title, fragment
      else if @_hasPushState
       method = if options.replace then 'replaceState' else 'pushState'
       state = {}
       state = options.state if options.state?
       title = ''
       title = options.title if options.title?
       @history[method] state, title, url

If hash changes haven't been explicitly disabled, update the hash
fragment to store history.

      else if @_wantsHashChange
       @_updateHash @location, fragment, options.replace

If you've told us that you explicitly don't want fallback hashchange-
based history, then `navigate` becomes a page refresh.

      else
       return @location.assign url
      if options.trigger
       return @loadUrl fragment, null

Update the hash

     _updateHash: (location, fragment, replace) ->
      if replace
       href = location.href.replace /(javascript:|#).*$/, ''
       location.replace "#{href}##{fragment}"
      else
       location.hash = "##{fragment}"

    window.Sweet = Sweet =
     View: View
     Router: Router
     Model: Model
     Base: Base

    Sweet.history = new History
