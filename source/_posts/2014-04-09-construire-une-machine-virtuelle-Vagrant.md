---
layout: post
title: Construire une machine virtuelle avec Vagrant
categories: [devops] 
tags: [vagrant,virtualization]
published: true
comments: true
locale: fr
---

Dans un [précédent billet](/2014/04/07/installer_vagrant_sur_osx/), nous avons vu comment installer vagrant facilement sur Mac OS X. Voyons maintenant comment l'utiliser pour démrrer une machine virtuelle simplement.

Construire une image vide
-------
Crééz vous un dossier pour le projet et placez vous dedans:

```bash
mkdir website
cd website
```

Crééz un fichier nommé `Vagrantfile` et ajoutez-y le contenu suivant:

```bash
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "precise64"

  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--cpuexecutioncap", "90", "--memory", "2048"]
  end

  config.vm.synced_folder ".", "/home/vagrant/website"  
end
```

Maintenant vous avez un `Vagrantfile` minimal, il va télécharger une image nommée `precise64` depuis le _Cloud_ ( en fait http://files.vagrantup.com/ ) et s'en servir pour créer une instance virtualbox _headless_ avec 2Go de RAM. L'image `precise64` est en fait une image contenant Ubuntu 12.04.4 (precise pangola) pré-installé.

Ce fichier vagrant va également configurer une synchronisation du dossier courant côté hôte (donc le dossier website créé plus haut) avec le dossier `/home/vagrant/website` dans la VM. Par défaut le dossier courant est mappé sur `/vagrant` dans la VM mais je préfère rester dans un sous dossier de `$HOME` sur l'hôte comme sur la vm.

( plus d'info sur la configuration de l'instance virtualbox sous-jacente sur http://www.virtualbox.org/manual/ch08.html#vboxmanage-modifyvm )

Manipuler l'état de la VM
--------
Nous sommes maintenants prêts à démarrer notre VM:

```bash
vagrant up
```

Cela devrait vous afficher quelque chose comme :

```bash
$ vagrant up
Bringing machine 'default' up with 'virtualbox' provider...
==> default: Importing base box 'precise64'...
==> default: Matching MAC address for NAT networking...
==> default: Setting the name of the VM: vagrant_default_1396680997107_72702
==> default: Clearing any previously set network interfaces...
==> default: Preparing network interfaces based on configuration...
    default: Adapter 1: nat
==> default: Forwarding ports...
    default: 22 => 2222 (adapter 1)
==> default: Running 'pre-boot' VM customizations...
==> default: Booting VM...
==> default: Waiting for machine to boot. This may take a few minutes...
    default: SSH address: 127.0.0.1:2222
    default: SSH username: vagrant
    default: SSH auth method: private key
    default: Error: Connection timeout. Retrying...
==> default: Machine booted and ready!
==> default: Checking for guest additions in VM...
    default: The guest additions on this VM do not match the installed version of
    default: VirtualBox! In most cases this is fine, but in rare cases it can
    default: prevent things such as shared folders from working properly. If you see
    default: shared folder errors, please make sure the guest additions within the
    default: virtual machine match the version of VirtualBox you have installed on
    default: your host and reload your VM.
    default:
    default: Guest Additions Version: 4.2.0
    default: VirtualBox Version: 4.3
==> default: Mounting shared folders...
    default: /vagrant => /private/tmp/vagrant
    default: /home/vagrant/website => /private/tmp/vagrant
```

Bravo, votre VM est démarrée, il reste à s'y connecter. Lors du démarrag, vous avez peut-être remarqué les lignes:

```bash
==> default: Forwarding ports...
    default: 22 => 2222 (adapter 1)
```

On se connecte donc en ssh sur la machine:

```bash
vagrant ssh
```

À l'issue de cette commande vous êtes dans un shell exécuté dans la machine virtuelle.

```bash
Welcome to Ubuntu 12.04 LTS (GNU/Linux 3.2.0-23-generic x86_64)

 * Documentation:  https://help.ubuntu.com/
Welcome to your Vagrant-built virtual machine.
Last login: Fri Sep 14 06:23:18 2012 from 10.0.2.2
vagrant@precise64:~$
```

Quittez ce shell, nous allons maintenant arrêter la VM:

```bash
vagrant halt
```

qui devrait vous afficher

```bash
==> default: Attempting graceful shutdown of VM...
```

Une dernière commande qui peut ête utile, supprimer la VM. Cela peut servir si vous décidez d'arrêter de travailler sur le projet ou si vous voulez recréer complètement la VM _from scratch_.

```bash
vagrant destroy
```

Cette commande va vous demander confirmation et si besoin arrêter la VM.

```bash
   default: Are you sure you want to destroy the 'default' VM? [y/N] y
==> default: Destroying VM and associated drives...
```

Félicitations! Vous êtes maintenant armé pour créer des machines virtuelles avec vagrant.
