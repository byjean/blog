---
layout: post
title: Provisionner une machine virtuelle avec Vagrant
categories: [tips]
tags: [vagrant, web]
published: true
comments: true
locale: fr
---

Nous savons maintenant [installer vagrant sur osx](/2014/04/07/installer_vagrant_sur_osx/) et utiliser vagrant pour [construire une vm](/2014/04/09/construire-une-machine-virtuelle-Vagrant/). Ces derniers temps le nombre de technologies différentes utilisées dans les projets à augmenté. La philosophie "Best tool for the job", que je soutiens totalement, encourage cette prolifération.

Pourquoi Vagrant
-------

Cependant il y a un inconvénient à cette multiplication, certains outils ne s'installent pas facilement sur tous les environnements. Si l'on veut réduire la barrière à l'entrée sur un projet et amener les gens a essayer de nouveaux outils, il est préférable d'éliminer un maximum de barrières.

C'est là que Vagrant va nous aider, la personne qui "sait" comment installer va construire le fichier de définition de la VM, les autres lancent

```bash
git clone git://uberduper/project.git && vagrant up
```
puis vont boire un café pendant que vagrant leur prépare un environnement.

Comment provisionner la VM
--------

Nous avons déjà croisé le fichier de définition lors de la construction de la VM vide. Mais pour une VM vide nous ne nous étions pas penchés sur les directives de _provisioning_. Le fichier de définition peut en comporter plusieurs, chacune réfère a un type de _provisionner_ particulier : file, shell, ansible, ... Les types de _provisionner_ sont décrits de façon extensive [dans la documentation](http://docs.vagrantup.com/v2/provisioning/index.html), nous allons regarder un peu plus en détail un _provisioner_ shell.

Il faut commencer par le déclarer dans le fichier de définition :

```bash
PROVISION = "provisioning.sh"
PROVISION_ARGS = "vagrant"

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "precise64"

  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--cpuexecutioncap", "90", "--memory", "2048"]
  end

  config.vm.provision :shell do |s|
    s.path = PROVISION
    s.args = PROVISION_ARGS
  end

  config.vm.synced_folder ".", "/home/vagrant/website"  
end
```

En tout début de fichier sont déclarées deux variables qui définissent le nom du script shell de _provisionning_ et ses arguments, il n'est pas obligatoire de passer par des variables. Les lignes 15-17 déclarent un _provisioner_ de type shell qui va donc appeller le script shell provisioning.sh avec l'argument 'vagrant'

Exemple de script de _provisioning_
----------

Notre fichier de définition dépends d'une image `precise64` donc notre VM tournera sous ubuntu. Le script suivant effectue pour vous les tâches suivantes:
- capture le nom d'utilisateur qui lui est passé en tant que premier argument
- met à jour les dépôts apt de l'OS,
- ajoute un outil permettant d'ajouter des dépôts facilement,
- ajoute les dépôts permettant d'installer les jdks Oracle, et les dernières versions de redis,
- installe java 8 en acceptant la license automatiquement
- installe quelques outils utiles et redis-server
- configure redis
- installe elastic search
- install sbt
- se place dans dossier de dev et lance un premier sbt update

```bash
#!/usr/bin/env bash
USER=$1

apt-get update -y
apt-get upgrade -y
apt-get install -y python-software-properties
add-apt-repository -y ppa:webupd8team/java
add-apt-repository -y ppa:chris-lea/redis-server
apt-get update -y
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
apt-get install -y curl git gdebi-core oracle-java8-installer redis-server

cp /etc/redis/redis.conf /etc/redis/redis.conf.default
cp /home/vagrant/dev/conf/redis-devoxxfr.conf /etc/redis/redis.conf

cd /tmp
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.1.0.deb >/dev/null
gdebi -n elasticsearch-1.1.0.deb >/dev/null

wget http://dl.bintray.com/sbt/debian/sbt-0.13.2.deb >/dev/null
gdebi -n sbt-0.13.2.deb >/dev/null
service  elasticsearch start
service  redis start
cd /home/$USER/dev
su -l $USER -c "sbt update"
```
