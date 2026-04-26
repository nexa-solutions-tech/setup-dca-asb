# setup-dca

Role Ansible para preparar uma VPS Ubuntu e subir a stack da aplicacao DCA.

Esta pasta contem apenas o necessario para publicar a role em um repositório Git:

- `defaults/main.yml`
- `meta/main.yml`
- `requirements.yml`
- `tasks/main.yml`
- `tasks/validate.yml`
- `tasks/docker-install.yml`
- `tasks/app-stack.yml`
- `tasks/observability.yml`
- `VERSION`
- `release.sh`

## O que a role faz

- instala Docker Engine e Docker Compose V2
- valida os arquivos obrigatorios do projeto consumidor
- sincroniza os artefatos locais do `docker-compose` para o servidor
- sobe Traefik, frontend, backend e banco de dados
- sobe Grafana, Loki, Promtail e Prometheus

## Requisitos

- Ubuntu LTS no servidor alvo
- collections `community.docker` e `ansible.posix` instaladas no projeto consumidor

## Variaveis

| Variavel | Default | Descricao |
|---|---|---|
| `app_dir` | `/opt/app` | Diretorio de destino no servidor |
| `docker_arch` | `amd64` | Arquitetura do servidor (`amd64` ou `arm64`) |
| `setup_dca_local_docker_dir` | `{{ playbook_dir }}/../docker` | Pasta local do projeto consumidor com os arquivos Docker |

## Estrutura esperada no consumidor

```text
app-infra/
├── ansible/
│   ├── inventory.ini
│   ├── playbook.yml
│   ├── requirements.yml
│   └── group_vars/
│       └── mk_app.yml
└── docker/
    ├── .env
    ├── obs.env
    ├── docker-compose.yml
    ├── loki-config.yml
    ├── prometheus.yml
    └── promtail-config.yml
```

## Uso no playbook

```yaml
- name: Configura servidor
  hosts: mk_app
  become: true
  roles:
    - setup-dca
```

## Exemplo de requirements.yml

```yaml
collections:
  - name: community.docker
    version: ">=3.0.0"
  - name: ansible.posix
    version: ">=1.5.0"
```

No repositório consumidor, o `ansible/requirements.yml` continua incluindo a role via Git.

## CI e release

Quando esta pasta virar um repositório próprio, ela já estará preparada para:

- CI em `.github/workflows/ci.yml`
- release em `.github/workflows/release.yml`
- versionamento local com `release.sh`

O fluxo de validação faz:

- instalação das collections declaradas em `requirements.yml`
- `ansible-lint .`
- `ansible-playbook --syntax-check` usando um harness temporário que monta a role como `setup-dca`

## Publicacao

Se quiser subir a role para um repositório Git dedicado, publique o conteudo desta pasta `module/setup-dca/` como raiz do novo repositório.
