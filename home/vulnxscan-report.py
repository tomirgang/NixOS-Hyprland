# vulnxscan-report: summary of a vulnxscan CSV for frame-update.
#   vulnxscan-report.py report VULNS_CSV PREV_CSV CDX_OUT HOST
#   vulnxscan-report.py assess STATE_DIR   (frame-update --claude)
# Confidence filter: a finding counts as confirmed when vulnix or OSV reports
# it, or at least two scanners agree. grype-only findings come from CPE name
# matching (e.g. 2009 Thunderbird CVEs on 159.0) and stay in the CSV only.
# Whitelisted rows (whitelist column true) are dropped from report and upload.
import csv
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

TOP = 25


def load(path):
    if not os.path.isfile(path):
        return None
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def confirmed(row):
    return row.get("vulnix") == "1" or row.get("osv") == "1" or int(row.get("sum") or 0) >= 2


def whitelisted(row):
    return str(row.get("whitelist", "")).lower() == "true"


def score(row):
    try:
        return float(row.get("severity") or 0)
    except ValueError:
        return 0.0


def key(row):
    return (row["vuln_id"], row["package"], row["version_local"])


def severity(s):
    if s >= 9:
        return "critical"
    if s >= 7:
        return "high"
    if s >= 4:
        return "medium"
    return "low" if s > 0 else "unknown"


def line(row):
    scanners = "+".join(n for n in ("vulnix", "grype", "osv") if row.get(n) == "1")
    return f"  {score(row):4.1f}  {row['vuln_id']:<20} {row['package']} {row['version_local']}  [{scanners}]"


def cyclonedx(rows, host):
    comps = {}
    vulns = []
    for r in rows:
        ref = f"{r['package']}@{r['version_local']}"
        comps[ref] = {
            "type": "library",
            "bom-ref": ref,
            "name": r["package"],
            "version": r["version_local"],
            "purl": f"pkg:nix/{r['package']}@{r['version_local']}",
        }
        s = score(r)
        vulns.append({
            "id": r["vuln_id"],
            "ratings": [{"method": "CVSSv31", "score": s, "severity": severity(s)}] if s else [],
            "properties": [
                {"name": "vulnxscan:scanners", "value": r.get("sum", "")},
                {"name": "vulnxscan:sources", "value": ",".join(
                    n for n in ("vulnix", "grype", "osv") if r.get(n) == "1")},
            ],
            "affects": [{"ref": ref}],
        })
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "version": 1,
        "metadata": {
            "tools": {"components": [{"type": "application", "name": "vulnxscan"}]},
            "component": {"type": "operating-system", "name": host},
        },
        "components": list(comps.values()),
        "vulnerabilities": vulns,
    }


def report(cur_path, prev_path, cdx_out, host):
    rows = load(cur_path)
    if rows is None:
        sys.exit(f"{cur_path} missing")
    active = [r for r in rows if not whitelisted(r)]
    good = sorted((r for r in active if confirmed(r)), key=score, reverse=True)
    print(f"==> {len(rows)} findings, {len(rows) - len(active)} whitelisted, "
          f"{len(active) - len(good)} grype-only (CSV only), {len(good)} confirmed")
    prev = load(prev_path)
    if prev is not None:
        old = {key(r) for r in prev}
        new = [r for r in good if key(r) not in old]
        gone = len({key(r) for r in prev if confirmed(r)} - {key(r) for r in good})
        print(f"==> since the last scan: {len(new)} new confirmed, {gone} resolved")
        for r in new[:TOP]:
            print(line(r))
    print(f"==> top {min(TOP, len(good))} confirmed by score (full list: {cur_path})")
    for r in good[:TOP]:
        print(line(r))
    with open(cdx_out, "w") as f:
        json.dump(cyclonedx(good, host), f)


# Pre-assessment with Claude Code (frame-update --claude). Annotation only:
# nothing is whitelisted or uploaded automatically. Findings already assessed
# (claude-assessment.json) are skipped, so a run only sends new findings.
# Sent to the API: CVE ids, package names and versions, OSV texts, names of
# running services and listening sockets of this host.
VERDICTS = ("affected", "not_affected", "needs_review")
SCHEMA = {
    "type": "object",
    "properties": {"assessments": {"type": "array", "items": {
        "type": "object",
        "properties": {
            "vuln_id": {"type": "string"},
            "package": {"type": "string"},
            "version": {"type": "string"},
            "verdict": {"enum": list(VERDICTS)},
            "confidence": {"enum": ["low", "medium", "high"]},
            "reason": {"type": "string"},
        },
        "required": ["vuln_id", "package", "version", "verdict", "confidence", "reason"],
    }}},
    "required": ["assessments"],
}
SYSTEM = """You pre-assess vulnerability scanner findings for a single-user NixOS \
laptop (desktop, Hyprland). For each finding decide:
- not_affected: clear evidence only, e.g. the CVE belongs to a different project \
with the same name, the version is outside the affected range stated in the \
description, or the affected component is a server/feature that is evidently \
not running on this host (see services and sockets).
- affected: the vulnerable code is plausibly reachable, especially through a \
running network-facing service or through processing untrusted files or data.
- needs_review: everything else, including when the description is missing.
NixOS may fix CVEs by backported patches without a version change; you cannot \
see them, so never use "probably patched" as reason for not_affected. Do not \
invent facts about CVEs you do not know. Reason: one or two sentences in German, \
neutral and technical. Return one assessment per finding, ids unchanged."""


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def host_context():
    services = [ln.split()[0] for ln in run(
        ["systemctl", "list-units", "--type=service", "--state=running",
         "--no-legend", "--plain"]).splitlines() if ln.strip()]
    sockets = sorted({" ".join(ln.split()[:1] + ln.split()[4:5] + ln.split()[6:7])
                      for ln in run(["ss", "-Htulpn"]).splitlines() if ln.strip()})
    return "Running services:\n" + "\n".join(services) + \
        "\n\nListening sockets (proto local-address process):\n" + "\n".join(sockets)


def osv_text(vuln_id, cache):
    if vuln_id not in cache:
        try:
            with urllib.request.urlopen(f"https://api.osv.dev/v1/vulns/{vuln_id}", timeout=10) as f:
                data = json.load(f)
            cache[vuln_id] = (data.get("summary") or data.get("details") or "")[:700]
        except (OSError, ValueError):
            return ""
    return cache[vuln_id]


def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def save_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)


def akey(vuln_id, package, version):
    return f"{vuln_id}|{package}|{version}"


def assess(state):
    model = os.environ.get("FRAME_UPDATE_CLAUDE_MODEL", "sonnet")
    limit = int(os.environ.get("FRAME_UPDATE_CLAUDE_MAX", "60"))
    budget = os.environ.get("FRAME_UPDATE_CLAUDE_BUDGET", "1.00")
    rows = load(os.path.join(state, "vulns.csv")) or []
    store_path = os.path.join(state, "claude-assessment.json")
    done = load_json(store_path, {})
    good = sorted((r for r in rows if confirmed(r) and not whitelisted(r)), key=score, reverse=True)
    todo = [r for r in good if akey(*key(r)) not in done]
    print(f"==> claude: {len(good)} confirmed, {len(good) - len(todo)} already assessed, "
          f"{len(todo)} new (limit {limit}, model {model})")
    todo = todo[:limit]
    if todo:
        cache_path = os.path.join(state, "osv-cache.json")
        cache = load_json(cache_path, {})
        findings = [{"vuln_id": r["vuln_id"], "package": r["package"], "version": r["version_local"],
                     "cvss": score(r), "description": osv_text(r["vuln_id"], cache)} for r in todo]
        save_json(cache_path, cache)
        prompt = host_context() + "\n\nFindings (JSON):\n" + json.dumps(findings, ensure_ascii=False)
        cmd = ["claude", "-p", "--model", model, "--tools", "", "--strict-mcp-config",
               "--mcp-config", '{"mcpServers":{}}', "--disable-slash-commands",
               "--no-session-persistence", "--output-format", "json",
               "--max-budget-usd", budget, "--append-system-prompt", SYSTEM,
               "--json-schema", json.dumps(SCHEMA)]
        # empty working directory: no project CLAUDE.md, no repo context
        with tempfile.TemporaryDirectory() as cwd:
            try:
                proc = subprocess.run(cmd, input=prompt, capture_output=True, text=True,
                                      timeout=900, cwd=cwd)
            except (OSError, subprocess.SubprocessError) as e:
                sys.exit(f"==> claude failed: {e}")
        try:
            out = json.loads(proc.stdout)
        except ValueError:
            sys.exit(f"==> claude failed (exit {proc.returncode}): {proc.stderr.strip()[:300]}")
        if out.get("is_error") or not isinstance(out.get("structured_output"), dict):
            sys.exit(f"==> claude returned no assessment: {str(out.get('result'))[:300]}")
        u = out.get("usage", {})
        print(f"==> claude: input {u.get('input_tokens', 0)} + cache "
              f"{u.get('cache_read_input_tokens', 0) + u.get('cache_creation_input_tokens', 0)}, "
              f"output {u.get('output_tokens', 0)} tokens, {out.get('total_cost_usd', 0):.4f} USD (API rate)")
        sent = {akey(*key(r)) for r in todo}
        today = time.strftime("%Y-%m-%d")
        for a in out["structured_output"].get("assessments", []):
            k = akey(a.get("vuln_id"), a.get("package"), a.get("version"))
            if k in sent and a.get("verdict") in VERDICTS:
                done[k] = {"verdict": a["verdict"], "confidence": a.get("confidence", "low"),
                           "reason": a.get("reason", ""), "model": model, "date": today}
        save_json(store_path, done)
        missing = len(sent - done.keys())
        if missing:
            print(f"==> claude: {missing} findings without assessment, retried next run")
    current = {akey(*key(r)): r for r in good}
    counts = {v: 0 for v in VERDICTS}
    for k in current:
        if k in done:
            counts[done[k]["verdict"]] += 1
    print("==> claude verdicts for current findings: " + ", ".join(f"{v} {n}" for v, n in counts.items()))
    fresh = {akey(*key(r)) for r in todo}
    for verdict in ("affected", "needs_review"):
        for k, r in current.items():
            a = done.get(k)
            if a and a["verdict"] == verdict and k in fresh:
                print(f"{line(r)}\n        {verdict} ({a['confidence']}): {a['reason']}")
    suggest = os.path.join(state, "claude-whitelist-suggestions.csv")
    with open(suggest, "w", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL)
        w.writerow(["vuln_id", "package", "version_local", "version_local_regex", "comment"])
        for k, r in current.items():
            a = done.get(k)
            if a and a["verdict"] == "not_affected" and a["confidence"] == "high":
                w.writerow([r["vuln_id"], r["package"], r["version_local"], "",
                            f"claude {a['model']} {a['date']}: {a['reason']}"])
    print(f"==> not_affected (high confidence) as whitelist candidates: {suggest}")
    print("==> review before copying entries to home/vulnxscan-whitelist.csv")


def main():
    args = sys.argv[1:]
    if len(args) == 5 and args[0] == "report":
        report(*args[1:])
    elif len(args) == 2 and args[0] == "assess":
        assess(args[1])
    else:
        sys.exit("usage: vulnxscan-report.py report VULNS_CSV PREV_CSV CDX_OUT HOST\n"
                 "       vulnxscan-report.py assess STATE_DIR")


if __name__ == "__main__":
    main()
