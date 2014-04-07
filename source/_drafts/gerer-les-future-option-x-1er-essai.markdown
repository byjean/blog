---
layout: post
title: Gérer les Future[Option[T]] : 1er essai
categories: [test,omg]
tags: [scala, play2]
date: 2015-03-18 16:05
published: false
comments: true
locale: fr
---

Depuis quelques temps je travaille sur une application Play 2 en scala. Nos apis d'accès aux données sont asynchrones et renvoient toutes des `Futures[T]`. Avec une telle API, on se retrouve vite avec des signatures de type `Future[Option[T]]`. Transformer proprement un tel résultat vers des réponses HTTP propres n'est pas forcément évident et peut amener de la duplication même dans des cas simples. Dans cet article nous allons voir une première façon d'éviter ce problème.

Le service et son domaine
------
Partons d'un exemple simple et développons un micro-service qui expose des `Articles` au format JSON. Il ne permet que de lire le détail d'un article à partir de son identifiant en accédant à la ressource suivante :
```
GET /article/:id
```
Un article est un élément simple défini comme suit:
```scala
case class Article(id: String, name: String, price: BigDecimal)
object Article {  
  implicit val jsonFormat = play.api.libs.json.Json.format[Article]
}

```
Afin de relire un article depuis notre base de donnée, nous disponson d'un `Repository` asynchrone dont l'interface est la suivante :
```scala
trait ArticleRepository {
  def findById(id: String): Future[Option[Article]]
}
```
Une implémentation naïve
-------
Partons maintenant d'une implémentation naïve de notre ressource Play:
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
Cette implémentation présente des défauts mais concentrons nous sur deux points :
* Un des cas de articleOptionFuture n'est pas géré. Si la `Future` est une `Failure` elle va remonter dans le framework. Celui-ci utilise un handler par défaut qui retourne une erreur 500 avec un contenu de type `text/html` en cas de `Failure`, quelque soit le type de contenu demandé par le client. Ici nous voudrions rester cohérents et toujours renvoyer un contenu de type `application/json`.
* La logique est difficile à comprendre en raison des imbrications.

Essayons de corriger le premier problème en interceptant la `Failure` pour renvoyer un message d'erreur JSON toujours avec un code HTTP 500:
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
}```
Ca fonctionne ! Nous avons maintenant un service qui renvoie du JSON même en cas d'erreur, tout en conservant la sémantique des codes de retour HTTP. Par contre nous avons dû extraire des méthodes pour ne pas rendre le code absolument illisible. Ces méthodes n'ont pas l'air d'être spécifque à notre controller : elles ne manipulent aucunement les articles. Il est probables qu'elles ne soient pas à leur place, mais nous y reviendront plus tard.

Je suis certain que nombre de mes lecteurs sont absolument horrifés que je fasse du refactoring sans tests. Qu'ils se rassurent, j'ai des tests mais ils feront l'objet d'un prochain article.

Pour le moment concentrons nous sur la méthode `get`. Son comportement est maintenant correct mais elle n'est pas très lisible. L'imbrication des appels à map, le grand nombre de  parenthèses, le mélange parenthèses/accolades : difficile de s'en sortir !

Procédons à un premier refactoring pour séparer la notion de mapping d'une valeur vers un résultat HTTP:
```
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
C'est un peu mieux mais ça reste compliqué. Par curiosité, essayons la syntaxe abbrégée de scala pour les fonctions de mapping:
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
C'est une question de goût mais je trouve que ça n'améliore pas tant que ça la lisibilité, il y a un truc qui cloche mais difficile de dire quoi. Essayons le pattern matching :
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
Là encore question de goût mais je trouve ça plus facile à lire. Il est évident que le code gère 3 cas. En l'occurrence, 1 succès et 2 erreurs. Ces 3 cas ne sont pas gérés dans le même bloc, c'est dommage. Ce qui est plus regrettable encore c'est que nos 2 cas d'erreur ne sont pas regroupés, l'un est seul et l'autre avec le cas de succès.

C'est d'autant plus regrettable que ces 2 cas d'erreur ne dépendent pas vraiment de la resource, ils sont assez génériques (au message d'erreur près). Nous pouvons extraire un convertisseur générique qui pourrait ressembler à

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
et notre ressource deviendrait alors
```scala
object ArticleController extends play.api.mvc.Controller {
  val articleRepository: ArticleRepository = ArticleRepositoryImpl

  def get(id: String) = Action.async { implicit request =>
    val articleOptionFuture = articleRepository.findById(id)
    JsonResultMapper.toJsonResult(articleOptionFuture, s"no article for $id")
  }
}
```
