---
layout: post
title: "Refactorer Future[Option[T]] : OptionT de Scalaz"
tags: [scala, play2, scalaz, programmation fonctionnelle, refactoring, craftsmanship]
comments: true
lang: fr
---

Dans [les]({% post_url 2015-02-03-refactorer-future-option-t %}) [précédents]({% post_url 2015-03-28-refactorer-future-option-t-exceptions %}) [articles]({% post_url 2015-05-13-refactorer_future_adhoc_monades %}), nous avons étudié 3 refactorings permettant d'améliorer la lisibilité de code manipulant le type `Future[Option[T]]`.

L'application du [principe de séparation des responsabilité]({% post_url 2015-02-03-refactorer-future-option-t %}) a permis une première amélioration, l'utilisation [d'exceptions métier]({% post_url 2015-03-28-refactorer-future-option-t-exceptions %}) est une solution dans certains cas mais sacrifie une partie de l'information de typage.

Finalement l'utilisation d'un type _ad hoc_ composant les propriétés d'une `Future` et d'une `Option` s'est avéré être un parfait complément à la séparation initiale.

Le seul défaut de cette dernière approche est le besoin de maintenir ce type et de construire un nouveau type pour chaque nouvelle composition: `FutureO` (`Future` et `Option`), `FutureL` (`Future` et `List`), etc. Ces types ne sont pas spécifiques à un projet et idéalement devraient être extraits dans une bibliothèque. Il s'avère qu'une telle bibliothèque existe déjà.

Dans cet article, le dernier de cette série, je vous propose un refactoring utilisant les `MonadTransformer` de Scalaz 7.x.

<!--more-->
Code
----

Le code pour cet article est disponible sur [github](https://github.com/jeantil/blog-samples) sous le tag `futureOption/4-optionT_scalaz` et dans la branche `futureOption`

`MonadTransformer`
-----
Je n'ai pas l'intention de me prêter au périlleux exercice qui consiste à essayer de définir ce que représente une `Monad`, d'autres s'y sont attelés et une [recherche google](https://www.google.fr/search?q=d%C3%A9finition+de+monade+programmation) vous fournira toute l'information que vous pourriez vouloir (et sans doute plus).

Les types _monadiques_ ont des propriétés intéressantes du point de vue de la composition. C'est parceque `Future` et `Option` peuvent être considérés comme des types monadiques que nous avons pu les composer pour créer `FutureO`.
D'un point de vue purement *pragmatique*[^1], on peut considérer que tout type qui respecte le contrat logique suivant est monadique :

```scala
Monad[A]{
  def this(a:A):Monad[A] //=> il faut un constructeur pour le type concret
  def map[B](f:A=>B):Monad[B]
  def flatMap[B](f:A=>Monad[B]):Monad[B]
  def filter(f:A=>Boolean):Monad[A]
}
```
Dans la bibliothèque standard de scala, les types `Option`, `Future`, `Try`, `String`, `Map`, `Seq`, et bien d'autres peuvent donc être considérés comme monadiques. Scalaz propose des alternatives monadiques à certains types de la bibliothèque standard qui ne sont pas compatibles avec l'interface (comme Either par exemple).

Si deux types sont compatibles avec le contrat ci-dessus, il est possible d'implémenter un `MonadTransformer` pour ces deux types. L'implémentation d'un tel type n'est pas forcément triviale, heureusement Scalaz propose déjà un grand nombre d'implémentations. Celle qui nous intéresse et qui permet de composer `Option` et `Future` s'appelle `OptionT`. Il permet en réalité de composer `Option` avec n'importe quelle type monadique.

Utiliser OptionT
-----

Nous allons remplacer le type `FutureO` du précédent article par `OptionT[Future, Article]`, commençons par la signature d'`ArticleRepository`

```scala
trait ArticleRepository {
  def findById(id: String): OptionT[Future,Article]
}
```

Mécaniquement, nous sommes amenés à changer l'implémentation pour que le code compile. Je conserve volontairement la variable `articleFO` pour continuer de mettre en évidence les types intermédiaires.

```scala
class FakeArticleRepository extends ArticleRepository {
  override def findById(id: String): OptionT[Future,Article] = {
    val articleFO:Future[Option[Article]] = id match {
      case "0"      => Future.successful( Option(Article("0", "good article", 10.0) ))
      case id @ "1" => Future.successful(None)
      case "2"      => Future.failed(new java.io.IOException("Connection lost !!") )
    }
    OptionT(articleFO)
  }
}
```

Dans `ArticleREST` le résultat de l'appel à `findById` est passé à la méthode `ResultMapper#toJsonResult`. La signature de cette dernière doit donc changer pour accepter une instance de `Option[Future,A]`.

```scala
def toJsonResult[A](subjectFuture: OptionT[Future,A][A])
                    (onNotFound : => Result,
                     onError:PartialFunction[Throwable, Result]=internalServerErrorHandler)
                    (implicit writer: Writes[A]): Future[Result] = {
   subjectFuture.map(jsonOk).getOrElse(onNotFound).recover(onError)
}
```

Le code d'`ArticleREST` n'a pas besoin de changer et la gestion des erreurs est la même que pour `FutureO`, par contre il manque une toute petite brique pour que le programme fonctionne :

```
[error] /Users/jean/dev/sdev/src/articles/futureOptions/app/mvc/ResultMapper.scala:41: could not find implicit value for parameter F: scalaz.Functor[scala.concurrent.Future]
[error]     subjectFuture.map(jsonOk).getOrElse(onNotFound).recover(onError)
[error]                      ^
[error] one error found
[error] (compile:compileIncremental) Compilation failed
[error] Total time: 6 s, completed 19 mai 2015 18:06:04
```

Il manque un paramètre implicite permettant de prouver à Scalaz qu'une Future est bien un Functor. Si vous utilisez une version de Scalaz supérieur à 7.1.x, il suffit d'ajouter l'import

```scala
  import scalaz.std.scalaFuture
```
pour les versions précédentes ou si vous souhaitez limiter au maximum le nombre d'implicites dans le _scope_, la définition suivante suffit :

```scala
  implicit val futureFunctor = new Functor[Future] {
      override def map[A, B](fa: Future[A])(f: (A) => B): Future[B] = fa.map(f)
  }
```
Dans les deux cas, l'ExecutionContext présent dans le _scope_ implicite sera utilisé pour construire la preuve que `Future` est bien un `Functor`.

Conclusion
----

L'utilisation du type `OptionT[Future,Article]` offre les même avantages que l'utilisation de FutureO, et va bien au-delà en généralisant cette composition à tous les types qui offrent un comportement monadique. Avantage supplémentaire, il n'est plus nécessaire de maintenir sa propre bibliothèque de types "pré composés", ceux-ci sont accessible directement par Scalaz.

Il est tout a fait possible de commencer par développer quelques types _ad hoc_ puis de les remplacer par des types de Scalaz en utilisant des alias de types et quelques imports. Ainsi lorsque le coût de maintenance ou le degré de répétition deviennent trop importants ou que Scalaz est importé pour d'autres raisons la migration se fait avec un minimum de modifications.
Scalaz souffre d'une image négative, l'utilisation d'opérateurs unicodes, l'utilisation massive d'implicites et la personnalité corrosive de certains de ses défenseurs y ont largement contribué.  
Cependant, il est maintenant possible d'utiliser les types que propose la bibliothèque de façon selective ce qui fait diminuer le coût d'entrée  de cette lib dans un projet.


[^1]: La véritable définition est mathématique et très formelle. Elle entraine régulièrement des débats sans fin à propos de types qui ne respectent pas tout à fait les lois monadique (par exemple Future et Try à cause des exceptions). Certes ces types ne sont pas parfaitement pur et il est possible qu'il existe des implémentations pures mais du point de vue de l'utilisateur ça n'a pas tant d'importance.
