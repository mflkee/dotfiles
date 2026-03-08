#!/usr/bin/env python3
"""Find domains for a service from certificate transparency logs (crt.sh)."""

from __future__ import annotations

import argparse
import csv
import json
import re
import socket
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import quote, urlparse
from urllib.request import Request, urlopen


HOST_RE = re.compile(r"^(?=.{1,253}$)(?!-)(?:[a-z0-9-]{1,63}\.)+[a-z0-9-]{2,63}$")
RAW_DOMAIN_RE = re.compile(r"(?<![a-z0-9-])(?:\*\.)?(?:[a-z0-9-]{1,63}\.)+[a-z0-9-]{2,63}(?![a-z0-9-])")


def normalize_input(value: str) -> str:
    value = value.strip().lower()
    if "://" in value:
        parsed = urlparse(value)
        value = parsed.hostname or ""
    else:
        value = value.split("/")[0]
        value = value.split(":")[0]
    value = value.strip(".")
    if value.startswith("*."):
        value = value[2:]
    return value


def valid_host(host: str) -> bool:
    return bool(HOST_RE.fullmatch(host))


def extract_hosts(blob: str) -> set[str]:
    found: set[str] = set()
    for match in RAW_DOMAIN_RE.finditer(blob.lower()):
        host = match.group(0).strip(".")
        if host.startswith("*."):
            host = host[2:]
        if valid_host(host):
            found.add(host)
    return found


def fetch_crtsh_json(query: str, timeout: int) -> list[dict]:
    encoded_query = quote(query, safe="")
    url = f"https://crt.sh/?q={encoded_query}&output=json"
    req = Request(
        url,
        headers={
            "User-Agent": "domain-scout/1.0 (+https://crt.sh)",
            "Accept": "application/json, text/plain;q=0.9,*/*;q=0.8",
        },
    )
    with urlopen(req, timeout=timeout) as response:
        raw = response.read().decode("utf-8", "replace")
    try:
        payload = json.loads(raw)
        if isinstance(payload, list):
            return payload
        return []
    except json.JSONDecodeError:
        return [{"name_value": "\n".join(sorted(extract_hosts(raw)))}]


def collect_from_rows(rows: list[dict]) -> set[str]:
    names: set[str] = set()
    for row in rows:
        for key in ("name_value", "common_name"):
            val = row.get(key, "")
            if not isinstance(val, str):
                continue
            for host in extract_hosts(val.replace("\r", "\n")):
                names.add(host)
    return names


def dns_resolves(host: str) -> bool:
    try:
        socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
        return True
    except OSError:
        return False


def filter_scope(hosts: set[str], domain: str, all_sans: bool) -> list[str]:
    scoped: list[str] = []
    for host in hosts:
        if not valid_host(host):
            continue
        if all_sans or host == domain or host.endswith("." + domain):
            scoped.append(host)
    return sorted(set(scoped))


def write_output(domains: list[str], output_format: str, output_path: Path | None) -> None:
    if output_format == "txt":
        rendered = "\n".join(domains) + ("\n" if domains else "")
    elif output_format == "json":
        rendered = json.dumps(domains, ensure_ascii=False, indent=2) + "\n"
    else:
        lines = ["domain"]
        for domain in domains:
            lines.append(domain)
        rendered = "\n".join(lines) + "\n"

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered, encoding="utf-8")
    else:
        sys.stdout.write(rendered)


def write_csv(domains: list[str], output_path: Path | None) -> None:
    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        handle = output_path.open("w", encoding="utf-8", newline="")
        close_after = True
    else:
        handle = sys.stdout
        close_after = False

    try:
        writer = csv.writer(handle)
        writer.writerow(["domain"])
        for domain in domains:
            writer.writerow([domain])
    finally:
        if close_after:
            handle.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="domain-scout",
        description="Collect domains for a service using crt.sh (certificate transparency).",
    )
    parser.add_argument("domain", help="Base domain, e.g. youtube.com")
    parser.add_argument(
        "-a",
        "--all-sans",
        action="store_true",
        help="Return all domains from matching certificates, not only *.base-domain.",
    )
    parser.add_argument(
        "--dns-check",
        action="store_true",
        help="Keep only domains that resolve in DNS.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=20,
        help="Parallel workers for DNS checks (default: 20).",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=30,
        help="Network timeout in seconds (default: 30).",
    )
    parser.add_argument(
        "-f",
        "--format",
        choices=("txt", "json", "csv"),
        default="txt",
        help="Output format (default: txt).",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output file path (default: stdout).",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    base_domain = normalize_input(args.domain)
    if not valid_host(base_domain):
        print(f"Invalid domain: {args.domain}", file=sys.stderr)
        return 2

    queries = [f"%.{base_domain}", base_domain]
    all_hosts: set[str] = set()
    for query in queries:
        try:
            rows = fetch_crtsh_json(query, timeout=args.timeout)
        except Exception as exc:
            print(f"Warning: failed to fetch {query}: {exc}", file=sys.stderr)
            continue
        all_hosts.update(collect_from_rows(rows))

    domains = filter_scope(all_hosts, base_domain, all_sans=args.all_sans)
    if args.dns_check and domains:
        checked: list[str] = []
        workers = max(1, args.workers)
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {pool.submit(dns_resolves, domain): domain for domain in domains}
            for future in as_completed(futures):
                domain = futures[future]
                try:
                    if future.result():
                        checked.append(domain)
                except Exception:
                    continue
        domains = sorted(checked)

    output_path = Path(args.output).expanduser() if args.output else None
    if args.format == "csv":
        write_csv(domains, output_path)
    else:
        write_output(domains, args.format, output_path)

    destination = str(output_path) if output_path else "stdout"
    print(
        f"domain-scout: found {len(domains)} domains for {base_domain} -> {destination}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
