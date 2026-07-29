#!/usr/bin/env bash
# Durcissement d'un VPS Ubuntu ou Debian fraichement provisionne.
# A executer une seule fois, en root, apres avoir cree un utilisateur non root
# et copie sa cle publique SSH. Relire avant execution.
set -euo pipefail

DEPLOY_USER="${1:?Usage: harden-server.sh <utilisateur> [port_ssh]}"
SSH_PORT="${2:-22}"

echo "== Mise a jour du systeme =="
apt-get update -qq && apt-get upgrade -y -qq

echo "== Installation des outils =="
apt-get install -y -qq ufw fail2ban unattended-upgrades curl ca-certificates

echo "== Durcissement SSH =="
# Sauvegarde avant toute modification
cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%F-%H%M)"
cat > /etc/ssh/sshd_config.d/99-hardening.conf << CONF
Port ${SSH_PORT}
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers ${DEPLOY_USER}
CONF
sshd -t && systemctl reload ssh

echo "== Pare-feu =="
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}"/tcp comment 'SSH'
ufw allow 80/tcp   comment 'HTTP'
ufw allow 443/tcp  comment 'HTTPS'
ufw --force enable

echo "== Fail2ban =="
cat > /etc/fail2ban/jail.local << CONF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd

[sshd]
enabled = true
port    = ${SSH_PORT}
maxretry = 3
bantime  = 86400

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true
CONF
systemctl enable --now fail2ban
systemctl restart fail2ban

echo "== Mises a jour de securite automatiques =="
cat > /etc/apt/apt.conf.d/20auto-upgrades << CONF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF

echo "== Parametres noyau =="
cat > /etc/sysctl.d/99-hardening.conf << CONF
net.ipv4.conf.all.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.tcp_syncookies=1
kernel.randomize_va_space=2
CONF
sysctl --system > /dev/null

echo
echo "Termine. Verifier AVANT de fermer la session courante :"
echo "  ssh -p ${SSH_PORT} ${DEPLOY_USER}@<ip>"
echo "Garder cette session ouverte tant que la connexion n'est pas confirmee."
