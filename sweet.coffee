delegateEventSplitter = /^(\S+)\s*(.*)$/

#Sweet.View
#Represents an element in the UI.

class BaseClass
 constructor: ->
  @_init.apply @, arguments

 _initFuncs: []
#Register initializer funcitons
 @initialize: (func) ->
  @::_initFuncs = _.clone @::_initFuncs
  @::_initFuncs.push func

 _init: ->
  for init in @_initFuncs
   init.apply @, arguments

#Include objects
 @include: (obj) ->
  for k, v of obj when not @::[k]?
   @::[k] = v


class View extends BaseClass
 @initialize ->
  @_viewId = _.uniqueId 'view'
  @_setupElement()

 _events: {}
 _attrs: {}

# Register events
 @events: (events) ->
  @::_events = _.clone @::_events
  for k, v of events
   @::_events[k] = v

#Register attributes
 @attributes: (attributes) ->
  @::_attrs = _.clone @::_attrs
  for k, v of attributes
   @::_attrs[k] = v

 tagName: 'div'
 $: (selector) -> @$el.find selector

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

optionalParam = /\((.*?)\)/g
namedParam    = /(\(\?)?:\w+/g
splatParam    = /\*\w+/g
escapeRegExp  = /[\-{}\[\]+?.,\\\^$|#\s]/g

class Router extends BaseClass
 @initialize ->
  @_bindRoutes()
  @_event = null
  @_history = []

 _routes: {}

 @routes: (routes) ->
  @::_routes = _.clone @::_routes
  for k, v of routes
   @::_routes[k] = v

 start: (options) ->
  Sweet.history.start options
  fragment = Sweet.history.getFragment()

  if options?.silent is on
   @_history.push fragment: fragment, title: document.title

 back: ->
  if @_history.length > 1
   Sweet.history.back()

 canBack: ->
  if @_history.length > 1 and Sweet.history.canBack()
   return true
  else
   return false

 route: (route, name) ->
  (route = @_routeToRegExp route) if not _.isRegExp route

  Sweet.history.route route, (fragment, event) =>
   args = @_extractParameters route, fragment
   @_event = event
   if @_event?.type is "popstate"
    @_history.pop()
    if @_history.length is 0
     @_history.push fragment: fragment, title: document.title, state: @getState()
   else
    @_history.push fragment: fragment, title: document.title, state: @getState()

   callbacks = name
   callbacks = [callbacks] if not Array.isArray callbacks

   for callback in callbacks
    callback = @[callback]
    break unless callback.apply this, args

 getState: ->
  if @_event?.originalEvent?.state?
   return @_event.originalEvent.state
  else
   return null

 navigate: (fragment, options) ->
  options = {} unless options
  if options.replace
   @_history.pop()
  if not options.trigger
   @_history.push fragment: fragment, title: options.title, state: options.state

  Sweet.history.navigate fragment, options

 #Most general at top
 _bindRoutes: ->
  for route, name of @_routes
   @route route, name

 # Convert a route string into a regular expression, suitable for matching
 _routeToRegExp: (route) ->
  route = route.replace(escapeRegExp, '\\$&')
               .replace(optionalParam, '(?:$1)?')
               .replace(namedParam, (match, optional) ->
                 if optional then match else '([^\/]+)'
               )
               .replace(splatParam, '(.*?)')

   return new RegExp "^#{route}$"

 # Given a route, and a URL fragment that it matches, return the array of
 # extracted decoded parameters. Empty or unmatched parameters will be
 # treated as `null` to normalize cross-browser behavior.
 _extractParameters: (route, fragment) ->
  params = route.exec(fragment).slice(1)
  return _.map params, (param) ->
   if param then decodeURIComponent(param) else null


# Handles cross-browser history management, based on either
# [pushState](http://diveintohtml5.info/history.html) and real URLs, or
# [onhashchange](https://developer.mozilla.org/en-US/docs/DOM/window.onhashchange)
# and URL fragments. If the browser supports neither (old IE, natch),
# falls back to polling.

# Cached regex for stripping a leading hash/slash and trailing space.
routeStripper = /^[#\/]|\s+$/g

#Cached regex for stripping leading and trailing slashes.
rootStripper = /^\/+|\/+$/g

#Cached regex for detecting MSIE.
isExplorer = /msie [\w.]+/

#Cached regex for removing a trailing slash.
trailingSlash = /\/$/

#Cached regex for stripping urls of hash and query.
pathStripper = /[?#].*$/

class History extends BaseClass
 @initialize ->
  @handlers = []
  _.bindAll this, 'checkUrl'
  @history = window.history
  @location = window.location

 interval: 50,

 # Gets the true hash value. Cannot use location.hash directly due to bug
 # in Firefox where location.hash will always be decoded.
 getHash: ->
  match = @location.href.match /#(.*)$/
  return (if match? then match[1] else '')

 #Get the cross-browser normalized URL fragment, either from the URL,
 # the hash, or the override.
 getFragment: (fragment, forcePushState) ->
  if not fragment?
   if @_hasPushState or not @_wantsHashChange or forcePushState
    fragment = @location.pathname
    root = @root.replace trailingSlash, ''
    if not fragment.indexOf root
     fragment = fragment.slice root.length
   else
    fragment = @getHash()

  return fragment.replace routeStripper, ''

 back: ->
  @history?.back?()

 canBack: -> @history?.back?

 #Start the hash change handling, returning `true` if the current URL matches
 #an existing route, and `false` otherwise.
 start: (options) ->
  History.started = true

  @options = _.extend {root: '/'}, @options, options
  @root = @options.root
  @_wantsHashChange = @options.hashChange isnt off
  @_wantsPushState = @options.pushState is on
  @_hasPushState = @options.pushState is on and @history?.pushState?

  @fragment = @getFragment()

  # Normalize root to always include a leading and trailing slash.
  @root = "/#{@root}/".replace rootStripper, '/'

  # Depending on whether we're using pushState or hashes, and whether
  # 'onhashchange' is supported, determine how we check the URL state.
  if @_hasPushState
   $(window).on 'popstate', @checkUrl
  else if @_wantsHashChange and window.onhashchange?
   @(window).on 'hashchange', @checkUrl
  else if @_wantsHashChange
   @_checkUrlInterval = setInterval @checkUrl, @interval

  if not @options.silent
   @loadUrl null, null

 #Add a route to be tested when the fragment changes. Routes added later
 #may override previous routes.
 route: (route, callback) ->
  @handlers.unshift route: route, callback: callback

 # Checks the current URL to see if it has changed, and if it has,
 # calls `loadUrl`
 checkUrl: (e) ->
  fragment = @getFragment()
  return if fragment is @fragment
  @loadUrl fragment, e

 #Attempt to load the current URL fragment. If a route succeeds with a
 # match, returns `true`. If no defined routes matches the fragment,
 # returns `false`.
 loadUrl: (fragment, e) ->
  fragment = @fragment = @getFragment fragment
  return _.any this.handlers, (handler) ->
   if handler.route.test fragment
    handler.callback fragment, e
    return true
   else
    return false

 # Save a fragment into the hash history, or replace the URL state if the
 # 'replace' option is passed. You are responsible for properly URL-encoding
 # the fragment in advance.
 #
 # The options object can contain `trigger: true` if you wish to have the
 # route callback be fired (not usually desirable), or `replace: true`, if
 # you wish to modify the current URL without adding an entry to the history.
 navigate: (fragment, options) ->
  return false if not History.started

  fragment = @getFragment(fragment or '')
  url = @root + fragment

  #Strip the fragment of the query and hash for matching.
  fragment = fragment.replace pathStripper, ''

  return if @fragment is fragment
  @fragment = fragment

  # Don't include a trailing slash on the root.
  if fragment is '' and url isnt '/'
   url = url.slice 0, -1

  #If pushState is available, we use it to set the fragment as a real URL.
  if @_hasPushState
   method = if options.replace then 'replaceState' else 'pushState'
   state = {}
   state = options.state if options.state?
   title = ''
   title = options.title if options.title?
   @history[method] state, title, url

  # If hash changes haven't been explicitly disabled, update the hash
  # fragment to store history.
  else if @_wantsHashChange
   @_updateHash @location, fragment, options.replace

  # If you've told us that you explicitly don't want fallback hashchange-
  # based history, then `navigate` becomes a page refresh.
  else
   return @location.assign url
  if options.trigger
   return @loadUrl fragment, null

 #Update the hash location, either replacing the current entry, or adding
 # a new one to the browser history.
 _updateHash: (location, fragment, replace) ->
  if replace
   href = location.href.replace /(javascript:|#).*$/, ''
   location.replace "#{href}##{fragment}"
  else
   location.hash = "##{fragment}"

window.Sweet = Sweet =
 View: View
 Router: Router

Sweet.history = new History
