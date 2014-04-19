---
layout: post
title: Gérer les Future[Option[T]], 2ème essai
categories: [test,omg]
tags: [scala, play2]
published: false
comments: true
locale: fr
---

Dans un précédent article, nous avons vu une première façon d'encapsuler la complexité associée à la manipulation de données embarquées dans un type Future[Option[T]] afin de nettoyer le code d'un web service. En conclusion, je vous avais indiqué que la solution présentée ne me satisfaisait pas. Nous allons voir aujourd'hui une seconde approche.

Rappel de la solution précédente
------------
La dernière fois nous avions, atteint le code suivant :

```scala
  def toJsonResult[A](subjectOptionFuture: Future[Option[A]],noneMsg: => String = "NotFound")
                             (implicit writer: Writes[A]): Future[SimpleResult] = {
    subjectOptionFuture.map {
      case Some(subject) => jsonOk(subject)
      case None          => jsonNotfound(noneMsg)
    }.recover {
      case e: Exception => jsonInternalServerError(e.getMessage, e)
    }
  }
```

Bien qu'aillant permis de gagner en lisibilité dans le code du controleur, je lui avais trouvé deux défauts:

- Mélange du traitement d'un cas d'erreur et d'un cas de succès
- Maintient de l'imbrication des types conteneurs

Il était une fois les exceptions
-------------

Dans le code présenté, la séparation entre le traitement du cas None et le traitement du cas Exception vient du fait que None n'est pas une exception, par conséquent la Future utilise le type Success pour wrapper le None. Dans certains cas, il peut être acceptable de considérer l'absence de valeur comme un réel cas d'erreur, cette absence devrait alors être représenté par une exception et non par None.

Je pense que c'est le cas dans notre exemple, pour rappel nous avions un repository renvoyant une Future[Option[Article]] lors d'une recherche par identifiant.

```scala
trait ArticleRepository {
  def findById(id: String): Future[Option[Article]]
}
```
L'absence d'une entité lors d'une interrogation par identifiant peut généralement être considéré comme une erreur, c'est d'ailleurs le cas dans de nombreux ORM synchrones.

Si l'on modélise l'absence d'entité pour un identifiant donné par l'exception suivante:

```scala
case class NotFoundException(msg:String, cause: Throwable) extends Exception
```
