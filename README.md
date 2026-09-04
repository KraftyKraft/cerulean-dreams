# Cerulean Dreams

The player-facing wiki for the Cerulean Dreams campaign. Live at:
https://kraftykraft.github.io/cerulean-dreams/

## Editing

Everything in this repo is content, except what's listed in
`.dockerignore` (build/config files, plus template files — see below).
Click the pencil icon on any file on GitHub to edit it, or add new
`.md` files directly. Every push to `main` rebuilds and republishes
the site automatically.

Links can be written simply as [[Page name]] or [[Page title]]. They are normalized
automatically when committing locally or after editing through GitHub.
Only the first link to the same page in an article is kept as a link;
later occurrences are converted to plain text.

When cloning the repo for local editing, run ./setup-hook.sh once.
This enables the repository's pre-commit hook, which automatically
normalizes Markdown links before each commit. Edits made directly on
GitHub are normalized by the deployment workflow instead.

### Templates

Some folders (e.g. `Spelarkaraktärer/`) have a `Mall.md` file — copy
it as a starting point for a new page in that category, so pages in
the same category stay consistent. Templates are committed to the
repo for contributors to use, but excluded from the published site.

## How this is built

This repo holds only content and a couple of small build files — the
[Quartz](https://quartz.jzhao.xyz/) site generator itself is never checked
in here. `.github/workflows/deploy.yaml` builds the `Dockerfile` on every
push to `main`, which clones Quartz fresh, drops this repo's content into
it, and publishes the result to GitHub Pages.
