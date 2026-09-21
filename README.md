# TABD — Problema Saúde

Ambiente PostgreSQL para o problema de clínica.

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
scripts/testes.sql              roteiro de testes T1–T7
queries/                        pré-processamento e consultas analíticas
docker-compose.yml              banco e serviços auxiliares
Makefile                        comandos de operação
docs/                           documentação e apresentação do trabalho
```

## Estrutura do banco

O banco representa o atendimento de uma clínica e é composto por cinco tabelas operacionais:

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

O setup também cria os seguintes objetos analíticos e de auditoria:

| Objeto | Finalidade |
| --- | --- |
| `mv_padroes_faltas` | Total de agendamentos e faltas por especialidade e dia da semana |
| `mv_horarios_criticos_faltas` | Ranking dos dias e horários com mais faltas em cada especialidade |
| `mv_ranking_exames_idade` | Ranking dos exames solicitados por faixa etária |
| `log_auditoria_faltas` | Histórico das consultas alteradas de comparecimento para falta |
| `registrar_falta()` / `trg_auditoria_falta` | Função e trigger responsáveis pelo registro automático das faltas |

As views materializadas são atualizadas automaticamente ao final de `make db-seed`.

## Uso

```bash
make db-up                       # sobe somente o PostgreSQL
make db-setup                       # garante que a estrutura definitiva existe
make db-seed                        # executa o setup e reaplica a carga idempotente
make db-status                      # mostra containers e contagens das tabelas
make db-analises                    # executa os arquivos de queries/
make db-test                        # executa o roteiro de testes
make db-logs                        # acompanha os logs do PostgreSQL
make db-down                        # para os containers e preserva os dados
```

## Pré-processamento, consultas analíticas e testes

| Arquivo | Conteúdo |
| --- | --- |
| `queries/00_pre_processamento.sql` | Verificações de KDD: nulos, chaves estrangeiras órfãs, domínio de `compareceu`, duplicidades, derivações de dia/hora/faixa etária e incoerências conhecidas da massa |
| `queries/01_faltas_por_especialidade.sql` | Faltas e taxa de não comparecimento por especialidade |
| `queries/02_horarios_criticos.sql` | Ranking dos períodos críticos e taxa de faltas de um período específico |
| `queries/03_exames_por_faixa_etaria.sql` | Ranking dos exames solicitados por faixa etária |
| `scripts/testes.sql` | Roteiro de testes T1–T7, com os resultados esperados em comentário |

As consultas de `queries/00_pre_processamento.sql` são apenas de verificação e não alteram dados: a massa fornecida é preservada como está, inclusive as duplicidades identificadas.

Os resultados esperados anotados nos arquivos valem para os CSVs de `data/`. Os números de faixa etária dependem da data de execução, porque o cálculo usa `CURRENT_DATE`.

## Notas

O arquivo `database/setup.sql` é a definição única e definitiva da estrutura do banco. Este projeto não utiliza migrations incrementais nem prevê alterações futuras no esquema.

A carga faz `UPSERT` por `id`: linhas presentes nos CSVs são inseridas ou atualizadas, mas linhas locais ausentes dos arquivos não são removidas.

## Reinicialização completa

```bash
make db-reset
```
