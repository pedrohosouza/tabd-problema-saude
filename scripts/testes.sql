-- =============================================================================
-- Roteiro de testes
-- Documento: seção 10 (ROTEIRO DE TESTES)
--
-- Reproduz os resultados apresentados no trabalho. Os valores esperados foram
-- obtidos executando database/setup.sql e scripts/seed.sql sobre os CSVs de
-- data/, com as consultas rodadas em 20/09/2026. A data só influencia a faixa
-- etária (T6), conforme a seção 6.
--
-- Execução:
--   make db-test
-- ou, no DBeaver/psql conectado ao banco tabd_saude:
--   psql -U tabd_saude -d tabd_saude -f scripts/testes.sql
--
-- T1 - Subir o ambiente e carregar os dados (executado fora deste arquivo):
--   make db-seed
--   make db-status
-- Esperado: os contêineres sobem, a carga termina com COMMIT e o db-status
-- mostra 6 especialidades, 70 pacientes, 6 exames, 320 consultas e 260 exames
-- solicitados.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- T2 - Conferir a padronização do comparecimento
-- Esperado: TRUE = 284 e FALSE = 36, sem valores nulos
--           (taxa geral de faltas: 36 / 320 = 11,25%).
-- -----------------------------------------------------------------------------
SELECT compareceu, COUNT(*) FROM consultas GROUP BY compareceu;


-- -----------------------------------------------------------------------------
-- T3 - Faltas e taxa por especialidade (pergunta 2.1)
-- Consulta da seção 8.1.1, também em queries/01_faltas_por_especialidade.sql.
-- Esperado: os valores da Tabela 2 (seção 11) - Dermatologia 53/9/16.98,
-- Pediatria 58/9/15.52, Clinica Geral 51/7/13.73, Ortopedia 64/6/9.38,
-- Ginecologia 43/4/9.30 e Cardiologia 51/1/1.96.
-- -----------------------------------------------------------------------------
SELECT
    nome_especialidade,
    SUM(total_agendamentos) AS total_agendamentos,
    SUM(total_faltas) AS total_faltas,
    ROUND(100.0 * SUM(total_faltas) / SUM(total_agendamentos), 2)
        AS taxa_faltas
FROM mv_padroes_faltas
GROUP BY nome_especialidade
ORDER BY total_faltas DESC, taxa_faltas DESC;


-- -----------------------------------------------------------------------------
-- T4 - Períodos críticos por especialidade (pergunta 2.2)
-- Consulta da seção 8.1.2, também em queries/02_horarios_criticos.sql.
-- Esperado: 14 linhas. As três primeiras têm 2 faltas - Clinica Geral
-- (Saturday, 14h), Dermatologia (Monday, 9h) e Pediatria (Saturday, 7h).
-- As demais têm 1 falta cada (empates dentro da especialidade).
-- -----------------------------------------------------------------------------
SELECT nome_especialidade,
       TRIM(dia_semana) AS dia_semana,
       hora,
       total_faltas,
       rank_criticidade
FROM mv_horarios_criticos_faltas
WHERE rank_criticidade = 1
ORDER BY total_faltas DESC, nome_especialidade;


-- -----------------------------------------------------------------------------
-- T5 - Taxa de faltas de um período (Dermatologia, segundas-feiras, 9h)
-- Também em queries/02_horarios_criticos.sql.
-- Esperado: 3 consultas, 2 faltas e taxa de 66,67%.
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS total_consultas,
       COUNT(*) FILTER (WHERE NOT c.compareceu) AS faltas,
       ROUND(100.0 * COUNT(*) FILTER (WHERE NOT c.compareceu)
             / COUNT(*), 2) AS taxa_faltas
FROM consultas c
JOIN especialidades e ON e.id = c.especialidade_id
WHERE e.nome = 'Dermatologia'
  AND EXTRACT(ISODOW FROM c.data_hora) = 1
  AND EXTRACT(HOUR FROM c.data_hora) = 9;


-- -----------------------------------------------------------------------------
-- T6 - Exames por faixa etária (pergunta 2.3)
-- Consulta da seção 8.2, também em queries/03_exames_por_faixa_etaria.sql.
-- Esperado: 18 linhas; na posição 1 aparecem Endoscopia (28) em "18-59",
-- Eletrocardiograma (33) em "60+" e Hemograma (25) em "Menor 18", conforme a
-- Tabela 4 (seção 11). Como a faixa etária usa CURRENT_DATE, a distribuição
-- pode variar se o teste for feito em outra data.
-- -----------------------------------------------------------------------------
SELECT faixa_etaria, nome_exame, total_solicitacoes, ranking
FROM mv_ranking_exames_idade
ORDER BY faixa_etaria, ranking;


-- -----------------------------------------------------------------------------
-- T7 - Trigger de auditoria de faltas
-- Esperado: a consulta 1 (paciente 67) está com compareceu = TRUE. Após o
-- primeiro UPDATE, o log tem uma linha (consulta_id 1, paciente_id 67,
-- data_registro preenchida). Repetir o UPDATE não cria nova linha, porque o
-- valor antigo já era FALSE (cláusula WHEN do gatilho). O ROLLBACK desfaz o
-- teste e deixa o log vazio, como após a carga.
-- -----------------------------------------------------------------------------
BEGIN;

UPDATE consultas SET compareceu = FALSE WHERE id = 1;

SELECT consulta_id, paciente_id, data_registro FROM log_auditoria_faltas;

UPDATE consultas SET compareceu = FALSE WHERE id = 1;

SELECT COUNT(*) FROM log_auditoria_faltas;

ROLLBACK;

-- Confirmação pós-ROLLBACK: o log volta a ficar vazio.
-- Esperado: 0.
SELECT COUNT(*) AS registros_no_log FROM log_auditoria_faltas;
