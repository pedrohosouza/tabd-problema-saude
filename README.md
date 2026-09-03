# TABD — Problema Saúde

Ambiente PostgreSQL para o problema de clínica, com estrutura definitiva e carga idempotente dos CSVs fornecidos.

## Requisitos

- Docker com o plugin Docker Compose
- GNU Make

O PostgreSQL 18 é exposto localmente na porta `5432`. As credenciais acadêmicas de desenvolvimento são:

```text
banco:   tabd_saude
usuário: tabd_saude
senha:   tabd_saude
```

## Estrutura do projeto

```text
data/                           CSVs versionados
database/setup.sql              estrutura definitiva do banco
scripts/seed.sql                importação transacional dos CSVs
docker-compose.yml              banco e serviços auxiliares
Makefile                        comandos de operação
```

## Estrutura do banco

O banco representa o atendimento de uma clínica e é composto por cinco tabelas:

| Tabela | Colunas |
| --- | --- |
| `especialidades` | `id INTEGER` (PK, identity), `nome TEXT` |
| `pacientes` | `id INTEGER` (PK, identity), `nome TEXT`, `data_nascimento DATE`, `sexo CHAR(1)` (`M` ou `F`) |
| `exames` | `id INTEGER` (PK, identity), `nome TEXT` |
| `consultas` | `id INTEGER` (PK, identity), `paciente_id INTEGER` (FK), `especialidade_id INTEGER` (FK), `data_hora TIMESTAMP`, `compareceu BOOLEAN` |
| `exames_solicitados` | `id INTEGER` (PK, identity), `paciente_id INTEGER` (FK), `exame_id INTEGER` (FK), `data_solicitacao DATE` |

Relacionamentos:

- `consultas.paciente_id` → `pacientes.id`
- `consultas.especialidade_id` → `especialidades.id`
- `exames_solicitados.paciente_id` → `pacientes.id`
- `exames_solicitados.exame_id` → `exames.id`

Cada tabela é alimentada pelo CSV de mesmo nome em `data/`. Durante a importação de `consultas.csv`, os valores `Sim` e `Nao` da coluna `compareceu` são convertidos, respectivamente, para `TRUE` e `FALSE`.

## Uso

```bash
make up                          # sobe o banco, cria a estrutura e importa os CSVs
make db-up                       # sobe somente o PostgreSQL
make setup                       # garante que a estrutura definitiva existe
make seed                        # executa o setup e reaplica a carga idempotente
make status                      # mostra containers e contagens das tabelas
make logs                        # acompanha os logs do PostgreSQL
make down                        # para os containers e preserva os dados
```

O arquivo `database/setup.sql` é a definição única e definitiva da estrutura do banco. Este projeto não utiliza migrations incrementais nem prevê alterações futuras no esquema.

A carga faz `UPSERT` por `id`: linhas presentes nos CSVs são inseridas ou atualizadas, mas linhas locais ausentes dos arquivos não são removidas.

## Reinicialização completa

```bash
make db-reset
```