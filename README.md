# Cerulean Dreams

The player-facing wiki for the Cerulean Dreams campaign. Live at:
https://kraftykraft.github.io/cerulean-dreams/

## Editing

Everything at the root of this repo (except `.github/`, `Dockerfile`, and
this README) is content — click the pencil icon on any file on GitHub to
edit it, or add new `.md` files directly. Every push to `main` rebuilds
and republishes the site automatically.

## How this is built

This repo holds only content and a couple of small build files — the
[Quartz](https://quartz.jzhao.xyz/) site generator itself is never checked
in here. `.github/workflows/deploy.yaml` builds the `Dockerfile` on every
push to `main`, which clones Quartz fresh, drops this repo's content into
it, and publishes the result to GitHub Pages.
