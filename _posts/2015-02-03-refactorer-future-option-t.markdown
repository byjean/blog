---
layout: post
title: Refactorer Future[Option[T]]
tags: [scala, play2, refactoring,craftsmanship]
comments: true
locale: fr
---

Depuis quelques temps je travaille sur une application Play 2 en scala. Nos APIs d'accès aux données sont asynchrones et renvoient toutes des `Futures[T]`. Avec une telle API, on se retrouve vite avec des signatures de type `Future[Option[T]]`. Transformer proprement un tel résultat vers des réponses HTTP n'est pas forcément évident et peut amener de la duplication même dans des cas simples. Dans cet article nous allons voir une façon d'éviter ce problème.

Contexte
------
Partons d'un exemple simple et développons un micro-service qui expose des `Articles` au format JSON. Il ne permet que de lire le détail d'un article à partir de son identifiant en accédant à la ressource suivante :

```bash
GET /article/:id

```

Un article est un élément simple défini comme suit :

```scala
case class Article(id: String, name: String, price: BigDecimal)
object Article {  
  implicit val jsonFormat = play.api.libs.json.Json.format[Article]
}

```

Afin de lire un article depuis notre base de donnée, nous disposons d'un `Repository` asynchrone dont l'interface est la suivante :

```scala
trait ArticleRepository {
  def findById(id: String): Future[Option[Article]]
}
```

Make it work
-------
Partons d'une implémentation naïve de la ressource Play :

```scala
import play.api.libs.concurrent.Execution.Implicits._
import play.api.libs.json.Json

object ArticleController extends play.api.mvc.Controller {
  val articleRepository: ArticleRepository = ArticleRepositoryImpl

  def get(id: String) = Action.async { implicit request =>
    val articleOptionFuture = articleRepository.findById(id)
    articleOptionFuture.map(articleOption =>
      articleOption.map(article =>
        Ok(Json.toJson(article))
      ).getOrElse(NotFound(Json.obj("reason" -> s"no article for $id")))
    )
  }
}
```

Concentrons nous sur deux points :

* Un des cas de `articleOptionFuture` n'est pas géré. Si la `Future` est une `Failure` elle va remonter dans le framework. Celui-ci utilise un handler par défaut qui retourne une erreur 500 avec un contenu de type `text/html` en cas de `Failure`, quelque soit le type de contenu demandé par le client. Ici nous voudrions rester cohérents et toujours renvoyer un contenu de type `application/json`.
* La logique est difficile à comprendre en raison des imbrications.

Il est facile de corriger le premier point en interceptant la `Failure` pour renvoyer un message d'erreur JSON, toujours avec un code 500 :

```scala
object ArticleController extends play.api.mvc.Controller {
  val articleRepository: ArticleRepository = ArticleRepositoryImpl

  def exception2Location(exception: Exception): Option[String] =
    Option(exception.getStackTrace)
    .flatMap(_.headOption)
    .map(_.toString)
    .getOrElse("unknown")

  def jsonInternalServerError(msg: String, cause: Exception) = {
    val jsonMsg = Json.obj(
      "reason" -> msg,
      "location" -> exception2Location(cause)
    )
    InternalServerError(jsonMsg)
  }

  def get(id: String) = Action.async { implicit request =>
    val articleOptionFuture = articleRepository.findById(id)
    articleOptionFuture.map(articleOption =>
      articleOption.map(article =>
        Ok(Json.toJson(article))
      ).getOrElse(NotFound(Json.obj("reason" -> s"no article for $id")))
    ).recover {
      case e: Exception => jsonInternalServerError(e.getMessage, e)
    }
  }
}
```

Nous avons maintenant un service qui renvoie du JSON même en cas d'erreur, tout en conservant la sémantique des codes de retour HTTP.

Nous avons dû extraire des méthodes pour conserver un minimum de libilité. Ces méthodes n'ont pas l'air d'être spécifque à notre controller : elles ne manipulent aucunement les articles. Il est probables qu'elles ne soient pas à leur place, mais nous y reviendront plus tard.

*(Si vous êtes horrifés que je fasse du refactoring sans tests, rassurez-vous j'ai des tests mais ils ne sont pas l'objet de cet article)*

Make it right
-----
Le comportement de la méthode `get` est maintenant correct. Cependant la lecture reste difficile :

* imbrication des appels,
* grand nombre de parenthèses,
* mélange parenthèses/accolades,
* manque de séparation des responsabilités.

Procédons à un premier refactoring pour séparer la notion de mapping d'une valeur vers un résultat HTTP :

```scala
object ArticleController extends play.api.mvc.Controller {
  val articleRepository: ArticleRepository = ArticleRepositoryImpl

  def jsonOk(article:Article)=Ok(Json.toJson(article))

  def jsonNotfound(msg: String) = NotFound(Json.obj("reason" -> msg))

  def exception2Location(exception: Exception): Option[String] =
    Option(exception.getStackTrace)
    .flatMap(_.headOption)
    .map(_.toString)
    .getOrElse("unknown")

  def jsonInternalServerError(msg: String, cause: Exception) = {
    val jsonMsg = Json.obj(
      "reason" -> msg,
      "location" -> exception2Location(cause)
    )
    InternalServerError(jsonMsg)
  }

  def get(id: String) = Action.async { implicit request =>
    val articleOptionFuture = articleRepository.findById(id)
    articleOptionFuture.map( articleOption =>
      articleOption.map( article => jsonOk(article)
      ).getOrElse( jsonNotfound(s"no article for $id") )
    ).recover {
      case e: Exception => jsonInternalServerError(e.getMessage, e)
    }
  }
}
```

Ce refactoring améliore un peu les choses mais `get` reste difficile à lire.

La syntaxe abbrégée de scala pour les fonctions de mapping n'aide pas vraiment :

```scala
  def get(id: String) = Action.async { implicit request =>
    val articleOptionFuture = articleRepository.findById(id)
    articleOptionFuture.map(
      _.map(jsonOk).getOrElse(jsonNotfound(s"no article for $id"))
    ).recover {
      case e: Exception => jsonInternalServerError(e.getMessage, e)
    }
  }
```

Une autre alternative est le pattern matching :

```scala
def get(id: String) = Action.async { implicit request =>
    val articleOptionFuture = articleRepository.findById(id)
    articleOptionFuture.map {
      case Some(article) => jsonOk(article)
      case None          => jsonNotfound(s"no article for $id")
    }.recover {
      case e: Exception => jsonInternalServerError(e.getMessage, e)
    }
  }
```

Je trouve cette forme plus facile à lire. Il saute aux yeux que la fonction gère 1 cas de succès et 2 cas d'erreurs. les cas d'erreur ne sont pas gérés ensemble c'est l'une des limites de ce refactoring.

C'est regrettable car les 2 cas d'erreur ne dépendent pas vraiment de la resource, ils sont assez génériques. Nous pouvons tout de même extraire la responsabilité de transformer un résultat (succès ou échec) en JSON dans une classe spécialisée :

```scala
import play.api.libs.concurrent.Execution.Implicits._
import play.api.libs.json.Json
import scala.concurrent.Future

object JsonResultMapper extends Results {
  import play.api.libs.json.Writes

  def jsonOk[A](subject: A)(implicit writer: Writes[A]) = Ok(Json.toJson(subject))

  def jsonNotfound(msg: String) = NotFound(Json.obj("reason" -> msg))

  def exception2Location(exception: Exception): String =
    Option(exception.getStackTrace)
      .flatMap(_.headOption)
      .map(_.toString)
      .getOrElse("unknown")

  def jsonInternalServerError(msg: String, cause: Exception) = {
    val jsonMsg = Json.obj(
      "reason" -> msg,
      "location" -> exception2Location(cause)
    )
    InternalServerError(jsonMsg)
  }

  def toJsonResult[A](subjectOptionFuture: Future[Option[A]],noneMsg: => String = "NotFound")
                             (implicit writer: Writes[A]): Future[SimpleResult] = {
    subjectOptionFuture.map {
      case Some(subject) => jsonOk(subject)
      case None          => jsonNotfound(noneMsg)
    }.recover {
      case e: Exception => jsonInternalServerError(e.getMessage, e)
    }
  }
}
```

et notre ressource devient alors :

```scala
object ArticleController extends play.api.mvc.Controller {
  val articleRepository: ArticleRepository = ArticleRepositoryImpl

  def get(id: String) = Action.async { implicit request =>
    val articleOptionFuture = articleRepository.findById(id)
    JsonResultMapper.toJsonResult(articleOptionFuture, s"no article for $id")
  }
}
```

Conclusion
----

Nous avons amélioré notre code initial, extrait une fonctionnalité transverse et fortement gagné en lisibilité dans la resource. Celle ci n'a désormais pour responsabilité que de coordonner le chargement de l'article et de demander la transformation en JSON au service correspondant. Dans le cas d'un appel plus complexe, on pourrait effectuer la validation du format d'entrée et extraire l'appel du repository dans un service.

Cependant l'implementation `toJsonResult` du `JsonResultMapper` restent suspectes. Les cas d'erreurs ne sont pas traités dans le même bloc logique et utiliser le pattern matching pour "cacher" l'imbrication des appels à map fonctionne mais laisse également à désirer.
