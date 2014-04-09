---
layout: post
title: Proxifying play server behind grunt for full stack dev
categories: [scala, js]
tags: [scala, Play! 2, js]
date: 2013-11-18 14:00
published: true
comments: true
---

I like the idea of using the best tool for the job. As I write this the best tool for web frontend development is clearly a js stack. However it is still my belief that the server is better served by a strongly typed language (and I now also prefer statically typed). I currently work on a Play 2.2 application which uses a full js frontend. The problem is that js stacks are better served by grunt (or brunch) with  minification, concatenation, sourcemap, coffee compilation, livereload, etc. At the same time play is able to restart and recompile my play app without me needed to do anything.

Getting both to cooperate in dev mode without hitting the cross origin restrictions requires a proxy. Instead of using yet another tool in dev mode to do the proxyfication (I do recommand using such a tool in production though), I decided to have grunt proxify requests he wasn't able to handle.

It all starts with writing a quick proxy handler wich goes in your `Gruntfile.js`:

```js
var proxyHandler = function proxyHandler(){
  var httpProxy = require('http-proxy');
  var proxy = new httpProxy.RoutingProxy();
  return function proxyHandler(req, res, next){
    var buffer = httpProxy.buffer(req);
    setTimeout(function () {
      proxy.proxyRequest(req, res, {
        port: 9000, //
        host: 'localhost',
        buffer: buffer
      });
    }, 200);
  };
};
```
Beware, I hard coded the definition for the port and host, you may want to change these. Also make sure you have http-proxy installed with `npm install -s http-proxy`

Ensure your grunt connect server doesn't conflict with play's

```js
connect: {
  options: {
    port: 9001, // play defaults to 9000
    livereload: 35729,
    // change this to '0.0.0.0' to access the server from outside
    hostname: 'localhost',
    middleware: function(connect, options) {
      var middlewares = [];
      var directory = options.directory || options.base[options.base.length - 1];
      if (!Array.isArray(options.base)) {
        options.base = [options.base];  
      }
      options.base.forEach(function(base) {
        // Serve static files.
        middlewares.push(connect.static(base));
      });
      // Make directory browse-able.
      middlewares.push(connect.directory(directory));
      //has to be last since we don't use connect routing at all!
      middlewares.push(proxyHandler());
      return middlewares;
    }
  }
  ...
}
```

Finally make sure `'connect:livereload'` appears in the server task. You can now start play (using the run command) on port 9000 and grunt which will bind to 9001 and proxy any unknown request to 9000.

If you use the play-yeoman plugin all you have to do is to start your play app with run (you only have one terminal window :),since the plugin will also lauch grunt and its proxy.
