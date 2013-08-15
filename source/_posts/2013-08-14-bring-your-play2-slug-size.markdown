---
layout: post
title: Bring your Play! 2 Heroku slug size under control
categories: [scala, Play! 2]
tags: [heroku, scala, Play! 2, shell]
date: 2013-08-14 09:00
published: true
comments: true
---

I had been bothered by my Play! 2 apps slug size before, but never took the time to investigate. I couldn't understand why `sbt dist` would yield a 34MB zip while Heroku would end up with a > 100MB archive. While deploying an upgrate to Play! 2.1.3, I noticed it had bloated to 142MB: I had to act.

The current heroku buildpack uses `sbt clean compile stage` as its main command instead of `sbt dist`. I haven't tried to change that as I wanted something working fast, but I speculate it would be the best way to go for a Play! 2 app. 

I cloned the official [Heroku buildpack for scala](https://github.com/heroku/heroku-buildpack-scala), added some debug output in `bin/compile` through `du -sh ./*` and `find . \! -type d | xargs ls -Slh` to try and understand were the bloat was coming from. To configure a custom buildpack for you app, all you have to do is run the following command :
```bash
$ heroku config:set BUILDPACK_URL=https://github.com/jeantil/heroku-buildpack-scala.git
```

Here is the output from `du -sh ./*`:
```bash
4.0K	./.gitignore
8.0K	./.ivy2
77M		./.jdk
12K		./.profile.d
251M	./.sbt_home
4.0K	./.travis.yml
4.0K	./LICENSE
4.0K	./Procfile
8.0K	./README.md
92K		./app
32K		./conf
55M		./project
1.1M	./public
4.0K	./system.properties
44M		./target
56K		./test
```

My first reaction was : 55MB in project ?! Since I had run a find on the whole directory I was able to check out what was in project, looking only for MB sized artifacts. Here is what I found:

```bash
$ grep ./project deploy.log  | grep M
55M	./project
 14M Aug 15 08:19 ./project/boot/scala-2.10.0/lib/scala-compiler.jar
6.8M Aug 15 08:19 ./project/boot/scala-2.10.0/lib/scala-library.jar
3.1M Aug 15 08:19 ./project/boot/scala-2.10.0/lib/scala-reflect.jar
 11M Aug 15 08:19 ./project/boot/scala-2.9.2/lib/scala-compiler.jar
8.5M Aug 15 08:19 ./project/boot/scala-2.9.2/lib/scala-library.jar
1.2M Aug 15 08:19 ./project/boot/scala-2.9.2/org.scala-sbt/sbt/0.12.3/ivy-2.3.0-rc1.jar
2.0M Aug 15 08:19 ./project/boot/scala-2.9.2/org.scala-sbt/sbt/0.12.3/main-0.12.3.jar
1.1M Aug 15 08:23 ./project/target/streams/$global/update/$global/out
```

Keeping both versions of the scala *compiler* in the production slug is not really useful. I haven't tried to check why sbt would place this here on heroku and not on my development platform, but the first thing I added to my buildpack was : 

```bash
  if [ -d $BUILD_DIR/project/boot ] ; then
    echo "-----> Dropping project boot dir from the slug" 
    rm -rf $BUILD_DIR/project/boot  
  fi
```

