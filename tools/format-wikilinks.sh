#!/usr/bin/env sh
set -eu


usage() {
    echo "Usage: $0 --all | --staged" >&2
    exit 2
}


MODE=${1:-}

case "$MODE" in
    --all|--staged)
        ;;
    *)
        usage
        ;;
esac


ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "wikilinks: not inside a Git repository" >&2
    exit 2
}


SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
AWK_SCRIPT="$SCRIPT_DIR/format-wikilinks.awk"


if [ ! -f "$AWK_SCRIPT" ]; then
    echo "wikilinks: missing $AWK_SCRIPT" >&2
    exit 2
fi


cd "$ROOT"


TMP_ROOT=${TMPDIR:-/tmp}
TMP_DIR=$(mktemp -d "$TMP_ROOT/wikilinks.XXXXXX") || exit 2

trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM


INDEX_FILE="$TMP_DIR/index.tsv"
FILES_FILE="$TMP_DIR/files.txt"
OUT_FILE="$TMP_DIR/output.md"
DANGLING_FILE="$TMP_DIR/dangling.tsv"

: > "$INDEX_FILE"
: > "$FILES_FILE"
: > "$DANGLING_FILE"


is_site_markdown() {
    case "$1" in
        .github/*|.githooks/*|.claude/*|.obsidian/*|tools/*|public/*|README.md|Mall.md|*/Mall.md)
            return 1
            ;;
        *.md)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}


get_frontmatter_title() {
    awk '
        NR == 1 && $0 ~ /^---\r?$/ {
            frontmatter = 1
            next
        }

        frontmatter && $0 ~ /^(---|\.\.\.)\r?$/ {
            exit
        }

        frontmatter && $0 ~ /^[[:space:]]*title:[[:space:]]*/ {
            value = $0
            sub(/^[[:space:]]*title:[[:space:]]*/, "", value)
            sub(/\r$/, "", value)

            if (substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") {
                value = substr(value, 2, length(value) - 2)
            }

            if (substr(value, 1, 1) == "\047" && substr(value, length(value), 1) == "\047") {
                value = substr(value, 2, length(value) - 2)
            }

            print value
            exit
        }
    ' "$1"
}


# Build repository-wide article index.

git -c core.quotepath=false ls-files -- '*.md' |
while IFS= read -r rel; do

    [ -f "$rel" ] || continue
    is_site_markdown "$rel" || continue

    file=${rel##*/}
    file_stem=${file%.md}

    case "$rel" in
        */*)
            dir=${rel%/*}
            ;;
        *)
            dir=""
            ;;
    esac

    if [ "$file" = "index.md" ]; then
        [ -n "$dir" ] || continue

        name=${dir##*/}
        target=$dir
        is_index=1
    else
        name=$file_stem
        target=${rel%.md}
        is_index=0
    fi

    file_target=${rel%.md}
    title=$(get_frontmatter_title "$rel")

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$target" "$file_target" "$is_index" "$rel" "$title" >> "$INDEX_FILE"

done


# Select files to process.

if [ "$MODE" = "--all" ]; then

    git -c core.quotepath=false ls-files -- '*.md' |
    while IFS= read -r rel; do

        [ -f "$rel" ] || continue
        is_site_markdown "$rel" || continue

        printf '%s\n' "$rel" >> "$FILES_FILE"

    done

else

    git -c core.quotepath=false diff --cached --name-only --diff-filter=ACMR -- '*.md' |
    while IFS= read -r rel; do

        [ -f "$rel" ] || continue
        is_site_markdown "$rel" || continue

        printf '%s\n' "$rel" >> "$FILES_FILE"

    done

fi


# Refuse partially staged Markdown files.

if [ "$MODE" = "--staged" ]; then

    partial=0

    while IFS= read -r rel; do

        [ -n "$rel" ] || continue

        if ! git diff --quiet -- "$rel"; then

            if [ "$partial" -eq 0 ]; then
                echo "wikilinks: refusing to format partially staged Markdown files." >&2
                echo "Stage or discard the unstaged edits first:" >&2
            fi

            echo "    $rel" >&2
            partial=1

        fi

    done < "$FILES_FILE"

    [ "$partial" -eq 0 ] || exit 2

fi


# Validate the run before modifying files.
# Dangling links are allowed and are not reported during this pass.

while IFS= read -r rel; do

    [ -n "$rel" ] || continue

    if ! awk -v INDEX_FILE="$INDEX_FILE" -v SOURCE="$rel" -v REPORT_DANGLING=0 -f "$AWK_SCRIPT" "$rel" > /dev/null; then
        exit 2
    fi

done < "$FILES_FILE"


# Transform files.

changed=0

while IFS= read -r rel; do

    [ -n "$rel" ] || continue

    awk -v INDEX_FILE="$INDEX_FILE" -v SOURCE="$rel" -v REPORT_DANGLING=1 -v DANGLING_FILE="$DANGLING_FILE" -f "$AWK_SCRIPT" "$rel" > "$OUT_FILE"

    if ! cmp -s "$rel" "$OUT_FILE"; then
        cat "$OUT_FILE" > "$rel"
        changed=$((changed + 1))

        if [ "$MODE" = "--staged" ]; then
            git add -- "$rel"
        fi
    fi

done < "$FILES_FILE"


if [ "$MODE" = "--staged" ]; then
    echo "wikilinks: formatted and re-staged $changed Markdown file(s)."
else
    echo "wikilinks: formatted $changed Markdown file(s)."
fi


if [ -s "$DANGLING_FILE" ]; then
    dangling_count=$(wc -l < "$DANGLING_FILE" | tr -d '[:space:]')
    echo "wikilinks: $dangling_count dangling target(s) remain (allowed)."
fi