---
title: "Benvenuto nel blog Momentum"
description: "Bozza di verifica della pipeline editoriale: questo articolo non è pubblicato e serve a testare schema, build e Worker."
pubDate: "2026-07-27"
draft: true
author: "Momentum"
category: "Annunci"
tags: ["momentum", "blog"]
---

## Una bozza di servizio

Questo articolo è la bozza seed della pipeline editoriale di Momentum:
resta con `draft: true`, quindi non genera nessuna pagina pubblica.

Serve a tre cose:

- verificare che lo schema della content collection sia rispettato;
- dare al Worker editoriale un esempio reale di frontmatter;
- testare la pubblicazione end-to-end senza toccare contenuti veri.

## Come si pubblica

Il Worker `momentum-blog-publisher` crea le bozze in questa cartella e,
solo dopo una conferma esplicita, cambia `draft: true` in `draft: false`.
Il commit su GitHub fa ripartire build e deploy del sito.
