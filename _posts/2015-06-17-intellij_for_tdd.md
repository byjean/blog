---
layout: post
title: "Improve your 'Test-First' experience with Intellij IDEA"
tags: [tooling, craftsmanship,tdd]
comments: true
lang: en
---

I recently helped friends create a koans-based exercise to introduce people to CQRS and event sourcing[^1]. I was tasked with creating the Java version of the exercise. Since the whole exercise was going to depend on the quality of the tests, we applied a test first approach.

I found it quite painful as I didn't see an obvious way to actually create a test without already having the corresponding class. I was able to create an empty class but it would force me to write a lot of boiler plate manually (all the test annotations and all the static imports manually).

I happened to discuss this with Yann Cebron from Jetbrains at [Devoxx France](http://devoxx.fr) who showed me a neat trick using file templates[^2].

If you go to the project tool window, select a package in the test folder and try to create a new file with the default configuration, you should see something like this : ![a screen capture of the new file menu in Intellij](/images/testfirsttip/new_file_default.png)

That's a lot of templates and there is nothing to create a Junit4 test, lets create one.

Select `edit file templates...` and you will reach a window with a green `+` sign click that, name it `Junit4` and paste the following code (or your own variation thereof) :

```
#if (${PACKAGE_NAME} && ${PACKAGE_NAME} != "")package ${PACKAGE_NAME};#end

import org.junit.Test;
import static org.junit.Assert.*;

public class ${NAME} {
  @Test
  public void test_${NAME}() throws Exception {

  }
}
```

Now save this and go back to the project tool window, select a package in the test folder and try to create a new file again. This time you should see the `Junit4` template.

This is nice and nifty but it can still be improved : there is an Intellij action called `from template` (you can find it with `find action...` which is cmd+shift+a on mac)

Using this action only custom templates applicable will be displated, in a test directory for a mixed scala/java project it will show a much smaller menu making it even easier to create your test first.

![a screen capture of the `from template` menu in Intellij ](/images/testfirsttip/from_template.png)

[^1]: You can find the exercise at http://github.com/devlyon/mixter.
[^2]: This feature has been broken in a few Intellij builds and the user templates wouldn't show up in the menu, see the corresponding [issue on youtrack](https://youtrack.jetbrains.com/issue/IDEA-139126).
