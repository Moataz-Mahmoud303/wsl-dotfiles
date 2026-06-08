# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# ═══════════════════════════════════════════════════════════════
# PATH & DS-EKS-Tools
# ═══════════════════════════════════════════════════════════════
export PATH="/usr/local/bin:/home/moataz/.local/bin:$PATH"

if [ -f /home/moataz/work/tools/setup.sh ]; then
    source /home/moataz/work/tools/setup.sh
fi

# =====================================================================
# AWS Login - fzf profile picker + WSL2 browser auto-open
# =====================================================================
awslogin() {
    if ! command -v fzf &> /dev/null; then
        echo "Error: fzf is required. Install with: sudo apt-get install fzf"
        return 1
    fi
    if [ ! -f ~/.aws/config ]; then
        echo "Error: ~/.aws/config not found."
        return 1
    fi

    local profiles selected temp_file device_url user_code aws_pid login_status
    profiles=$(grep -E "^\[profile " ~/.aws/config | sed 's/\[profile //;s/\]//' | sort)

    if [ -z "$profiles" ]; then
        echo "No AWS profiles found in ~/.aws/config"
        return 1
    fi

    selected=$(echo "$profiles" | fzf \
        --preview 'grep -A 10 "^\[profile {}\]" ~/.aws/config' \
        --header='Select AWS profile to login (ESC to cancel)' \
        --preview-window=right:50%)

    if [ -z "$selected" ]; then
        echo "Cancelled."
        return 0
    fi

    echo "🔐 Logging in: $selected"
    temp_file=$(mktemp)
    (aws sso login --profile "$selected" 2>&1) > "$temp_file" &
    aws_pid=$!

    echo "⏳ Waiting for SSO URL..."
    device_url=""
    user_code=""
    for i in $(seq 1 30); do
        sleep 0.5
        device_url=$(grep -oE 'https://[^ ]+user_code=[^ ]+' "$temp_file" 2>/dev/null | head -1)
        [ -z "$device_url" ] && device_url=$(grep -oE 'https://[^ ]+(awsapps\.com|amazonaws\.com)[^ ]*' "$temp_file" 2>/dev/null | head -1)
        [ -n "$device_url" ] && { user_code=$(grep -oE '[A-Z]{4}-[A-Z]{4}' "$temp_file" 2>/dev/null | head -1); break; }
        kill -0 "$aws_pid" 2>/dev/null || break
    done

    if [ -n "$device_url" ]; then
        echo ""
        echo "📱 Device authentication required"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if [ -n "$user_code" ]; then
            echo "  🔑 Code: $user_code"
            command -v clip.exe &>/dev/null && echo -n "$user_code" | clip.exe && echo "  📋 Code copied to clipboard!"
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🌐 Opening browser..."
        if grep -qi microsoft /proc/version 2>/dev/null; then
            powershell.exe -NoProfile -Command "Start-Process '$device_url'" 2>/dev/null \
                || cmd.exe /c start "" "$device_url" 2>/dev/null
        else
            xdg-open "$device_url" 2>/dev/null || echo "Please visit: $device_url"
        fi
        echo "✅ Browser opened! Waiting for authentication..."
    else
        echo "⚠️  Could not detect SSO URL. Output:" && cat "$temp_file"
    fi

    wait "$aws_pid"
    login_status=$?
    rm -f "$temp_file"

    echo ""
    if [ "$login_status" -eq 0 ]; then
        echo "✅ Logged in: $selected"
        echo "   Verify: aws sts get-caller-identity --profile $selected"
    else
        echo "❌ Login failed or cancelled"
    fi
    return "$login_status"
}

# =====================================================================
# AWS Profile selector (awsfzf)
# =====================================================================
awsfzf() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "[ERROR] fzf not found. Install: sudo apt-get install fzf" >&2; return 1
  fi
  local profiles profile identity
  profiles=$(aws configure list-profiles 2>/dev/null | sort)
  [ -z "$profiles" ] && { echo "[ERROR] No AWS profiles found" >&2; return 1; }

  profile=$(echo "$profiles" | fzf \
    --preview='aws sts get-caller-identity --profile {} --output table 2>/dev/null || echo "Not accessible - run awslogin first"' \
    --preview-window=right:45% --header='Select AWS Profile' --border --margin=1 --padding=1) \
    || { echo "[ERROR] Cancelled" >&2; return 1; }

  export AWS_PROFILE="$profile"
  export AWS_DEFAULT_REGION="ap-southeast-2"

  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "[WARN] Credentials expired for $profile, logging in..."
    awslogin
    aws sts get-caller-identity >/dev/null 2>&1 || { echo "[ERROR] Login failed" >&2; unset AWS_PROFILE; return 1; }
  fi

  identity=$(aws sts get-caller-identity --output json 2>/dev/null)
  echo ""
  echo "=========================================="
  echo "[OK] Profile:  $profile"
  echo "     Account:  $(echo "$identity" | jq -r '.Account')"
  echo "     ARN:      $(echo "$identity" | jq -r '.Arn')"
  echo "=========================================="
}

alias whoamiaws='aws sts get-caller-identity --output table'
alias awsclear='unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN && echo "[OK] AWS env cleared"'

# AWS CLI autocomplete
complete -C '/usr/local/bin/aws_completer' aws 2>/dev/null

# =====================================================================
# General aliases
# =====================================================================
alias k='kubectl'
alias h='helm'
alias tf='terraform'
alias d='docker'

# Kubernetes completions
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash 2>/dev/null)
    complete -o default -F __start_kubectl k 2>/dev/null
fi
if command -v helm &> /dev/null; then
    source <(helm completion bash 2>/dev/null)
fi

# =====================================================================
# PRIVOXY PROXY CONFIGURATION (corporate proxy)
# =====================================================================
proxy_on() {
  export HTTP_PROXY="http://127.0.0.1:8118"
  export HTTPS_PROXY="http://127.0.0.1:8118"
  export http_proxy="$HTTP_PROXY"
  export https_proxy="$HTTPS_PROXY"
  export NO_PROXY="localhost,127.0.0.1,::1,.local,.amazonaws.com,.eks.amazonaws.com,kubernetes.io,6.6.0.80,*.sk1.ap-southeast-2.eks.amazonaws.com"
  export no_proxy="$NO_PROXY"
  echo "[OK] Proxy ON ($HTTP_PROXY)"
}

proxy_off() {
  unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy
  echo "[OK] Proxy OFF"
}

# Auto-enable proxy if Privoxy is running
if timeout 1 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/8118" 2>/dev/null; then
  proxy_on
else
  echo "[⚠] Privoxy not running on 127.0.0.1:8118 - proxy disabled"
fi

# =====================================================================
# KTOOLS (Kubernetes tools)
# =====================================================================
[ -f ~/work/repo/dotsource/ktools.sh ] && source ~/work/repo/dotsource/ktools.sh

ktools() {
  cat <<'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                       ⚙️  KTOOLS - Kubernetes Tools                       ║
╚═══════════════════════════════════════════════════════════════════════════╝
🔄 CLUSTER & CONTEXT MANAGEMENT
  kswitch    │ Switch between AWS profiles and EKS clusters
  krefresh   │ Update kubeconfig for selected EKS cluster
  kns        │ Interactively switch kubectl namespace
📊 POD & NODE INSPECTION
  kpods      │ List pods in current namespace with node info
  kgp        │ kubectl get pods
  kgpa       │ kubectl get pods -A (all namespaces)
🔍 LOGGING & DEBUGGING
  klogs      │ Stream logs from a selected pod container
  kexec      │ Execute shell/command in a selected pod
🚀 DEPLOYMENT MANAGEMENT
  kgetdeployment  │ Export deployment YAML to file
  kdeldeployment  │ Interactively select and delete a deployment
💡 ENHANCED TOOLS
  kdash      │ Cluster status dashboard
  kctx       │ Show current cluster & namespace
  kaswitch   │ Switch AWS profile AND update kubeconfig
EOF
}

kdash() {
  if ! command -v kubectl >/dev/null 2>&1; then echo "[ERROR] kubectl not found" >&2; return 1; fi
  local cluster namespace nodes ready_nodes pods running_pods pvcs
  cluster=$(kubectl config current-context 2>/dev/null | cut -d'/' -f2 || echo "unknown")
  namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default")
  nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready")
  pods=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
  running_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c "Running")
  pvcs=$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l)
  cat <<EOF
╔════════════════════════════════════════════════════════════════════╗
║                   📊 CLUSTER STATUS DASHBOARD                      ║
╚════════════════════════════════════════════════════════════════════╝
  🏗️  CLUSTER:    $cluster
  📍 NAMESPACE:   $namespace
  🖥️  NODES:      $ready_nodes/$nodes ready
  📦 PODS:        $running_pods/$pods running
  💾 PVC:         $pvcs persistent volumes
════════════════════════════════════════════════════════════════════
EOF
}

kctx() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📍 Cluster:     $(kubectl config current-context 2>/dev/null | cut -d'/' -f2 || echo unknown)"
  echo "   Namespace:   $(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo default)"
  echo "   AWS Profile: ${AWS_PROFILE:-none}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

kaswitch() {
  echo "[*] Switching AWS profile and EKS cluster..."
  awsfzf || return 1
  kswitch || return 1
  echo "[✓] Done! Use 'kctx' to verify"
}

# =====================================================================
# DOTFILES BACKUP
# =====================================================================
backup_dotfiles() {
    bash ~/.dotfiles-backup.sh && echo "✅ Backed up to GitHub (dotfiles-backup branch)"
}

# Auto-backup .bashrc to OneDrive on shell start (only if changed)
_BASHRC_OD="/mnt/c/Users/W76715/OneDrive - Woodside Energy Ltd/wsl/Bashrc"
if [ -d "$_BASHRC_OD" ]; then
    _latest=$(ls -t "$_BASHRC_OD"/.bashrc_* 2>/dev/null | head -1)
    if [ -z "$_latest" ] || ! diff -q ~/.bashrc "$_latest" &>/dev/null; then
        mkdir -p "$_BASHRC_OD"
        cp ~/.bashrc "$_BASHRC_OD/.bashrc_$(date +%Y%m%d_%H%M%S)" 2>/dev/null
    fi
    unset _latest
fi
unset _BASHRC_OD
