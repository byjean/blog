---
layout: post
title: Hierarchy adaptation kata
category: java
tags: [kata, java, craftsmanship]
date: 2013-05-30 09:53
published: false
---

Once upon a time, in a project far far away, The Architect made a decision. Having considered multiple options, he decided to make separate classes for the client visible model and the persistence model. Little did he know that he had just planted the seed which would one day lead to the most terrible of wars : The hierarchy adaptation war...

At first all was well, the models were simple, clients happily consumed the data. Soon the requirements began to change and The Architect beban to congratulate himself : with his strategy, he was able to change the exposed model and the persistent model at different rates 
