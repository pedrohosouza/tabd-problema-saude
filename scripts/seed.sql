\set ON_ERROR_STOP on

BEGIN;

CREATE TEMPORARY TABLE seed_especialidades (
    id INTEGER,
    nome TEXT
) ON COMMIT DROP;

CREATE TEMPORARY TABLE seed_exames (
    id INTEGER,
    nome TEXT
) ON COMMIT DROP;

CREATE TEMPORARY TABLE seed_pacientes (
    id INTEGER,
    nome TEXT,
    data_nascimento DATE,
    sexo CHAR(1)
) ON COMMIT DROP;

CREATE TEMPORARY TABLE seed_consultas (
    id INTEGER,
    paciente_id INTEGER,
    especialidade_id INTEGER,
    data_hora TIMESTAMP WITHOUT TIME ZONE,
    compareceu TEXT
) ON COMMIT DROP;

CREATE TEMPORARY TABLE seed_exames_solicitados (
    id INTEGER,
    paciente_id INTEGER,
    exame_id INTEGER,
    data_solicitacao DATE
) ON COMMIT DROP;

\copy seed_especialidades FROM '/data/especialidades.csv' WITH (FORMAT csv, HEADER true)
\copy seed_exames FROM '/data/exames.csv' WITH (FORMAT csv, HEADER true)
\copy seed_pacientes FROM '/data/pacientes.csv' WITH (FORMAT csv, HEADER true)
\copy seed_consultas FROM '/data/consultas.csv' WITH (FORMAT csv, HEADER true)
\copy seed_exames_solicitados FROM '/data/exames_solicitados.csv' WITH (FORMAT csv, HEADER true)

DO $validation$
BEGIN
    IF EXISTS (
        SELECT 1 FROM seed_consultas WHERE compareceu NOT IN ('Sim', 'Nao') OR compareceu IS NULL
    ) THEN
        RAISE EXCEPTION 'consultas.csv contém compareceu diferente de Sim/Nao';
    END IF;
END
$validation$;

INSERT INTO especialidades (id, nome)
SELECT id, nome FROM seed_especialidades
ON CONFLICT (id) DO UPDATE SET nome = EXCLUDED.nome;

INSERT INTO exames (id, nome)
SELECT id, nome FROM seed_exames
ON CONFLICT (id) DO UPDATE SET nome = EXCLUDED.nome;

INSERT INTO pacientes (id, nome, data_nascimento, sexo)
SELECT id, nome, data_nascimento, sexo FROM seed_pacientes
ON CONFLICT (id) DO UPDATE SET
    nome = EXCLUDED.nome,
    data_nascimento = EXCLUDED.data_nascimento,
    sexo = EXCLUDED.sexo;

INSERT INTO consultas (id, paciente_id, especialidade_id, data_hora, compareceu)
SELECT
    id,
    paciente_id,
    especialidade_id,
    data_hora,
    CASE compareceu WHEN 'Sim' THEN TRUE WHEN 'Nao' THEN FALSE END
FROM seed_consultas
ON CONFLICT (id) DO UPDATE SET
    paciente_id = EXCLUDED.paciente_id,
    especialidade_id = EXCLUDED.especialidade_id,
    data_hora = EXCLUDED.data_hora,
    compareceu = EXCLUDED.compareceu;

INSERT INTO exames_solicitados (id, paciente_id, exame_id, data_solicitacao)
SELECT id, paciente_id, exame_id, data_solicitacao FROM seed_exames_solicitados
ON CONFLICT (id) DO UPDATE SET
    paciente_id = EXCLUDED.paciente_id,
    exame_id = EXCLUDED.exame_id,
    data_solicitacao = EXCLUDED.data_solicitacao;

SELECT setval(
    pg_get_serial_sequence('especialidades', 'id'),
    COALESCE(MAX(id), 1),
    COUNT(*) > 0
) FROM especialidades;

SELECT setval(
    pg_get_serial_sequence('exames', 'id'),
    COALESCE(MAX(id), 1),
    COUNT(*) > 0
) FROM exames;

SELECT setval(
    pg_get_serial_sequence('pacientes', 'id'),
    COALESCE(MAX(id), 1),
    COUNT(*) > 0
) FROM pacientes;

SELECT setval(
    pg_get_serial_sequence('consultas', 'id'),
    COALESCE(MAX(id), 1),
    COUNT(*) > 0
) FROM consultas;

SELECT setval(
    pg_get_serial_sequence('exames_solicitados', 'id'),
    COALESCE(MAX(id), 1),
    COUNT(*) > 0
) FROM exames_solicitados;

REFRESH MATERIALIZED VIEW mv_padroes_faltas;
REFRESH MATERIALIZED VIEW mv_horarios_criticos_faltas;
REFRESH MATERIALIZED VIEW mv_ranking_exames_idade;

COMMIT;
