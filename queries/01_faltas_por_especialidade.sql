-- =============================================================================
-- 01 - Faltas e taxa de não comparecimento por especialidade
-- Documento: seção 8.1.1 (Query 1), pergunta de negócio 2.1, teste T3
--
-- A view mv_padroes_faltas consolida, por especialidade e dia da semana, o total
-- de agendamentos e o total de faltas. A taxa não é armazenada na view: ela é
-- calculada aqui, dividindo total_faltas por total_agendamentos.
--
-- Resultado esperado (Tabela 2 da seção 11):
--   Dermatologia    53  9  16.98
--   Pediatria       58  9  15.52
--   Clinica Geral   51  7  13.73
--   Ortopedia       64  6   9.38
--   Ginecologia     43  4   9.30
--   Cardiologia     51  1   1.96
--   Total          320 36  11.25
--
-- Observação: os CSVs gravam "Clinica Geral" sem acento; o documento acentua o
-- nome nas tabelas de resultado.
-- =============================================================================

SELECT
    nome_especialidade,
    SUM(total_agendamentos) AS total_agendamentos,
    SUM(total_faltas) AS total_faltas,
    ROUND(100.0 * SUM(total_faltas) / SUM(total_agendamentos), 2)
        AS taxa_faltas
FROM mv_padroes_faltas
GROUP BY nome_especialidade
ORDER BY total_faltas DESC, taxa_faltas DESC;
