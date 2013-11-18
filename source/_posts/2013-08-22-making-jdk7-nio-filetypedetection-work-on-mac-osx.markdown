---
layout: post
title: Making JDK7 nio FileType detection work on OSX
category: java
tags: [bugs, java, workaround]
date: 2013-08-22 18:45
published: true
comments: true
---

JDK 7 introduced NIO.2 and the `java.nio.file` package, within it came the Files featuring a very interesting method : `probeContentType(Path path)`. Mime type detection is always a pain, thus having a simple way to do it in the JDK is a very interesting feature indeed. Unfortunately, on Mac OS X, this feature is broken (see my [gist](https://gist.github.com/jeantil/6306467) for a test program). 

As the [javadoc for probeContentType](http://docs.oracle.com/javase/7/docs/api/java/nio/file/Files.html#probeContentType\(java.nio.file.Path\)) explains, mime type detection is based on having a FileTypeDetector installed. The default one provided in JDK 7 is the `GnomeFileTypeDetector` [class](http://grepcode.com/file/repository.grepcode.com/java/root/jdk/openjdk/7-b147/sun/nio/fs/GnomeFileTypeDetector.java) and for some reason it won't pick up libgio even if it is installed on the system. Or at least, I haven't managed to get it to detect the lib, if you do I would love to hear from you in the comments. A [bug](http://bugs.sun.com/bugdatabase/view_bug.do?bug_id=7133484) was opened on this subject at Oracle but they decided to fix it only in jdk8 which is not yet released. I tried submitting a new bug report hoping to prompt Oracle to backport the JDK8's file detector to JDK7. I have little hope, so you can forget about `probeContentType`on OSX, unless ...

The FileTypeDetector mechanism uses SPI (Service Provider Interface) to allow for loading additional detection providers. I hacked JDK 8's [default provider](http://cr.openjdk.java.net/~alanb/7142921/webrev/src/solaris/classes/sun/nio/fs/MimeTypesFileTypeDetector.java.html) and created a small maven project to generate a jar which will register the provider with the JDK. Since this is platform specific issue and some of my coworkers use linux I didn't add the jar to my project dependencies. Instead I dropped it into my JDK7's `jre/lib/ext` folder. This way the jar is registered automatically whenever I use that JDK. 

The code can be found on [github](https://github.com/jeantil/jdk7-mimeutils). Hopefully I have respected the requirements of the JDK licensing by reproducing both the license and the copyright header. 

For the impatients, I made a branch with a [binary of the jar](https://github.com/jeantil/jdk7-mimeutils/raw/v1.0.0/lib/mimeutils.jar) and a sample [mime.types](https://github.com/jeantil/jdk7-mimeutils/raw/v1.0.0/mime.types) file lifted from some apache source repository and ready to be copied to `$HOME/.mime.types`.