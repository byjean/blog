---
layout: post
title: "Painless release with SBT"
tags: [scala, sbt,craftsmanship,continuous integration]
comments: true
lang: en
---

As a developer, the only version which really matters is the SHA-1 of the commit from which a deployed artifact was built. It lets me quickly get the source code for this artifact back if a patch is needed.
However as a project stakeholder, I need human understandable versions to provide to users. by human understandable I mean strictly increasing and possibly semantically versioned.

In this article I am going to detail an SBT combo allowing for SHA-1 based continuous delivery to an integration environment. The combo then allows to easily promote from this integration environment to QA, PreProd and Production platforms, creating a human understandable version in the process.

- **edit -- Added missing bumper function for release version**
- **edit -- Bump sbt-git version, drop corresponding obsolete code (as it fixes [#89](https://github.com/sbt/sbt-git/issues/89) and [#67](https://github.com/sbt/sbt-git/issues/67))**
- **edit -- mention ExtraReleaseCommands.initialVcsChecksCommand based on a suggestion from the comment section**



<!--more-->

Starting point
-----
We start from a very basic play project with the following structure

```
.
├── app
│   └── eu
│       └── byjean
│           └── Health.scala
├── build.sbt
├── conf
│   ├── application.conf
│   ├── logback.xml
│   └── routes
├── project
│   ├── build.properties
│   └── play.sbt
└── test
    └── resources
```


sbt-buildinfo
-----

The first piece of the combo is to use the [sbt-buildinfo](https://github.com/sbt/sbt-buildinfo) plugin to encode the project version in the generated artifact.  

To add the build info plugin we will create a `buildinfo.sbt` in the project directory with the following content (feel free to change version number to upgrade to the latest release)

```scala
addSbtPlugin("com.eed3si9n" % "sbt-buildinfo" % "0.4.0")
```
The tree now looks like

```
.
├── app
│   └── eu
│       └── byjean
│           └── Health.scala
├── build.sbt
├── conf
│   ├── application.conf
│   ├── logback.xml
│   └── routes
├── project
│   ├── build.properties
│   ├── buildinfo.sbt
│   └── play.sbt
└── test
    └── resources
```


Then configure your build to use it by changing build.sbt to look like

```scala
lazy val `ultimate-build` = (project in file(".")).enablePlugins(PlayScala, BuildInfoPlugin)

buildInfoKeys := Seq[BuildInfoKey](name, version, scalaVersion, sbtVersion)
buildInfoPackage := "eu.byjean"
```

This will create an object called `BuildInfo` in the configured package. Using this object we can create a useful little endpoint in our app : `GET /health`.

We need to implement the `Health#check` method :

```scala
val isoDateTimeWrites = new Writes[org.joda.time.DateTime] {
  def writes(d: org.joda.time.DateTime): JsValue = JsString(d.toString(ISODateTimeFormat.dateTime()))
}
def check=Action { request =>
  val json = Json.obj(
    "version" -> BuildInfo.version,
    "timestamp" -> Json.toJson(DateTime.now())(isoDateTimeWrites),
    "reverse" -> routes.Health.check().absoluteURL(secure = true)(request)
  )
  Ok(json)
}
```

Is a good start. When calling this endpoint we get a small json payload with the version of the project:

```bash
$> http :9000/health
HTTP/1.1 200 OK
Content-Length: 112
Content-Type: application/json; charset=utf-8
Date: Fri, 10 Jul 2015 16:07:40 GMT

{
    "reverse": "https://localhost:9000/health",
    "timestamp": "2015-07-10T18:07:40.594+02:00",
    "version": "0.1-SNAPSHOT"
}
```

This call can be extended as the application grows. I usually add checks on external system availability, making the service return a failure code (I usually choose 502) if a critical system used by the app stops responding.

Now that we can display our own version, let's customize it.

sbt-git
-----

[sbt-git](https://github.com/sbt/sbt-git) is a very useful plugin, it will provide you with a nice prompt showing git information right there in sbt.
It can also derive the version of the project from the git history in various ways.

To enable it create a `git.sbt` file in the `project` directory with the following content (again check for newer versions):

```scala
addSbtPlugin("com.typesafe.sbt" % "sbt-git" % "0.8.5")
```

Your project tree should now look like

```
.
├── app
│   └── eu
│       └── byjean
│           └── Health.scala
├── build.sbt
├── conf
│   ├── application.conf
│   ├── logback.xml
│   └── routes
├── project
│   ├── build.properties
│   ├── buildinfo.sbt
│   ├── git.sbt
│   └── play.sbt
└── test
    └── resources
```

We need to enable at least the `GitVersioning` plugin, in my sample I also activate the `GitBranchPrompt` which I find very useful.

Change your build.sbt accordingly:

```scala
lazy val `ultimate-build` = (project in file(".")).enablePlugins(PlayScala, BuildInfoPlugin, GitVersioning, GitBranchPrompt)
```
enables both plugins.

Now we can configure the versioning system. We need to choose a versioning scheme which is compatible with both SHA-1 based versioning for developers and semantic versioning for stakeholders.

The default scheme in sbt-git looks at the project tags. The first to match the `gitTagToVersionNumberSetting` is used to assign the version. If you tag
your app `v1.0.1` it will pick it up, that commit associated to the tag will have the SBT version set to `1.0.1`, it you make local changes it will become `1.0.1-SNAPSHOT`.
Upon the next commit, the version reverts to the base version suffixed by the SHA-1. This is fine if you are manually handling version bumps but not so nice if you want to automate releases[^1].

This leads us to the second versioning scheme offered by sbt-git. This scheme simply uses the output of `git describe` as version. It can be activated by adding the following to `build.sbt`.

```scala
git.useGitDescribe := true
```
Using `useGitDescribe` has a few shortcomings :

* Non version related tags can interfere with sbt versioning.
* In my specific case,I want all versions which are not exactly a version tag to be considered `-SNAPSHOTS`

Luckily the versioning scheme is pretty easy to extend to eliminate these problems. First, make the version start somewhere :

```scala
git.baseVersion := "0.0.0"
```

Now to avoid accidental versioning issue from non version related tags and enforce my `-SNAPSHOT` rules :

```scala
val VersionRegex = "v([0-9]+.[0-9]+.[0-9]+)-?(.*)?".r
git.gitTagToVersionNumber := {
  case VersionRegex(v,"") => Some(v)
  case VersionRegex(v,"SNAPSHOT") => Some(s"$v-SNAPSHOT")  
  case VersionRegex(v,s) => Some(s"$v-$s-SNAPSHOT")
  case _ => None
}

```

This scheme yields the following versions in order:

* `0.0.0-SNAPSHOT`
* `0.0.0-xxxxx-SNAPSHOT` //with xxxxxx a SHA-1
* `1.0.0` // for a commit whose SHA-1 has been tagged with v1.0.0
* `1.0.0-2-yyyyy-SNAPSHOT` // for the second commit after the tag

These versions are compatible with both nexus rules if you deploy your binaries there and with semantic versioning rules while preserving SHA-1 information whenever it is necessary.

sbt-native-packager
-----

When releasing an application (as opposed to a library), it is beneficial to package it up and release the whole package. The [sbt-native-packager](https://github.com/sbt/sbt-native-packager) makes it easy to target various kinds of packages zip, tarball, dmg, rpm, deb you name it and it will package it for you. Such packages make the lives of anyone who needs to handle operations around the application much easier.

In a play application, which is what I used for this example, the plugin is configured by default and the `universal:packageBin` will produce a zip file of the project complete with a run script, all the jars, a config directory and a documentation directory with the scaladoc for the project. However the publish settings are left untouched and the package itself is not published.

Fortunately the plugin authors have that covered, adding the following line to your build will change the publish settings to add the binary package to the published artifacts:

```scala
import com.typesafe.sbt.packager.SettingsHelper._

publishTo := Some("temp" at "file:///tmp/repository")
makeDeploymentSettings(Universal, packageBin in Universal, "zip")
```

Here I choose to publish a zip, feel free to adjust that to your needs with the help of the [documentation](http://www.scala-sbt.org/sbt-native-packager/formats/index.html)

sbt-release
-----

The next step to the ultimate sbt build is to add the [sbt-release](https://github.com/sbt/sbt-release) plugin. As for the other plugins, create a `release.sbt` file in your project directory with the following content:

```scala
addSbtPlugin("com.github.gseitz" % "sbt-release" % "1.0.0")
```

Your project tree should then look like this :

```
.
├── app
│   └── eu
│       └── byjean
│           └── Health.scala
├── build.sbt
├── conf
│   ├── application.conf
│   ├── logback.xml
│   └── routes
├── project
│   ├── build.properties
│   ├── buildinfo.sbt
│   ├── git.sbt
│   ├── play.sbt
│   └── release.sbt
└── test
    └── resources
```

Now the plugin is present, lets configure it so it plays nice with our versioning scheme. By default the sbt-release plugin behaves kind of like the maven release plugin. It will :

* Check for SNAPSHOT dependencies and prevent the release if any are present.
* Ask for the release version and next development version (or use defaults if the `with-defaults` argument is used).
* Clean the project.
* Run the tests.
* Set the release version (computes the release version and reapplies the settings so the project's version is reloaded) and write it to the version file (version.sbt by default)
* Commit the version file.
* Tag the release.
* Build and publish the artifacts with the release version.
* Set the project's version to the next development version and write it to the version file.
* Commit the version file.
* Push all the changes.

All these steps are here to ensure a repeatable build. I think it lacks a test run with the release version applied to be an exact match for the maven release process. In our case though where the version is fully derived from the VCS, this is slightly overkill.

With our setup, if we want to be able to repeat a specific version build all we have to do is checkout the corresponding tag which will automatically set the version to the correct value. Additionally, writing the version to an SBT file will kill the SHA-1 based versioning scheme we were using.

Once again the plugin author made it easy to change the release steps so we can customize our build as we want. Here is the sequence I use :

* Check for SNAPSHOT dependencies and prevent the release if any are present.
* Ask for the release version and next development version (or use defaults if the `with-defaults` argument is used).
* Set the release version (computes the release version and reapplies the settings so the project's version is reloaded).
* Clean the project.
* Run the tests.
* Tag the release.
* Build and publish the artifacts with the release version.
* Push all the changes.

This way we do run the tests with the actual release version (some applications have tests which depend on the application version).

Tagging the release ensures we can repeat the build once the artifacts are published and the changes are pushed. If anything bad happens before the last step, just delete the local tag  if it was created and you are back to square one. No more messing with files to propagate the version.

The first thing we need is to redefine the steps to set the release and next development versions to avoid writing to the version file:

```scala
import sbtrelease._
// we hide the existing definition for setReleaseVersion to replace it with our own
import sbtrelease.ReleaseStateTransformations.{setReleaseVersion=>_,_}

def setVersionOnly(selectVersion: Versions => String): ReleaseStep =  { st: State =>
  val vs = st.get(ReleaseKeys.versions).getOrElse(sys.error("No versions are set! Was this release part executed before inquireVersions?"))
  val selected = selectVersion(vs)

  st.log.info("Setting version to '%s'." format selected)
  val useGlobal =Project.extract(st).get(releaseUseGlobalVersion)
  val versionStr = (if (useGlobal) globalVersionString else versionString) format selected

  reapply(Seq(
    if (useGlobal) version in ThisBuild := selected
    else version := selected
  ), st)
}

lazy val setReleaseVersion: ReleaseStep = setVersionOnly(_._1)
```

Next we need to change slightly the way the release version is computed. Sbt-git derives the version number directly from the tag which means our _snapshot_ builds numbered `1.0.0-x-gyyyyyy-SNAPSHOT` is actually destined to be released as `1.0.1` not as `1.0.0` (since the `1.0.0` is derived from an existing tag). We need to change the release version computation logic slightly :

```scala
releaseVersion <<= (releaseVersionBump)( bumper=>{
   ver => Version(ver)
          .map(_.withoutQualifier)
          .map(_.bump(bumper).string).getOrElse(versionFormatError)
})
```

Finally you need to decide if you want to push the default build artifacts (usually a jar) which is the right choice for a library, or the packaged artifacts which is most likely what you want for an application. Then you can override the `releaseProcess` to match your need.

Below is a sample release process for an application, to switch it to a library you would uncomment the publishArtifacts and comment the next line which is used to publish the package from the Universal namespace.

```scala
releaseProcess := Seq(
  checkSnapshotDependencies,
  inquireVersions,
  setReleaseVersion,
  runTest,
  tagRelease,
 // publishArtifacts,
  ReleaseStep(releaseStepTask(publish in Universal)),
  pushChanges
)
```

With all this, releasing a bugfix can be done with the following command line :

```bash
sbt release with-defaults
```

Changing the default version bump from bugfix to minor is just a matter of changing `releaseVersionBump` to the appropriate settings for you.

In the comments, Loki mentionned that you may want to add the following step to your release process:

```scala
releaseStepCommand(ExtraReleaseCommands.initialVcsChecksCommand),
```
This step will ensure that you don't have uncommitted changes in your workspace. Having uncommitted changes while releasing would break the repeatable build. A  checkout of the tag in a fresh clone of the repository would not have the uncomitted changes and might result in a different binary. I didn't mention this initially because our process is to trigger releases on a CI server which starts by doing a clone from scratch in a temporary workspace. If your release process isn't as strict, adding the `initialVcsChecksCommand` step at the beggining of your release process is definitely a good idea.

Conclusion
-----

We now have an SBT build which delegates versioning to git, packages applications as a deployable zip file, tags the release automatically and publishes it to your company's artifact repository before pushing the tag on your remote git server in a single command. At the same time, every package built is versioned with the SHA-1 of the HEAD which was checked out to build it. You will find the complete project's [code on github](https://github.com/jeantil/blog-samples/tree/painless-sbt-build).

You might wonder where the buildinfo plugin I introduced initially comes in ? Having the binary package be able to report its own version enables relatively simple package promotion schemes.

Imagine the development package is continuously built and deployed to an integration platform, promoting a build to the QA platform is simple : fetch the version from the deployed instance in integration, parse it to extract the SHA-1, check it out and tag the release.

Promoting from QA to pre-prod or prod is even simpler : fetch the version from the QA platform, fetch the deployable package from the artifacts repository and deploy it to the target environment. But that's a story for another post.


[^1]: This might change in the future, follow [sbt-git#93](https://github.com/sbt/sbt-git/issues/93) for more
