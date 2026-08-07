#!/usr/bin/env python3
# Usage: ./add-dev-ssh-key.sh <linux-username> "<ssh-public-key>"
import json, subprocess, sys, time

INSTANCE_ID = "i-00d70946cb4d92dad"
REGION = "ap-southeast-2"
import os
AWS_PROFILE = os.environ.get("AWS_PROFILE", "dstools-prd")

if len(sys.argv) < 3:
    print("Usage: add-dev-ssh-key.sh <username> '<ssh-pubkey>'")
    sys.exit(1)

u, k = sys.argv[1], sys.argv[2]
print(f"Adding SSH key for '{u}' on {INSTANCE_ID}...")

script = "\n".join([
    "set -e",
    f"id '{u}' >/dev/null 2>&1 || {{ useradd -m -s /bin/bash '{u}' && usermod -aG sudo '{u}'; }}",
    # AD-joined instances use /home/wde.woodside.com.au/<user> as home
    f"H=$(getent passwd '{u}' | cut -d: -f6); H=${{H:-/home/{u}}}",
    "D=$H/.ssh; K=$D/authorized_keys",
    # Home must be 755 (not 775) or SSH StrictModes rejects it
    f"chmod 755 $H",
    f"mkdir -p $D && chown {u} $H $D && chmod 700 $D",
    f"touch $K && chown {u} $K && chmod 600 $K",
    f"grep -qF '{k}' $K 2>/dev/null && echo 'already present' || {{ printf '%s\\n' '{k}' >> $K && echo 'added'; }}",
    # SSSD simple_allow_users: add user if not in an allowed group
    f"if grep -q 'simple_allow_groups' /etc/sssd/sssd.conf 2>/dev/null; then"
    f"  if ! id '{u}' 2>/dev/null | grep -qi 'right-usr-sv-science.dev.server'; then"
    f"    if grep -q 'simple_allow_users' /etc/sssd/sssd.conf; then"
    f"      grep -q '{u}' /etc/sssd/sssd.conf || sed -i 's/^simple_allow_users = /simple_allow_users = {u}, /' /etc/sssd/sssd.conf"
    f"    ; else"
    f"      sed -i '/^simple_allow_groups/a simple_allow_users = {u}' /etc/sssd/sssd.conf"
    f"    ; fi"
    f"    systemctl restart sssd && echo 'sssd: added {u} to simple_allow_users'"
    f"  ; else"
    f"    echo 'sssd: {u} already in allowed group'"
    f"  ; fi"
    f"; fi",
])

params = json.dumps({"commands": [script]})
env = os.environ.copy()
env["AWS_PROFILE"] = AWS_PROFILE

r = subprocess.run([
    "aws", "ssm", "send-command",
    "--instance-ids", INSTANCE_ID,
    "--document-name", "AWS-RunShellScript",
    "--parameters", params,
    "--region", REGION,
    "--query", "Command.CommandId",
    "--output", "text"
], capture_output=True, text=True, env=env)

if r.returncode != 0:
    print("ERROR:", r.stderr); sys.exit(1)

cmd_id = r.stdout.strip()
print(f"SSM command: {cmd_id} -- waiting...")
time.sleep(6)

r2 = subprocess.run([
    "aws", "ssm", "get-command-invocation",
    "--command-id", cmd_id,
    "--instance-id", INSTANCE_ID,
    "--region", REGION,
    "--output", "json"
], capture_output=True, text=True, env=env)

d = json.loads(r2.stdout)
status = d["Status"]
stdout = d["StandardOutputContent"].strip()
stderr = d["StandardErrorContent"].strip()

print(f"Status: {status}")
if stdout: print(f"Output: {stdout}")
if stderr: print(f"Errors: {stderr}")

if status == "Success":
    print(f"Done. {u} can now SSH to AWAUBDEV01112.")
else:
    sys.exit(1)
