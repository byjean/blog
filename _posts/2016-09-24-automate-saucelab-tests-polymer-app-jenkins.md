---
layout: post
title: "Polymer + saucelabs + jenkins"
tags: [polymer, js, gulp, saucelabs, jenkins]
comments: true
lang: en
---

To test polymer components, the recomended way is to use [web-component-tester](https://github.com/Polymer/web-component-tester) if you want to run your tests on multiple browsers, web-component-tester (wct) includes a [saucelabs plugin](https://github.com/Polymer/wct-sauce) by default. The problems start when you want to automatically run your tests after each push or after each realease.

<!--more-->

At work we use jenkins for continuous integration tasks, we naturally investigated how to automate our polymer tests from it. The saucelabs documentation on how to properly integrate selenium tests started from jenkins is [comprehensive](https://wiki.saucelabs.com/display/DOCS/Setting+Up+Sauce+Labs+with+Jenkins) but the bit on [`Setting Up Reporting between Sauce Labs and Jenkins`](https://wiki.saucelabs.com/display/DOCS/Setting+Up+Reporting+between+Sauce+Labs+and+Jenkins) assumes you have access to the low level webdriver instances:  

* to set the job name and job number you are expected to directly set them in the capabilites

  ```java
  DesiredCapabilities capabilities = new DesiredCapabilities();
  // ...
  capabilities.setCapability("build", System.getenv("JOB_NAME") + "__" + System.getenv("BUILD_NUMBER"));
  ```
* the let jenkins display the saucelabs tests results you have to make webdriver write a specific line to `stdout` or `stderr`

  ```js
  SauceOnDemandSessionID=<session id> job-name=<some job name>
  ```

Neither the capabilities nor the session id are readily accessible in `wct` or in `wct-sauce`.

However `wct-sauce` includes a [travis-specific integration](https://github.com/Polymer/wct-sauce/blob/master/lib/plugin.js#L111) to report job name and number. All you have to do to make it work from jenkins is set 2 environment variables `TRAVIS_JOB_NUMBER` and `TRAVIS_JOB_NAME` from the corresponding variables in jenkins.

Making webdriver write the correct line on one of the standard outputs is not so easy. You will have to write a `wct` plugin such as this one :

```js
module.exports = function(wct, pluginOptions, plugin) {
   wct.on('browser-end', function(def, error, stats, sessionId, browser) {
     wct.emit('log:info', 'SauceOnDemandSessionID=' + sessionId + ' job-name=' + process.env.BUILD_NUMBER);
   })
};
```

How to write a plugin is almost documented in the `wct`'s [readme](https://github.com/Polymer/web-component-tester#plugin-authoring). I couldn't find a reference documentation of the available events and had to go through the code to find the `browser-end` event published by [`wct`](https://github.com/Polymer/web-component-tester/blob/master/browser.js#L1702). As I write this, I am pretty sure it is the only event which contains the sessionId or a connected browser.

It is far from perfect : if the test times out or throws, there is a good chance that `browser-end` will not be emitted.

The next step is configuring the plugin in `wct` which is inferrable from the [readme](https://github.com/Polymer/web-component-tester#configuration) since plugins is plural it accepts a list of plugins, like this:

```
{
  "plugins": {
    "jenkins":{
      "disabled": false,
    }
    "sauce": {
      "disabled": true,
      "browsers": [...
      ]
    }
  }
}
```

The last step and most frustrating one for me was to get this all to work together. As it happens, just the `js` code isn't enough to make a `wct` plugin. You also need a line in a `package.json` somewhere. This is [documented in the readme](https://github.com/Polymer/web-component-tester#plugin-authoring) adding this was enough:

```json
{
  // ...
  "wct-plugin": {
      "cli-options": {
      }
    },
  // ...
}
```
Before you ask, no I have not tried removing the `cli-options` item. It's in the readme and that's the limit of my confidence and the time I have to waste on this. Feel free to comment if it works for you without.

Of course `package.json` means an npm module with its own directory (as far as I understand anyway, I'll be happy to be shown wrong). I placed all this in :

```
wct-jenkins
├── lib
│   └── plugin.js
└── package.json
```

So you need 6 lines of boilerplate in two separate files in their own directory structure to write a line to the standard output. Javascript tooling is amazing.
I have no intention of publishing and maintaining npm packages. After a bit more digging I found that if I could put it in the toplevel directory of my project the module it could be picked up by adding this to my project's `package.json`'s `devDependencies` section :

```
"wct-jenkins":"file:./wct-jenkins/",
```

Then I was able to load the module with a require at the top of the guplfile :

```
var wct_jenkins  = require('wct-jenkins');
```

The saucelabs results finally got displayed in the jenkins build.

I still feel this was harder than it should have been but at least it works. Any suggestions to simplify the process by a npm,gulp,wct,js specialist are more than welcome.
