#!/usr/bin/env python3
# Grant SSH access to AWAUBDEV01112 for a user
# Handles: AD home path, home dir 775→755, key in correct path, SSSD PAM access
#
# Usage: ./add-dev-ssh-key.sh <wopid> '<ssh-pubkey>'
# Example: ./add-dev-ssh-key.sh wa0wid 'ssh-ed25519 AAAA... user@host'
import json, subprocess, sys, time, os

INSTANCE_ID = "i-00d70946cb4d92dad"
REGION = "ap-southeast-2"
AWS_PROFILE = os.environ.get("AWS_PROFILE", "dstools-prd")

if len(sys.argv) < 3:
    print("Usage: add-dev-ssh-key.sh <wopid> '<ssh-pubkey>'")
    sys.exit(1)

u, k = sys.argv[1], sys.argv[2]
print(f"Adding SSH key for '{u}' on {INSTANCE_ID}...")

# Extract just the key body for grep matching (ignore comment at end)
key_match = k.split()[1] if len(k.split()) >= 2 else k

script = "\n".join([
    "set -e",
    f"echo '=== 1. User check ==='",
    f"id '{u}' >/dev/null 2>&1 && echo 'user exists' || {{ useradd -m -s /bin/bash '{u}' && usermod -aG sudo '{u}' && echo 'user created'; }}",

    f"echo '=== 2. Home directory (AD path) ==='",
    f"H=$(getent passwd '{u}' | cut -d: -f6); H=${{H:-/home/{u}}}",
    f"echo \"home=$H\"",

    f"echo '=== 3. Fix home dir perms (775→755 for SSH StrictModes) ==='",
    f"chmod 755 $H && echo 'home chmod ok'",

    f"echo '=== 4. SSH key ==='",
    "D=$H/.ssh; K=$D/authorized_keys",
    f"mkdir -p $D",
    f"chown {u} $H $D",
    f"chmod 700 $D",
    f"touch $K && chown {u} $K && chmod 600 $K",
    # Also copy keys from wrong path /home/<user>/.ssh/ if they exist there
    f"[ -f /home/{u}/.ssh/authorized_keys ] && [ \"$H\" != \"/home/{u}\" ] && cat /home/{u}/.ssh/authorized_keys >> $K 2>/dev/null && sort -u -o $K $K && echo 'merged keys from /home/{u}' || true",
    f"grep -qF '{key_match}' $K 2>/dev/null && echo 'key already present' || {{ printf '%s\\n' '{k}' >> $K && echo 'key added'; }}",

    f"echo '=== 5. SSSD access ==='",
    f"if grep -q 'simple_allow_groups' /etc/sssd/sssd.conf 2>/dev/null; then",
    f"  if id '{u}' 2>/dev/null | grep -qi 'right-usr-sv-science.dev.server'; then",
    f"    echo 'sssd: already in allowed group'",
    f"  elif grep -q '{u}' /etc/sssd/sssd.conf 2>/dev/null; then",
    f"    echo 'sssd: already in simple_allow_users'",
    f"  else",
    f"    if grep -q '^simple_allow_users' /etc/sssd/sssd.conf; then",
    f"      sed -i 's/^simple_allow_users = /simple_allow_users = {u}, /' /etc/sssd/sssd.conf",
    f"    else",
    f"      sed -i '/^simple_allow_groups/a simple_allow_users = {u}' /etc/sssd/sssd.conf",
    f"    fi",
    f"    systemctl restart sssd && echo 'sssd: added {u}'",
    f"  fi",
    f"fi",

    f"echo '=== 6. Verify ==='",
    f"ls -la $D/",
    f"echo '=== DONE ==='",
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
