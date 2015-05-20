---
layout: post
title: "Refactorer Future[Option[T]] : la composition par un type <i>ad hoc</i>"
tags: [scala, play2, programmation fonctionnelle, refactoring, craftsmanship]
comments: true
locale: fr
---

Dans les précedents articles, nous avons étudié comment améliorer la lisibilité de code manipulant le type `Future[Option[T]]` en appliquant [le principe de séparation des responsabilité]({% post_url 2015-02-03-refactorer-future-option-t %}) et en utilisant [des exceptions métier]({% post_url 2015-03-28-refactorer-future-option-t-exceptions %}).

Ces deux approches, relativement simples ont toutes deux montré des limites: la première mélange le traitement de cas d'erreurs avec le traitement de cas normaux, la seconde perd de l'information au niveau du système de type et nécessite une connaissance de précise de l'implémentation ou une documentation détaillée pour pouvoir être correctement manipulée.

Dans cet article je vous propose d'explorer une piste proposée par la programmation fonctionnelle: la composition du type Future et du type Option dans un type _ad hoc_.

<!--more-->
Code
----

Le code pour cet articles est disponible sur [github](https://github.com/jeantil/blog-samples) sous le tag `futureOption/3-type_ad_hoc` et dans la branche `futureOption`

Le type `FutureO`
-----

Il s'agit de créer un type représentant spécifiquement la composition d'une future et d'une option,qui conserve la sémantique de ces deux types et qui soit compatible avec une _expression for_.

Cette idée n'est pas nouvelle,  [Edofic](http://www.edofic.com/posts/2014-03-07-practical-future-option.html) et [Loic](http://loicdescotte.github.io/posts/scala-compose-option-future/) ont tout deux proposé une implémentation à laquelle j'ai ajouté le `withFilter` nécessaire pour supporter les conditions de garde dans les _expressions for_ ainsi que le getOrElse qui permet de fournir à l'option une valeur par défaut:

```scala
import scala.concurrent.{Future, ExecutionContext}

case class FutureO[+A](future: Future[Option[A]]) extends AnyVal {
  def flatMap[B](f: A => FutureO[B])(implicit ec: ExecutionContext): FutureO[B] = {
    val newFuture = future.flatMap{
      case Some(a) => f(a).future
      case None => Future.successful(None)
    }
    FutureO(newFuture)
  }

  def map[B](f: A => B)(implicit ec: ExecutionContext): FutureO[B] =
    FutureO(future.map(option => option map f))

  def filter(p: A => Boolean)(implicit ec: ExecutionContext): FutureO[A] =
    FutureO(future.map(_.filter(p)))

  final def withFilter(p: A => Boolean)(implicit executor: ExecutionContext): FutureO[A] =
    filter(p)(executor)

  def getOrElse[AA >: A](default: AA)(implicit executor: ExecutionContext):Future[AA] =
    future.map(_.getOrElse(default))
}
```

Utiliser `FutureO`
-----

La première étape pour utiliser notre type `FutureO` est de changer la signature d'`ArticleRepository`

```scala
trait ArticleRepository {
  def findById(id: String): FutureO[Article]
}
```

Mécaniquement, nous sommes amenés à changer notre implémentation pour que le code compile. J'en profite pour introduire la variable `articleFO` pour mettre en évidence les types intermédiaires.

```scala
class FakeArticleRepository extends ArticleRepository {
  override def findById(id: String): FutureO[Article] = {
    val articleFO:Future[Option[Article]] = id match {
      case "0"      => Future.successful( Option(Article("0", "good article", 10.0) ))
      case id @ "1" => Future.successful(None)
      case "2"      => Future.failed(new java.io.IOException("Connection lost !!") )
    }
    FutureO(articleFO)
  }
}
```

Dans `ArticleREST` le résultat de l'appel à `findById` est passé à la méthode `ResultMapper#toJsonResult`. La signature de cette dernière doit donc changer pour accepter une instance de `FutureO`.
Ce changement nous force également à changer la gestion d'erreur pour le cas `NotFound`. Nous n'avons plus d'exceptions donc la signature `PartialFunction[Throwable,Result]` ne peut plus s'appliquer. Nous la remplaçons par une valeur de type Result ce qui permet au code appelant de continuer de controler le resultat HTTP effectivement renvoyé au client du service. Voici la nouvelle implémentation :

```scala
def toJsonResult[A](subjectFuture: FutureO[A])
                    (onNotFound : => Result,
                     onError:PartialFunction[Throwable, Result]=internalServerErrorHandler)
                    (implicit writer: Writes[A]): Future[Result] = {
   subjectFuture.map(jsonOk).getOrElse(onNotFound).recover(onError)
 }

 def jsonNotFound(msg: String) = NotFound(Json.obj("reason" -> msg))
```

Le code appelant ne change que très peu, il suffit d'enlever le `case` de la `PartialFunction`.

```scala
def get(id: String) = Action.async { implicit request =>
  val articleFuture = articleRepository.findById(id)
  mvc.ResultMapper.toJsonResult(articleFuture)(
      mvc.ResultMapper.jsonNotFound(s"no article for $id")
  )
}
```

Conclusion
----

L'utilisation d'un type ad-hoc nous a permis de séparer le traitement logique du succès de celui de l'absence de valeur. Cette dernière bénéficie tout de même d'un traitement spécifique par rapport aux autres erreurs qui corresponds assez bien à la réalité métier de l'application. L'absence de valeur n'est pas une erreur technique mais une erreur métier.

Le type ad-hoc permet de composer facilement divers appels de service dans des _expressions-for_ comme dans le cas d'utilisation d'exceptions, mais au contraire des exceptions, le cas d'erreur métier lié à l'absence de la valeur n'est pas dissimulée dans les signatures de méthodes.

Le seul inconvénient de cette approche est de devoir créer et maintenir les différents types représentant les compositions ad-hoc utilisées dans le programme. Cette charge relativement faible peut devenir importante sur un projet de grande envergure.
