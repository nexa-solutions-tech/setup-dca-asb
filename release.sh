#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

VERSION_FILE="VERSION"

if [ ! -f "$VERSION_FILE" ]; then
  echo "0.1.0" > "$VERSION_FILE"
  echo -e "${YELLOW}⚠️  Arquivo VERSION não encontrado. Criado com 0.1.0${RESET}"
fi

ANSIBLE_HOME_DIR="$(mktemp -d)"
export ANSIBLE_HOME="$ANSIBLE_HOME_DIR"
trap 'rm -rf "$ANSIBLE_HOME_DIR"' EXIT

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo -e "${RED}❌ ansible-playbook não encontrado no PATH.${RESET}"
  exit 1
fi

if ! command -v ansible-lint >/dev/null 2>&1; then
  echo -e "${RED}❌ ansible-lint não encontrado no PATH.${RESET}"
  exit 1
fi

if ! command -v ansible-galaxy >/dev/null 2>&1; then
  echo -e "${RED}❌ ansible-galaxy não encontrado no PATH.${RESET}"
  exit 1
fi

CURRENT=$(cat "$VERSION_FILE" | tr -d '[:space:]')
CUR_MAJOR=$(echo "$CURRENT" | cut -d. -f1)
CUR_MINOR=$(echo "$CURRENT" | cut -d. -f2)
CUR_PATCH=$(echo "$CURRENT" | cut -d. -f3)

NEXT_PATCH="$CUR_MAJOR.$CUR_MINOR.$((CUR_PATCH + 1))"
NEXT_MINOR="$CUR_MAJOR.$((CUR_MINOR + 1)).0"
NEXT_MAJOR="$((CUR_MAJOR + 1)).0.0"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       ansible-role · release         ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${CYAN}Versão atual:${RESET} ${BOLD}v$CURRENT${RESET}"
echo ""

echo -e "  ${CYAN}→ Instalando collections...${RESET}"
ansible-galaxy collection install -r requirements.yml > /dev/null

echo -e "  ${CYAN}→ Validando role com ansible-lint...${RESET}"
ansible-lint .

echo -e "  ${CYAN}→ Executando syntax-check...${RESET}"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/roles/setup-dca"
cp -R defaults meta tasks README.md requirements.yml "$TMP_DIR/roles/setup-dca/"

cat > "$TMP_DIR/playbook.yml" <<'EOF'
---
- name: Validate role
  hosts: localhost
  connection: local
  gather_facts: true
  roles:
    - setup-dca
EOF

cat > "$TMP_DIR/inventory.ini" <<'EOF'
[local]
localhost ansible_connection=local
EOF

ANSIBLE_ROLES_PATH="$TMP_DIR/roles" ansible-playbook -i "$TMP_DIR/inventory.ini" "$TMP_DIR/playbook.yml" --syntax-check > /dev/null

echo -e "  ${GREEN}✔  Validação concluída.${RESET}"
echo ""
read -p "$(echo -e "  ${BOLD}Mensagem do commit:${RESET} ")" MESSAGE

if [ -z "$MESSAGE" ]; then
  echo -e "\n${RED}❌ Mensagem do commit não pode ser vazia.${RESET}\n"
  exit 1
fi

echo ""
echo -e "  Qual versão deseja publicar?"
echo ""
echo -e "    ${BOLD}1)${RESET} Patch  →  v$NEXT_PATCH   ${CYAN}(bug fix, ajuste pequeno)${RESET}"
echo -e "    ${BOLD}2)${RESET} Minor  →  v$NEXT_MINOR   ${CYAN}(nova feature, retrocompatível)${RESET}"
echo -e "    ${BOLD}3)${RESET} Major  →  v$NEXT_MAJOR   ${CYAN}(breaking change)${RESET}"
echo ""

while true; do
  read -p "$(echo -e "  ${BOLD}Escolha (1, 2 ou 3):${RESET} ")" CHOICE
  case $CHOICE in
    1) VERSION="$NEXT_PATCH"; break ;;
    2) VERSION="$NEXT_MINOR"; break ;;
    3) VERSION="$NEXT_MAJOR"; break ;;
    *) echo -e "  ${RED}❌ Opção inválida. Digite 1, 2 ou 3.${RESET}" ;;
  esac
done

echo ""
echo -e "  ${YELLOW}Resumo do release:${RESET}"
echo -e "    Versão   →  ${BOLD}v$VERSION${RESET}"
echo -e "    Commit   →  \"$MESSAGE\""
echo -e "    Tag git  →  v$VERSION"
echo ""

read -p "$(echo -e "  ${BOLD}Confirmar? (s/N):${RESET} ")" CONFIRM
if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
  echo -e "\n  ${YELLOW}Cancelado.${RESET}\n"
  exit 0
fi

echo ""
echo -e "  ${CYAN}→ Atualizando VERSION para $VERSION...${RESET}"
echo "$VERSION" > "$VERSION_FILE"

echo -e "  ${CYAN}→ Commit e push...${RESET}"
git add .
git commit -m "$MESSAGE"
git push origin HEAD

echo -e "  ${CYAN}→ Criando tag v$VERSION...${RESET}"
git tag "v$VERSION"
git push origin "v$VERSION"

echo ""
echo -e "${GREEN}${BOLD}✅ Publicado com sucesso: v$VERSION${RESET}"
echo ""
