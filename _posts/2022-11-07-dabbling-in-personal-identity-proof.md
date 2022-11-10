---
layout: post
title: "Dabbling in personal identity proof"
tags: [gpg, keyoxide]
lang: en
---

_I knew it had been a while since I last posted to my blog, but 6 years, damn! Time sure flies !_

As I followed the latest attempt at a twitter exodus to mastodon, I found myself immersed in a fresh timeline teeming with things I had somehow missed lately. One in particular caught my attention: decentralized identity proofs using [keyoxide](https://keyoxide.org/). 

I got interested in identity proofs when I joined keybase. I eventually went all-in with a semi-paranoid GPG setup[1] : 
- Master key generated and manipulated on an airgapped older IME-less laptop, using tails linux, stored on an encrypted USB stick
- Subkeys stored on yubikeys (3 actually : daily driver, cold spare for the daily driver, and an RFC enabled key for mobile usage)


But storing all my social network handles in my GPG key is painful, hence keyoxide ! 

The core idea is to verify claims of identity, the claims can be made using 2 protocols: 

- OpenPGP profiles notations with a `proof@ariadne.id=` prefix (the classic method)
- Signature profiles : essentially text files with a gpg signature containing claims with a `proof=` prefix.

In both cases keyoxide will parse the prefixed information, try to determine a custom provider for the provided claim and verify that the proof actually exists. The proof consists in placing the gpg key fingerprint with an `openpgp4fpr:` prefix in a known location for the corresponding service. 

Injecting the proof in GitHub requires creating a specific gist such as [this](https://gist.github.com/jeantil/d3bf3d2dba8eeaa9ce06bcda1206e459), for Twitter you will have to post a tweet, for mastodon to add a metadata to your profile, for gitlab to create a project with a specific description, etc.

The claims must match the service's verification provider expectations, and can be verified at  https://keyoxide.org/sig by copy and pasting the signed claims. 

This leaves the problem of distributing the signed claims. For now there is no obvious solution, I chose to add [the file](https://gist.github.com/jeantil/d3bf3d2dba8eeaa9ce06bcda1206e459#file-signature-profile) to the gist proof as that makes it easy to update for me and easy to reach for others.

[1] Maybe I'll write about this someday but this is all pretty well documented already.