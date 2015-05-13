---
layout: post
title: "Refactorer Future[Option[T]] : Les exceptions business"
tags: [scala, play2, refactoring, craftsmanship]
comments: true
locale: fr
---

Dans le [précedent article]({% post_url 2015-02-03-refactorer-future-option-t %}), nous avons vu comment mitiger les effets des signatures de type `Future[Option[T]]` sur la lisibilité du code. L'extraction d'un `ResultMapper` et l'utilisation du pattern matching ont permis de séparer les différentes problématiques du code initial.

En conclusion je faisait remarquer que la répartition des traitements succès/erreur dans le _mapper_ était suspecte. Elle devient problématique lorsque vous voulez coordonner plusieurs appels à des services ayant ce type de signature, le _happy path_ est alors pollué par l'extraction des valeurs dans les couches successives de type conteneurs.

Je vais maintenant montrer que l'utilisation d'exceptions métier est une façon de regrouper les cas d'erreurs dans le même bloc et de conserver un _happy path_ simple.

<!--more-->
Exception `ArticleNotFound`
-----

Notez que nous n'utilisons pas les exceptions métier en tant qu'exceptions mais en tant que valeurs. Elle ne sont pas utilisées avec `throw` et ne contournent donc pas le flot d'exécution normal du programme.

Pour marquer la différence entre les exceptions métier du projet et les exceptions classiques, créons un trait racine:

```scala
package support

import scala.util.control.NoStackTrace

trait BusinessException extends RuntimeException with NoStackTrace
```

Notez l'utilisation du trait NoStackTrace, fourni par la librairie standard de scala. Il permet d'éviter la coûteuse construction de la _stacktrace_ lors de la création d'un objet à partir d'une classe qui hérite de `java.lang.Throwable`.

```scala
object ArticleRepository{
  case class ArticleNotFound(id:String) extends BusinessException
}
```

Dans le code actuel, l'exception ArticleNotFound n'a de sens métier qu'au niveau du repository, elle est donc définie dans l'objet compagnon de celui-ci.

Retour à Future[Article]
------

Nous avons maintenant une valeur qui peut être placée dans un `Future.failed` et qui dénote de l'absence d'un article. Nous pouvons donc changer la signature du repository:

 ```scala
 trait ArticleRepository {
   def findById(id: String): Future[Article]
 }
 ```

Notez que cette signature est celle qu'expose _notre_ façade pour le repository. Dans le cadre de l'article nous contrôlons également l'implémentation, mais dans le cas contraire c'est la façade qui se chargerait de faire l'adaptation entre la signature source et celle que nous désirons avoir (et, oui, il faut *toujours* encapsuler les services externes utilisé dans notre code ;) ).

Making it work
-------
Changer la signature du repository nous oblige à corriger les erreurs de compilations. Tout d'abord le `FakeArticleRepository` doit implémenter la nouvelle signature.

```scala
class FakeArticleRepository extends ArticleRepository {

  def findById(id: String): Future[Article] = {
    id match {
      case "0"      => Future.successful( Article("0", "good article", 10.0) )
      case id @ "1" => Future.failed( ArticleRepository.ArticleNotFound(id) )
      case "2"      => Future.failed( new java.io.IOException("Connection lost !!") )
    }
  }
}
```

Il suffit de changer le cas de l'id 1, en remplaçant `Future.sucessful(None)` par `Future.failed( ArticleRepository.ArticleNotFound(id) )`

Reste à corriger la signature de la méthode du `ResultMapper` qui acceptait une valeur de `Future[Option[T]]` et doit maintenant accepter une valeur de `Future[T]`. Dans un projet plus riche, il pourrait être utile de conserver les deux.

```scala
def toJsonResult[A](subjectFuture: Future[A], noneMsg: => String = "NotFound")
                     (implicit writer: Writes[A]): Future[Result] = {
    subjectFuture.map {
      case subject => jsonOk(subject)
    }.recover {
      case ArticleNotFound(id) => jsonNotfound(noneMsg)
      case e: Exception => jsonInternalServerError(e.getMessage, e)
    }
  }
```

Nous pouvons déplacer le traitement du cas où l'article n'existe pas dans le bloc recover (ce qui était la raison principale de cette réécriture). Le traitement du cas normal est donc séparé du traitement des cas d'erreur.

Le code compile et les tests repassent, nous allons pouvoir nettoyer un peu.

Make it right
-----

Dans le contrôlleur, nous avons une variable intermédiaire dont le nom est `articleOptionFuture` ce qui n'a plus de sens puisque le type `Option` n'est plus utilisé. Un petit re-nomage plus tard et le code devient :

```scala
class ArticlesREST(val articleRepository: ArticleRepository) extends Controller {
  def get(id: String) = Action.async { implicit request =>
    val articleFuture = articleRepository.findById(id)
    mvc.ResultMapper.toJsonResult(articleFuture, s"no article for $id")
  }
}
```

Rester à nettoyer `ResultMapper`, problématique plus conséquente:

```scala
  def jsonOk[A](subject: A)(implicit writer: Writes[A]) = Ok(Json.toJson(subject))

  def toJsonResult[A](subjectFuture: Future[A], noneMsg: => String = "NotFound")
                     (implicit writer: Writes[A]): Future[Result] = {
    subjectFuture.map(jsonOk(_)).recover {
      case ArticleNotFound(id) => jsonNotfound(noneMsg)
      case e: Exception => jsonInternalServerError(e.getMessage, e)
    }
  }
```

La signature de jsonOk impose l'utilisation des parenthèses et du `_` en raison de ses deux listes d'arguments. Le compilateur scala, ne permet pas de mettre la liste des arguments implicites en premier, ce qui permettrait de transformer notre méthode en fonction. Il est possible de contourner cette limitation de la façon suivante :

```scala
def jsonOk[A:Writes]: A => Result = (subject: A)=> Ok(Json.toJson(subject))

def toJsonResult[A](subjectFuture: Future[A], noneMsg: => String = "NotFound")
                   (implicit writer: Writes[A]): Future[Result] = {
  subjectFuture.map(jsonOk).recover {
    case ArticleNotFound(id) => jsonNotfound(noneMsg)
    case e: Exception => jsonInternalServerError(e.getMessage, e)
  }
}
```

Il reste cependant un problème de taille : notre solution actuelle introduit une dépendance directe entre le ResultMapper et le repository des articles.

On pourrait définir un trait `NotFoundException` dans le package support  où se trouve `BusinessException`.

```scala
trait NotFoundException extends BusinessException
```

mixer ce trait dans ArticleNotFound

```scala
object ArticleRepository{
  case class ArticleNotFound(id:String) extends NotFoundException
}
```
et écrire `toJsonResult` de la façon suivante :

```scala
def jsonOk[A:Writes]: A => Result = (subject: A)=> Ok(Json.toJson(subject))
def toJsonResult[A](subjectFuture: Future[A], noneMsg: => String = "NotFound")
                  (implicit writer: Writes[A]): Future[Result] = {
 subjectFuture.map(jsonOk).recover {
   case notFound:NotFoundException => jsonNotfound(noneMsg)
   case e: Exception => jsonInternalServerError(e.getMessage, e)
 }
}
```
Cette approche est assez restrictive, elle implique qu'une exception "NotFound" renverra nécessairement un code 404 avec un message. Cette réponse est peut être valide pour la plupart des APIs mais n'est pas nécessairement juste. Scala nous permet de faire beaucoup mieux !

Imaginons que la signature de `toJsonResult` soit la suivante :

```scala
def toJsonResult[A](subjectFuture: Future[A])
                   (onError: PartialFunction[Throwable, Result])
                   (implicit writer: Writes[A]): Future[Result]
```

L'implémentation de ArticlesREST pourrait alors passer la gestion d'erreur correcte de la façon suivante :

```scala
import mvc.ResultMapper
class ArticlesREST(val articleRepository: ArticleRepository) extends Controller {
  def get(id: String) = Action.async { implicit request =>
    val articleFuture = articleRepository.findById(id)
    toJsonResult(articleFuture){
      case ArticleNotFound(articleId) => jsonNotfound(s"no article for $articleId")
    }
  }
}
```

En fournissant un _handler_ par défaut nous pourrions conserver exactement la même implémentation, tout en offrant aux services qui le souhaitent la possibilité de gérer eux même tout ou partie des erreurs.

L'implémentation du ResultMapper pourrait proposer ces handlers par défaut :

```scala
def notFoundHandler(noneMsg: => String = "NotFound"): PartialFunction[Throwable, Result] = {
  case notFound: NotFoundException=> jsonNotfound(noneMsg)
}
val internalServerErrorHandler: PartialFunction[Throwable, Result] = {
  case e: Exception=> jsonInternalServerError(e.getMessage, e)
}
```

Et l'implémentation de `toJsonResult` devient alors :

```scala
def toJsonResult[A](subjectFuture: Future[A])
                  (onError: PartialFunction[Throwable, Result] = notFoundHandler() )
                  (implicit writer: Writes[A]): Future[Result] = {
 val defaultHandler = notFoundHandler() orElse internalServerErrorHandler
 subjectFuture.map(jsonOk).recover(onError orElse defaultHandler)
}
```

Une dernière amélioration pourrait être de faire de ResultMapper un trait qui soit mixé dans le controller plutôt que de l'exposer sous la forme d'un objet exterieur.

Conclusion
----

L'utilisation d'exceptions métier nous a permis de regrouper le traitement d'erreur et proposer des traitements par défaut tout en offrant la possibilité d'utiliser un traitement spécifique.  Utiliser les `expressions-for` sur les valeurs de retour des services permet de les composer facilement sans avoir N niveaux de conteneurs à traverser pour atteindre les valeurs à manipuler.

Cette approche a cependant un défaut important par rapport à la précédente : les types des services ne sont plus auto-suffisants. Une documentation des erreurs possibles et des exceptions correspondantes sera indispensable pour une bonne utilisation des services. Bien que notre utilisation des exceptions ne casse pas le flot du programme sur le plan technique, elle dissimule des informations importantes qui ne peuvent être retrouvées que par de la documentation.
