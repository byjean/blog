---
layout: post
title: "Git changelog "
tags: [git]
comments: true
lang: en
---

For a couple days I have needed to tell the team the changs contained in the last release of the backend code. Since each of our releases are tagged automatically thanks to our [painless-sbt-build] this is fairly straightforward. Today I automated a little bit more with 3 aliases added to my `~/.gitconfig` :

* `git currrent-tag` looks up the latest tag in the repository
* `git previous-tag` looks up the tag immediately before the latest tag in the repository
* `git changelog` displays only the changes between these two tags

The code for the aliases:

```sh
[alias]
current-tag= describe --abbrev=0 --tags
previous-tag= "!sh -c 'git describe --abbrev=0 --tags $(git current-tag)^'"
changelog = "!sh -c 'git --no-pager lg --first-parent $(git previous-tag)..$(git current-tag)'"
```
