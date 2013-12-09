SweetJS
========

SweetJS is inspired by Backbone, written in CoffeeScript, and much lighter.
It doesn't sync or handle events like Backbone.

Sweet.Base introduces class level `include` to support multiple inheritence.
Also you can subclass views and add new events and attributes from subclasses
without overriding parent class events.

Router suppoers `history.back()` and setting a state object. This lets you synchronize
browser back button and web app back button - this is needed specially on mobile devices since
browser toolbar dissapears.

SweetJS requires jQuery and Underscore.

Model
-----
Model is a simple class that would add default values to a key-value set.

View
----
View has most of the functions in *Backbone.View* and also supports subclassing, where you can register new events and/or override events from parent classes.

Also multiple initializers can be registered, aiding subclassing.

Router
------
Similar to `Backbone.Router`. Supports `history.back()` and HTML5 history states, falls back to hash tags if HTML5 history is not available.
