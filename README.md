Sweet.JS
========

Sweet.JS is Inspired by Backbone, written in CoffeeScript, and much lighter.
Sweet.Base introduces class level `include` to support multiple inheritence.

Model
-----
Model is a simple class that would add default values to a key-value set. (similar to `$.extend`)

View
----
View has most of the functions in *Backbone.View* and also supports subclassing, where you can register new events and/or override events from parent classes.

Also multiple initializers can be registered, aiding subclassing.

Router
------
Similar to `Backbone.Router`. Supports `history.back()` and HTML5 history states, falls back to hash tags if HTML5 history is not available.
