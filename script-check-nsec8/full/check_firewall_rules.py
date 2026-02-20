#!/usr/bin/env python3
"""check_firewall_rules.py - CheckMK local check firewall rules (Python puro)."""

import shutil
import subprocess
import sys

SERVICE = "Firewall_Rules"


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=False)
    return (result.stdout or "")


def count_rule_lines(output: str) -> int:
    return sum(1 for line in output.splitlines() if line.strip() and line[0].isupper())


def extract_policy(output: str) -> str:
    first = output.splitlines()[0] if output.splitlines() else ""
    token = "policy "
    if token in first:
        return first.split(token, 1)[1].split()[0]
    return "UNKNOWN"


def main() -> int:
    if shutil.which("iptables") is None:
        print("2 Firewall_Rules - iptables non trovato")
        return 0

    out_input = run(["iptables", "-L", "INPUT", "-n"])
    out_forward = run(["iptables", "-L", "FORWARD", "-n"])
    out_output = run(["iptables", "-L", "OUTPUT", "-n"])
    out_nat = run(["iptables", "-t", "nat", "-L", "-n"])

    input_rules = count_rule_lines(out_input)
    forward_rules = count_rule_lines(out_forward)
    output_rules = count_rule_lines(out_output)
    nat_rules = count_rule_lines(out_nat)
    total_rules = input_rules + forward_rules + output_rules

    input_policy = extract_policy(out_input)
    forward_policy = extract_policy(out_forward)

    if total_rules == 0:
        status, status_text = 2, "CRITICAL - Nessuna regola attiva"
    elif total_rules < 5:
        status, status_text = 1, "WARNING - Poche regole attive"
    else:
        status, status_text = 0, "OK"

    print(
        f"{status} {SERVICE} - INPUT:{input_rules} FORWARD:{forward_rules} OUTPUT:{output_rules} NAT:{nat_rules} "
        f"- Policy: INPUT={input_policy} FORWARD={forward_policy} - {status_text} "
        f"| input={input_rules} forward={forward_rules} output={output_rules} nat={nat_rules} total={total_rules}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
