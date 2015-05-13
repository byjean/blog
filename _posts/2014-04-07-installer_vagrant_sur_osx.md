---
layout: post
title: Installation facile de vagrant sur OSX
categories: [devops]
tags: [vagrant, virtualization, brew]
published: true
comments: true
---

J'ai eu l'occasion de travailler un peu avec [Vagrant](http://www.vagrantup.com) ces dernier temps. L'installation sur OS X peut être assez compliquée, je vous livre ici la recette la plus simple que j'ai trouvé.

Premièrement, installez Homebrew
--------

Si vous n'avez pas encore installé [Homebrew](http://brew.sh), il est grand temps de le faire. Je vous promet que vous ne le regretterez pas. Homebrew est très propre et installe ses logiciels dans `/usr/local/Cellar/` puis crée des liens symboliques vers les logiciels dans `/usr/local/bin`. Aucune "pollution" du système n'est a craindre.

L'installation de homebrew lui-même est très simple:

```bash
ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
```

Deuxièmement, installez Vagrant
--------

Avec Homebrew, installer vagrant devient facile:

```bash
brew update
brew tap phinze/homebrew-cask
brew install brew-cask
brew cask install vagrant
```

Troisièmement, il n'y a pas de troisièmement
---------
Félicitations! Vagrant est maintenant installé sur votre mac. Vous pouvez le vérifier en faisant:

```bash
 $ vagrant --version
Vagrant 1.5.1
```

Enjoy !
