---
layout: post
title: Hierarchy adaptation kata
category: java
tags: [kata, java, craftsmanship]
date: 2013-08-27 14:43
published: false
---

###Kata
{% blockquote %}
a system of individual training exercises for practitioners of karate and other martial arts.
{% endblockquote %}

A coding Kata is derived from the same principle except instead of the exercise being about martial arts, its about code. I exercise my coding skills on a regular basis, solving such exercises, trying to find variations on the solutions, etc. However, every kata I have tried has always struck me as being academic. By that I mean that it always seemed a bit too far from the problemes I have to solve on actual projects for actual clients.

The hierarchy adaptation kata attempts to capture a problem I have encountered multiple times in entreprise projects coded in java, it is extracted from a real-world application. The problem is very well known : for some reason (any reason really) you have two parallel class hierarchies and you want to convert for one to the other, or the other way around or both. In a classic java web application you would have the persistence model and the client model (webservice, REST, ...), you can also have the domain model. Some other occurrences can be less obvious : you use a complex library wich exposes a domain of its own but you don't want to have dependencies on it all over your code, some business requirements make you duplicate data because it has at least two different and incompatible life cycles,...

At first your models are simple and converters work out just fine, but soon you end up with inheritance in your models or conversion starts requiring access to external services, and your code starts to accumulate smells. You end up considering frameworks like [Dozer](http://dozer.sourceforge.net/).

Dozer is indeed a possible solution, but it also has limitations. It can require a lot of configuration, it uses reflection for runtime mapping which can cause performance problems. It can be deemed *heavy* to integrate at the beggining of a project. I believe other solutions are worth investigating too.

When exercising on this kata, here are a few points worth paying attention to: 
- Do not create package dependency cycles
- Keep your code testable (Be careful with static ;) ) 
- Do not use unchecked casts

In your first attempts, try to actually write the conversion code yourself, later you can try and integrate Dozer to see what it brings you, you can also try and remove the double hierarchy keeping only one. 

There are *integration* tests to make sure you actually solve the problems, there are also *unit* tests for the provided code.

You can find the Kata in [my github](https://github.com/jeantil/adaptation_kata), make sure you read the [README](https://github.com/jeantil/adaptation_kata/blob/master/README.md). I welcome any contributions be they improvements on the subject, solution proposals or improvements on the existing solutions.
