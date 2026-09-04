# Markdown normalization tools

This directory contains the Markdown normalization tooling used by the
Cerulean Dreams wiki.

The formatter is intentionally implemented using POSIX shell and AWK so
contributors do not need Python, Node.js, Go, or another runtime installed.
Git for Windows provides the shell environment required by the hook, while
Linux and macOS normally provide the required tools directly.

## Files

- `format-wikilinks.sh` — main entry point and Git/file orchestration.
- `format-wikilinks.awk` — Markdown text transformation and wikilink resolution.
- `format-wikilinks.cmd` — Windows convenience wrapper for manually running
  the formatter from Command Prompt or PowerShell.

The local pre-commit hook is stored separately in:

```text
.githooks/pre-commit
```

## Processing modes

### `--all`

```bash
./tools/format-wikilinks.sh --all
```

Processes all tracked Markdown content in the repository.

Use this for:

- initial repository normalization
- testing formatter changes
- occasional full-repository cleanup
- manually reapplying normalization rules

### `--staged`

```bash
./tools/format-wikilinks.sh --staged
```

Processes only Markdown files currently staged for commit.

This mode is normally invoked automatically by `.githooks/pre-commit`.

Files changed by the formatter are automatically re-staged.

If a Markdown file contains both staged and unstaged changes, formatting is
aborted rather than staging unrelated working-tree changes.

### `--changed`

```bash
./tools/format-wikilinks.sh --changed <base-ref> <head-ref>
```

Processes Markdown files changed between two Git revisions.

This mode is used by GitHub Actions for pushed commits and edits made through
the GitHub web interface.

Example:

```bash
./tools/format-wikilinks.sh --changed HEAD~1 HEAD
```

## Wikilink resolution

Authors are expected to write the shortest useful link form:

```markdown
[[Roland Corveaux]]
[[Morbejara]]
[[Handelshuset Sarissos]]
```

The formatter resolves these links against tracked Markdown files.

Resolution uses:

1. canonical file/directory paths
2. source paths such as `/index`
3. article filenames
4. directory names for `index.md`
5. frontmatter `title:` values
6. normalized case, whitespace, hyphen and underscore variants for existing
   targets

For example:

```text
Karaktärer/Roland Corveaux.md
```

can be resolved from:

```markdown
[[Roland Corveaux]]
```

A directory article such as:

```text
Platser/Morbejara/index.md
```

can be resolved from:

```markdown
[[Morbejara]]
```

A page such as:

```text
Organisationer/Sarissos.md
```

with:

```yaml
---
title: Handelshuset Sarissos
---
```

can also be resolved from:

```markdown
[[Handelshuset Sarissos]]
```

Resolved links are normalized to an explicit canonical target with a display
alias where required.

## Duplicate links

Only the first link to a particular article in each Markdown file remains a
link.

For example:

```markdown
[[Roland Corveaux]]

Roland met [[Karaktärer/Roland Corveaux|Roland]] later that evening.
```

becomes conceptually:

```markdown
[[Karaktärer/Roland Corveaux|Roland Corveaux]]

Roland met Roland later that evening.
```

Duplicate detection uses the resolved canonical target rather than the literal
wikilink syntax, so different spellings or path forms that resolve to the same
article count as the same link.

Aliases are preserved as the display text when duplicate links are flattened.

## Dangling links

Links without a currently valid target are allowed.

For example:

```markdown
[[Future Castle]]
```

remains a wikilink even when no matching article exists yet.

The first dangling link is preserved as written. Later occurrences of the same
dangling target in the same Markdown file are converted to plain text.

Dangling duplicate comparison is deliberately conservative. Case differences
are ignored, but the formatter does not assume that different hyphenation or
spacing refers to the same future article.

The formatter reports the number of dangling targets encountered but does not
fail the commit or deployment.

## Quartz boundary fixes

Quartz may fail to parse bold markup correctly when they are
directly adjacent to alphanumeric characters.

For example:

```markdown
**[[Gughlug]]**s sword
```

The formatter inserts the invisible HTML entity:

```text
&#8203;
```

where required:

```markdown
[[Gughlug]]&#8203;s sword
```

No separator is inserted before punctuation such as:

```text
- _ , . '
```

## Content ignored by the formatter

The formatter does not modify:

- YAML frontmatter
- fenced code blocks
- inline code
- `![[embeds]]`
- heading/block-reference links
- repository tooling
- `README.md`
- `Mall.md` templates
- Markdown excluded from the published site

## Local setup

Enable the repository hook once after cloning:

```bash
./setup-hook.sh
```

This configures:

```bash
git config --local core.hooksPath .githooks
```

After that, a normal:

```bash
git commit
```

automatically invokes:

```bash
./tools/format-wikilinks.sh --staged
```

The hook can be bypassed manually with:

```bash
git commit --no-verify
```

This is mainly useful when testing the GitHub-side `--changed` workflow.

## GitHub Actions

Edits committed directly through GitHub do not execute local Git hooks.

The deployment workflow therefore runs:

```bash
./tools/format-wikilinks.sh --changed <before> <sha>
```

before building the Quartz site.

If formatting changes a Markdown file, the workflow commits the normalized
version back to the repository before continuing with the build.

Manual workflow runs use:

```bash
./tools/format-wikilinks.sh --all
```