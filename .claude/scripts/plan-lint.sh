#!/usr/bin/env bash
#
# plan-lint.sh — mechanical checks over .claude/PLAN.md.
#
# Everything here is decidable by grep. It exists so that Opus reviewers never spend a round
# rediscovering a placeholder, a signature that drifted between two tasks, or a requirement that
# appears nowhere in the plan. Run it after every planner revision, before the planner closes its
# resolve task, and hand the output to `planner` directly — findings from this script are not a
# review round and do not need a lens.
#
# It is deliberately conservative about what it reports. It is NOT permitted to be quiet about what
# it did not check: every section states how many items it examined, and a check that examined
# nothing is itself a finding. Reviewers have been told not to re-derive these checks by hand, so a
# silent no-op here is worse than no script at all.
#
# Usage:  .claude/scripts/plan-lint.sh [PLAN.md] [SPEC.md] [CONTRACTS.md]
#
# Exit:   0  nothing found
#         1  findings (see output)
#         2  could not run (missing plan)

set -uo pipefail

PLAN="${1:-.claude/PLAN.md}"
SPEC="${2:-.claude/SPEC.md}"
CONTRACTS="${3:-.claude/CONTRACTS.md}"
SRC_DIRS=(novawallet novawalletTests)

# Derived from what the reduction rules can actually deliver: contracts-by-reference and test case
# tables take a 5000-line plan to ~3150. A budget below what the rules reach is a standing
# escalation carrying no information. Override per-run when the human has knowingly accepted more.
PLAN_LINE_BUDGET="${PLAN_LINE_BUDGET:-3200}"
TASK_LINE_BUDGET="${TASK_LINE_BUDGET:-450}"

[ -f "$PLAN" ] || { echo "plan-lint: no such file: $PLAN" >&2; exit 2; }

findings=0
sect=0
section() { sect=0; printf '\n### %s\n\n' "$1"; }
finding() { findings=$((findings + 1)); sect=$((sect + 1)); printf -- '- %s\n' "$1"; }
# Every section ends with one of these. `checked` states the denominator; a zero denominator is a
# finding, because "nothing found" over nothing examined is the failure mode this script must not
# have.
checked() {
    local n="$1" what="$2"
    if [ "$n" -eq 0 ]; then
        finding "CHECK DID NOT RUN: found no $what to examine. Treat this section as unchecked and do it by hand — do not read the absence of findings as a pass."
    elif [ "$sect" -eq 0 ]; then
        printf -- '- clean over %s %s\n' "$n" "$what"
    else
        printf -- '- (examined %s %s)\n' "$n" "$what"
    fi
}

printf '# plan-lint — %s\n' "$PLAN"

# ---------------------------------------------------------------------------
# 1. Size budget.
# ---------------------------------------------------------------------------
section "Size"

total=$(wc -l < "$PLAN" | tr -d ' ')
printf -- '- total: %s lines (budget %s)\n' "$total" "$PLAN_LINE_BUDGET"

task_lines=$(awk '
    /^## Task /  { if (t != "") print n "\t" t; t = $0; n = 0; next }
    /^## /       { if (t != "") print n "\t" t; t = ""; next }
                 { if (t != "") n++ }
    END          { if (t != "") print n "\t" t }
' "$PLAN")

ntasks=0
while IFS=$'\t' read -r n title; do
    [ -z "${n:-}" ] && continue
    ntasks=$((ntasks + 1))
    printf -- '-   %5s  %s\n' "$n" "$title"
done <<< "$task_lines"

if [ "$total" -gt "$PLAN_LINE_BUDGET" ]; then
    finding "PLAN.md is $total lines, over the $PLAN_LINE_BUDGET budget. Escalate as scope before reviewing — split the plan, or apply the reduction rules in nova-planner.md Stage 2."
fi
while IFS=$'\t' read -r n title; do
    [ -z "${n:-}" ] && continue
    [ "$n" -gt "$TASK_LINE_BUDGET" ] && finding "Over task budget ($n > $TASK_LINE_BUDGET lines): $title"
done <<< "$task_lines"
checked "$ntasks" "tasks (\`## Task \` headings)"

# ---------------------------------------------------------------------------
# 2. Placeholders.
#    NOTE: awk's ERE has no \b. Word boundaries are spelled out as character
#    classes; do not reintroduce \b here — it matches nothing and the rule dies
#    silently.
# ---------------------------------------------------------------------------
section "Placeholders"

placeholders=$(awk '
    /^[[:space:]]*```/                          { fence = !fence; next }
    fence && /^[[:space:]]*(\.\.\.|…)[[:space:]]*$/ { print NR ": bare ellipsis inside a code fence" ; next }
    /(^|[^A-Za-z])TBD([^A-Za-z]|$)/             { print NR ": TBD — " $0; next }
    /(^|[^A-Za-z])similar to (Task|the)/        { print NR ": \"similar to\" — " $0; next }
    /(^|[^A-Za-z])as (needed|appropriate|required)([^A-Za-z]|$)/ { print NR ": hand-wave — " $0; next }
    /(^|[^A-Za-z])and so on([^A-Za-z]|$)/       { print NR ": open-ended list — " $0; next }
    /(^|[^A-Za-z])etc\.?[[:space:]]*$/          { print NR ": open-ended list — " $0; next }
    /^[[:space:]]*- \[ \][[:space:]]*[0-9]+\..*(implement the|add error handling|wire it up|update the tests accordingly)/ {
                                                  print NR ": step states an intention, not an action — " $0; next }
' "$PLAN")

if [ -n "$placeholders" ]; then
    while IFS= read -r hit; do finding "$PLAN:$hit"; done <<< "$placeholders"
fi
checked "$(wc -l < "$PLAN" | tr -d ' ')" "lines scanned"

# ---------------------------------------------------------------------------
# 3. Interface consistency.
#
#    Declarations are JOINED ACROSS LINES before comparison — a multi-line
#    `func` is one declaration, and comparing only its first physical line
#    (which is just `func name(`) makes the whole check vacuous. Keys carry the
#    enclosing type, so two protocols declaring the same method name do not
#    collide. A `Consumes`/`Produces` label only opens an interface block if a
#    fence actually follows; a bodyless "Produces: nothing" must not capture the
#    next fenced block in the document.
# ---------------------------------------------------------------------------
section "Interface consistency"

sig_report=$(awk '
    function norm(s) { gsub(/[[:space:]]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
    function head(s) { sub(/[[:space:]]*\{.*$/, "", s); return norm(s) }
    function pdelta(s,   i, c, n) {
        n = 0
        for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); if (c == "(") n++; else if (c == ")") n-- }
        return n
    }
    function isfunc(s) { return s ~ /^[[:space:]]*(@[A-Za-z]+[[:space:]]+)*(public |internal |private |fileprivate |open |final |static |class |mutating |nonisolated )*func +/ }
    function istype(s) { return s ~ /^[[:space:]]*(@[A-Za-z]+[[:space:]]+)*(public |internal |private |fileprivate |open |final |indirect )*(protocol|struct|enum|class|actor|typealias|extension) +/ }
    # Keys deliberately do NOT carry the enclosing type: a producer written inside
    # `extension X { func f() }` and a consumer written as a bare `func f()` are the same
    # declaration, and keying on the enclosure makes the second look undeclared. Same-named
    # methods on different types are handled by ambiguity reporting in END, not by the key.
    function key(s,   m, args, i, n, parts, labels) {
        if (s ~ /^extension /) { m = s; sub(/^extension +/, "", m); sub(/[^A-Za-z0-9_].*$/, "", m); return "ext:" m }
        if (match(s, /func +[A-Za-z_][A-Za-z0-9_]*/)) {
            m = substr(s, RSTART, RLENGTH); sub(/^func +/, "", m)
            args = s; sub(/^[^(]*\(/, "", args); sub(/\)[^)]*$/, "", args)
            labels = ""; n = split(args, parts, ",")
            for (i = 1; i <= n; i++) {
                if (parts[i] ~ /:/) {
                    sub(/:.*$/, "", parts[i]); gsub(/[[:space:]]+/, " ", parts[i])
                    sub(/^ +/, "", parts[i]); sub(/ .*$/, "", parts[i])
                    labels = labels parts[i] ":"
                }
            }
            return "func:" m "(" labels ")"
        }
        if (match(s, /(protocol|struct|enum|class|actor|typealias) +[A-Za-z_][A-Za-z0-9_]*/)) {
            m = substr(s, RSTART, RLENGTH); sub(/^[a-z]+ +/, "", m); return "type:" m
        }
        return ""
    }
    function emit(raw,   h, k) {
        h = head(raw); k = key(norm(raw))
        if (k == "") return
        # A declaration that opens a brace becomes the enclosing scope for what follows.
        if (raw ~ /\{[[:space:]]*$/ && (k ~ /^type:/ || k ~ /^ext:/)) { encl = k; sub(/^(type|ext):/, "", encl) }
        if (mode == "p") {
            # Record EVERY producer, not just the first: two producers of one key with different
            # text is an ambiguity the plan must resolve, and silently keeping the first turns a
            # correct plan into a drift finding against an unrelated declaration.
            if (!(k in pkey)) { pkey[k] = h; ptask[k] = task; pencl[k] = encl }
            else if (pkey[k] != h) { pamb[k] = pamb[k] "\n      also " task (encl == "" ? "" : " (in " encl ")") ": " h }
            np++
        }
        else { nc++; ck[nc] = k; ch[nc] = h; ctask[nc] = task }
    }
    /^## Task / { task = $0; sub(/^## /, "", task); sub(/ —.*$/, "", task) }
    # A label arms the parser; only an immediately-following fence fires it.
    /^(Consumes|Produces)/ { pending = ($0 ~ /^Consumes/) ? "c" : "p"; next }
    /^[[:space:]]*```/ {
        if (fence) { fence = 0; mode = ""; encl = ""; buf = ""; depth = 0; next }
        if (pending != "") { mode = pending; pending = ""; fence = 1; encl = ""; buf = ""; depth = 0 }
        next
    }
    /^[[:space:]]*$/ { next }
    {
        # Any non-blank, non-fence line between the label and a fence disarms it.
        if (pending != "") pending = ""
        if (!fence || mode == "") next
        if ($0 ~ /^[[:space:]]*\}[[:space:]]*$/) { if (buf == "") encl = ""; next }
        if ($0 ~ /^[[:space:]]*\/\//) next
        if (buf == "") {
            if (!isfunc($0) && !istype($0)) next
            buf = $0; depth = pdelta($0)
        } else {
            buf = buf " " $0; depth += pdelta($0)
        }
        if (depth <= 0) { emit(buf); buf = ""; depth = 0 }
    }
    END {
        # Force numeric: tab is IFS whitespace, so an empty field would be collapsed by `read`
        # and shift every column left.
        print "COUNTS\t" (np + 0) "\t" (nc + 0)
        for (i = 1; i <= nc; i++) {
            k = ck[i]
            if (k in pkey) {
                if (k in pamb) {
                    if (!(k in ambdone)) {
                        ambdone[k] = 1
                        print "AMBIG\t" ctask[i] "\t" ch[i] "\t" ptask[k] (pencl[k] == "" ? "" : " (in " pencl[k] ")") ": " pkey[k] pamb[k]
                    }
                } else if (pkey[k] != ch[i]) {
                    print "DRIFT\t" ctask[i] "\t" ch[i] "\t" ptask[k] ": " pkey[k]
                }
            } else {
                id = k; sub(/^(func|type|ext):/, "", id); sub(/\|.*$/, "", id); sub(/\(.*$/, "", id)
                if (!(id in seen)) { seen[id] = 1; print "EXTERNAL\t" ctask[i] "\t" id "\t" ch[i] }
            }
        }
    }
' "$PLAN")

external=""
nprod=0; ncons=0
if [ -n "$sig_report" ]; then
    while IFS=$'\t' read -r kind a b c; do
        case "$kind" in
            COUNTS)   nprod="$a"; ncons="$b" ;;
            DRIFT)    finding "Signature drift — $a consumes \`$b\`, but $c" ;;
            AMBIG)    finding "Ambiguous producer — $a consumes \`$b\`, and more than one task declares that name and label list with different text. Disambiguate by enclosing type, or make them identical. Producers: $c" ;;
            EXTERNAL) external+="$a"$'\t'"$b"$'\t'"$c"$'\n' ;;
        esac
    done <<< "$sig_report"
fi
checked "$((nprod + ncons))" "declarations joined and compared ($nprod produced, $ncons consumed)"

if [ -n "$external" ]; then
    section "Consumes citing existing code"
    nx=0
    while IFS=$'\t' read -r task id sig; do
        [ -z "${id:-}" ] && continue
        nx=$((nx + 1))
        if ! grep -rqE --include='*.swift' "(^|[^A-Za-z0-9_])${id}([^A-Za-z0-9_]|$)" "${SRC_DIRS[@]}" 2>/dev/null; then
            finding "$task consumes \`$id\`, which no task produces and no .swift file in ${SRC_DIRS[*]} declares — \`$sig\`"
        fi
    done <<< "$external"
    checked "$nx" "symbols consumed but not produced"
fi

# ---------------------------------------------------------------------------
# 4. Requirement coverage, both directions. A missing SPEC is a finding, never a
#    skip — SPEC.md is gitignored and absent in a fresh worktree, which is
#    exactly when a silent pass is most dangerous.
# ---------------------------------------------------------------------------
section "Requirement coverage"

if [ -f "$SPEC" ]; then
    id_re='(FR|NFR|EC)-[0-9]+[a-z]?'
    spec_ids=$(grep -oE "$id_re" "$SPEC" | sort -u)
    plan_ids=$(grep -oE "$id_re" "$PLAN" | sort -u)
    nspec=$(printf '%s\n' "$spec_ids" | grep -c . || true)

    uncovered=$(comm -23 <(printf '%s\n' "$spec_ids") <(printf '%s\n' "$plan_ids") | tr '\n' ' ' | sed 's/ $//')
    invented=$(comm -13 <(printf '%s\n' "$spec_ids") <(printf '%s\n' "$plan_ids") | tr '\n' ' ' | sed 's/ $//')

    [ -n "$uncovered" ] && finding "In SPEC, absent from PLAN entirely — $uncovered"
    [ -n "$invented" ]  && finding "In PLAN, absent from SPEC — $invented"
    checked "$nspec" "requirement ids in SPEC"
else
    finding "CHECK DID NOT RUN: $SPEC not found, so requirement coverage was not checked at all. If you are in a worktree, SPEC.md is gitignored and did not travel — fetch it before assigning a round."
fi

# ---------------------------------------------------------------------------
# 5. Contract citations resolve.
# ---------------------------------------------------------------------------
section "Contract citations"

if [ -f "$CONTRACTS" ]; then
    defined=$(grep -oE '^## C-[0-9]+' "$CONTRACTS" | grep -oE 'C-[0-9]+' | sort -u)
    cited=$(grep -oE '(^|[^A-Za-z0-9_])C-[0-9]+' "$PLAN" | grep -oE 'C-[0-9]+' | sort -u)
    ndef=$(printf '%s\n' "$defined" | grep -c . || true)

    dangling=$(comm -13 <(printf '%s\n' "$defined") <(printf '%s\n' "$cited") | tr '\n' ' ' | sed 's/ $//')
    unused=$(comm -23 <(printf '%s\n' "$defined") <(printf '%s\n' "$cited") | tr '\n' ' ' | sed 's/ $//')

    [ -n "$dangling" ] && finding "PLAN cites contracts that CONTRACTS.md does not define — $dangling. The executor will open the file and find nothing."
    [ -n "$unused" ]   && finding "CONTRACTS.md defines contracts no task cites — $unused. Either a task is missing, or the contract is dead."
    checked "$ndef" "contracts defined in $CONTRACTS"
else
    finding "CHECK DID NOT RUN: $CONTRACTS not found. The plan cites contracts by reference, so the executor and \`plan-exec\` have nothing to resolve them against — this file must exist and must travel with the plan."
fi

# ---------------------------------------------------------------------------
# 6. File table vs task file lists.
# ---------------------------------------------------------------------------
section "File table"

file_re='`[^`]+\.(swift|strings|pbxproj|toml|xcdatamodeld?|json)`'
table_files=$(awk '/^## Files/{f=1;next} /^## /{f=0} f && /^\|/' "$PLAN" \
              | grep -oE "$file_re" | tr -d '`' | sort -u)
task_files=$(awk '/^## Task /{t=1} /^\*\*Interface\*\*/{t=0} t && /^- (create|modify|delete) /' "$PLAN" \
             | grep -oE "$file_re" | tr -d '`' | sort -u)
ntable=$(printf '%s\n' "$table_files" | grep -c . || true)
ntask=$(printf '%s\n' "$task_files" | grep -c . || true)

missing_from_table=$(comm -13 <(printf '%s\n' "$table_files") <(printf '%s\n' "$task_files") | tr '\n' ' ' | sed 's/ $//')
missing_from_tasks=$(comm -23 <(printf '%s\n' "$table_files") <(printf '%s\n' "$task_files") | tr '\n' ' ' | sed 's/ $//')

[ -n "$missing_from_table" ] && finding "Touched by a task, absent from the ## Files table — $missing_from_table"
[ -n "$missing_from_tasks" ] && finding "In the ## Files table, touched by no task — $missing_from_tasks"
checked "$((ntable + ntask))" "file paths ($ntable in the table, $ntask in task steps)"

# ---------------------------------------------------------------------------
# 7. Per-task required sections.
# ---------------------------------------------------------------------------
section "Task structure"

structure=$(awk '
    function flush() {
        if (task == "") return
        if (!implements) print task "\tno **Implements:** line"
        if (!steps)      print task "\tno checkbox steps"
        if (!verify)     print task "\tno **Verify** section"
        if (!expected)   print task "\tno \"Expected:\" line — a verification that cannot fail"
        if (!commit)     print task "\tno **Commit:** line"
    }
    /^## Task / { flush(); task = $0; sub(/^## /, "", task); sub(/ —.*$/, "", task)
                  implements = verify = expected = commit = steps = 0; next }
    /^## /      { flush(); task = ""; next }
    task != "" {
        if ($0 ~ /^\*\*Implements:\*\*/)  implements = 1
        if ($0 ~ /^\*\*Verify\*\*/)       verify = 1
        if ($0 ~ /^(\*\*)?Expected:/)     expected = 1
        if ($0 ~ /^\*\*Commit:\*\*/)      commit = 1
        if ($0 ~ /^[[:space:]]*- \[ \]/)  steps = 1
    }
    END { flush() }
' "$PLAN")

if [ -n "$structure" ]; then
    while IFS=$'\t' read -r task what; do finding "$task — $what"; done <<< "$structure"
fi
checked "$ntasks" "tasks"

# ---------------------------------------------------------------------------
section "Result"
if [ "$findings" -eq 0 ]; then
    printf 'clean — every check ran and found nothing.\n'
    exit 0
fi
printf '%s mechanical finding(s). Send them to `planner` directly; this is not a review round.\n' "$findings"
exit 1
