BEGIN {
    FS = "\t"
    ZWSP = "&#8203;"

    while ((getline row < INDEX_FILE) > 0) {
        split(row, f, "\t")

        name = f[1]
        target = f[2]
        filetarget = f[3]
        is_index = f[4] + 0
        source = f[5]
        title = f[6]

        if ((target in target_exists) && article_source[target] != source) {
            print "wikilinks: canonical target collision: " target > "/dev/stderr"
            print "    " article_source[target] > "/dev/stderr"
            print "    " source > "/dev/stderr"
            init_error = 1
            continue
        }

        target_exists[target] = 1
        file_target[filetarget] = target
        article_name[target] = name
        article_title[target] = title
        article_is_index[target] = is_index
        article_source[target] = source

        name_count[name]++

        if (name_count[name] == 1) {
            name_target[name] = target
            name_candidates[name] = source
        } else {
            name_target[name] = ""
            name_candidates[name] = name_candidates[name] "\n    " source
        }

        if (title != "") {
            title_count[title]++

            if (title_count[title] == 1) {
                title_target[title] = target
                title_candidates[title] = source
            } else {
                title_target[title] = ""
                title_candidates[title] = title_candidates[title] "\n    " source
            }
        }

        register_loose_path(target, target, source)
        register_loose_path(filetarget, target, source)
        register_loose_name(name, target, source)

        if (title != "") {
            register_loose_title(title, target, source)
        }
    }

    close(INDEX_FILE)

    if (init_error) {
        exit 2
    }
}


function trim(s) {
    sub(/^[[:space:]]+/, "", s)
    sub(/[[:space:]]+$/, "", s)
    return s
}


function casefold(s) {
    gsub(/Å/, "å", s)
    gsub(/Ä/, "ä", s)
    gsub(/Ö/, "ö", s)
    return tolower(s)
}


function normalize_target(s) {
    s = trim(s)
    gsub(/\\/, "/", s)
    gsub(/%20/, " ", s)

    while (substr(s, 1, 2) == "./") {
        s = substr(s, 3)
    }

    sub(/^\/+/, "", s)
    sub(/\.md$/, "", s)
    sub(/\/+$/, "", s)

    while (index(s, "//")) {
        gsub(/\/\//, "/", s)
    }

    return s
}


function dangling_key(s) {
    s = trim(s)
    gsub(/\\/, "/", s)

    while (substr(s, 1, 2) == "./") {
        s = substr(s, 3)
    }

    sub(/^\/+/, "", s)
    sub(/\.md$/, "", s)
    sub(/\/+$/, "", s)

    while (index(s, "//")) {
        gsub(/\/\//, "/", s)
    }

    return casefold(s)
}


function loose_key(s) {
    s = normalize_target(s)
    s = casefold(s)
    gsub(/[-_]+/, " ", s)
    gsub(/[[:space:]]+/, " ", s)
    gsub(/[[:space:]]*\/[[:space:]]*/, "/", s)
    return trim(s)
}


function register_loose_path(raw, target, source, key) {
    key = loose_key(raw)

    if (key == "") {
        return
    }

    if (!(key in loose_path_target)) {
        loose_path_target[key] = target
        loose_path_count[key] = 1
        loose_path_candidates[key] = source
        return
    }

    if (loose_path_target[key] == target) {
        return
    }

    loose_path_count[key]++
    loose_path_candidates[key] = loose_path_candidates[key] "\n    " source
}


function register_loose_name(raw, target, source, key) {
    key = loose_key(raw)

    if (key == "") {
        return
    }

    if (!(key in loose_name_target)) {
        loose_name_target[key] = target
        loose_name_count[key] = 1
        loose_name_candidates[key] = source
        return
    }

    if (loose_name_target[key] == target) {
        return
    }

    loose_name_count[key]++
    loose_name_candidates[key] = loose_name_candidates[key] "\n    " source
}


function register_loose_title(raw, target, source, key) {
    key = loose_key(raw)

    if (key == "") {
        return
    }

    if (!(key in loose_title_target)) {
        loose_title_target[key] = target
        loose_title_count[key] = 1
        loose_title_candidates[key] = source
        return
    }

    if (loose_title_target[key] == target) {
        return
    }

    loose_title_count[key]++
    loose_title_candidates[key] = loose_title_candidates[key] "\n    " source
}


function resolve_target(raw, t, key, name) {
    resolved_title = ""
    t = normalize_target(raw)

    if (t == "" || index(t, "#") || index(t, "^")) {
        return ""
    }

    if (t in target_exists) {
        return t
    }

    if (t in file_target) {
        return file_target[t]
    }

    if (index(t, "/") == 0) {
        name = t

        if (name_count[name] == 1) {
            return name_target[name]
        }

        if (name_count[name] > 1) {
            print SOURCE ": ambiguous [[" raw "]]; use a full path. Candidates:" > "/dev/stderr"
            print "    " name_candidates[name] > "/dev/stderr"
            fatal = 1
            return ""
        }

        if (title_count[name] == 1) {
            resolved_title = name
            return title_target[name]
        }

        if (title_count[name] > 1) {
            print SOURCE ": ambiguous title [[" raw "]]; use a full path. Candidates:" > "/dev/stderr"
            print "    " title_candidates[name] > "/dev/stderr"
            fatal = 1
            return ""
        }
    }

    key = loose_key(t)

    if (key in loose_path_target) {
        if (loose_path_count[key] == 1) {
            return loose_path_target[key]
        }

        print SOURCE ": ambiguous path [[" raw "]]; use the exact path. Candidates:" > "/dev/stderr"
        print "    " loose_path_candidates[key] > "/dev/stderr"
        fatal = 1
        return ""
    }

    if (index(t, "/") == 0) {
        if (key in loose_name_target) {
            if (loose_name_count[key] == 1) {
                return loose_name_target[key]
            }

            print SOURCE ": ambiguous article name [[" raw "]]; use a full path. Candidates:" > "/dev/stderr"
            print "    " loose_name_candidates[key] > "/dev/stderr"
            fatal = 1
            return ""
        }

        if (key in loose_title_target) {
            if (loose_title_count[key] == 1) {
                resolved_title = t
                return loose_title_target[key]
            }

            print SOURCE ": ambiguous article title [[" raw "]]; use a full path. Candidates:" > "/dev/stderr"
            print "    " loose_title_candidates[key] > "/dev/stderr"
            fatal = 1
            return ""
        }
    }

    return ""
}


function duplicate_display(raw_target, alias, display) {
    if (alias != "") {
        return alias
    }

    display = normalize_target(raw_target)

    if (display ~ /\/index$/) {
        sub(/\/index$/, "", display)
    }

    sub(/^.*\//, "", display)

    return display
}


function dangling_display(raw_target, alias, display) {
    if (alias != "") {
        return alias
    }

    display = trim(raw_target)
    gsub(/\\/, "/", display)

    while (substr(display, 1, 2) == "./") {
        display = substr(display, 3)
    }

    sub(/^\/+/, "", display)
    sub(/\.md$/, "", display)
    sub(/\/+$/, "", display)

    while (index(display, "//")) {
        gsub(/\/\//, "/", display)
    }

    if (display ~ /\/index$/) {
        sub(/\/index$/, "", display)
    }

    sub(/^.*\//, "", display)

    return display
}


function format_dangling(payload, raw_target, alias, key) {
    key = dangling_key(raw_target)

    if (key == "") {
        return "[[" payload "]]"
    }

    if (key in dangling_seen) {
        return dangling_display(raw_target, alias)
    }

    dangling_seen[key] = 1

    if (REPORT_DANGLING && DANGLING_FILE != "") {
        print SOURCE "\t" raw_target >> DANGLING_FILE
        close(DANGLING_FILE)
    }

    return "[[" payload "]]"
}


function format_payload(payload, pipe_at, raw_target, alias, canonical, name, chosen, matched_title, seen_key) {
    pipe_at = index(payload, "|")

    if (pipe_at) {
        raw_target = trim(substr(payload, 1, pipe_at - 1))
        alias = trim(substr(payload, pipe_at + 1))
    } else {
        raw_target = trim(payload)
        alias = ""
    }

    if (raw_target == "" || index(raw_target, "#") || index(raw_target, "^")) {
        return "[[" payload "]]"
    }

    canonical = resolve_target(raw_target)
    matched_title = resolved_title

    if (canonical == "") {
        return format_dangling(payload, raw_target, alias)
    }

    name = article_name[canonical]
    seen_key = loose_key(canonical)

    if (seen_key in seen) {
        return duplicate_display(raw_target, alias)
    }

    seen[seen_key] = 1

    if (!article_is_index[canonical] && name_count[name] == 1) {
        chosen = name
    } else {
        chosen = canonical
    }

    if (alias != "") {
        return "[[" chosen "|" alias "]]"
    }

    if (matched_title != "") {
        return "[[" chosen "|" matched_title "]]"
    }

    if (index(chosen, "/") && chosen ~ /[[:space:]]/) {
        return "[[" chosen "|" name "]]"
    }

    return "[[" chosen "]]"
}


function needs_boundary(c) {
    return c ~ /[[:alnum:]]/
}


function process_strong(line, pos, open_at, close_rel, close_at, before, after, content, result) {
    result = ""
    open_at = pos
    close_rel = index(substr(line, open_at + 2), "**")

    if (!close_rel) {
        return ""
    }

    close_at = open_at + close_rel + 1
    before = ""

    if (open_at > 1) {
        before = substr(line, open_at - 1, 1)
    }

    after = ""

    if (close_at + 2 <= length(line)) {
        after = substr(line, close_at + 2, 1)
    }

    if (needs_boundary(before)) {
        result = result ZWSP
    }

    content = substr(line, open_at, close_at - open_at + 2)
    result = result content

    if (needs_boundary(after)) {
        result = result ZWSP
    }

    strong_end = close_at + 2

    return result
}


function process_line(line, out, i, n, c, run, marker, rest, close_at, chunk_len, payload, strong, formatted, link_end, next_char) {
    out = ""
    i = 1
    n = length(line)

    while (i <= n) {
        c = substr(line, i, 1)

        if (c == "`") {
            run = 1

            while (substr(line, i + run, 1) == "`") {
                run++
            }

            marker = substr(line, i, run)
            rest = substr(line, i + run)
            close_at = index(rest, marker)

            if (close_at) {
                chunk_len = (2 * run) + close_at - 1
                out = out substr(line, i, chunk_len)
                i += chunk_len
                continue
            }

            out = out substr(line, i)
            break
        }

        if (substr(line, i, 2) == "[[" && (i == 1 || substr(line, i - 1, 1) != "!")) {
            rest = substr(line, i + 2)
            close_at = index(rest, "]]")

            if (close_at) {
                payload = substr(rest, 1, close_at - 1)
                formatted = format_payload(payload)
                link_end = i + close_at + 2
                next_char = substr(line, link_end + 1, 1)

                out = out formatted

                if (needs_boundary(next_char)) {
                    out = out ZWSP
                }

                i = link_end + 1
                continue
            }
        }

        if (substr(line, i, 2) == "**") {
            strong = process_strong(line, i)

            if (strong != "") {
                out = out strong
                i = strong_end
                continue
            }
        }

        out = out c
        i++
    }

    return out
}


function detect_fence(line, s, c, n) {
    s = line
    sub(/^[ \t]*/, "", s)
    sub(/\r$/, "", s)
    c = substr(s, 1, 1)

    if (c != "`" && c != "~") {
        return 0
    }

    n = 1

    while (substr(s, n + 1, 1) == c) {
        n++
    }

    if (n < 3) {
        return 0
    }

    detected_fence_char = c
    detected_fence_len = n

    return 1
}


{
    line = $0
    plain = line
    sub(/\r$/, "", plain)

    if (NR == 1 && plain == "---") {
        in_frontmatter = 1
        print line
        next
    }

    if (in_frontmatter) {
        print line

        if (plain == "---" || plain == "...") {
            in_frontmatter = 0
        }

        next
    }

    if (detect_fence(line)) {
        if (!in_fence) {
            in_fence = 1
            fence_char = detected_fence_char
            fence_len = detected_fence_len
        } else if (detected_fence_char == fence_char && detected_fence_len >= fence_len) {
            in_fence = 0
        }

        print line
        next
    }

    if (in_fence) {
        print line
        next
    }

    print process_line(line)
}


END {
    if (fatal) {
        exit 2
    }
}