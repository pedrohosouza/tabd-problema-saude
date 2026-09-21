-- =============================================================================
-- 02 - Dias e horários críticos de faltas
-- Documento: seção 8.1.2 (Query 2), pergunta de negócio 2.2, testes T4 e T5
--
-- A view mv_horarios_criticos_faltas conta apenas as consultas com falta, por
-- especialidade, dia da semana e hora. RANK() OVER (PARTITION BY nome ...)
-- reinicia a classificação a cada especialidade, de modo que cada uma é
-- comparada apenas com os próprios horários; empates recebem a mesma posição.
--
-- O TRIM é necessário porque TO_CHAR(data_hora, 'Day') devolve o nome do dia em
-- inglês preenchido com espaços à direita (seção 6.3).
-- =============================================================================


-- T4 - Períodos mais críticos de cada especialidade.
-- Esperado: 14 linhas. As três primeiras têm 2 faltas - Clinica Geral
-- (Saturday, 14h), Dermatologia (Monday, 9h) e Pediatria (Saturday, 7h). As
-- demais têm 1 falta cada (empates dentro da especialidade).
SELECT nome_especialidade,
       TRIM(dia_semana) AS dia_semana,
       hora,
       total_faltas,
       rank_criticidade
FROM mv_horarios_criticos_faltas
WHERE rank_criticidade = 1
ORDER BY total_faltas DESC, nome_especialidade;


-- T5 - Taxa de faltas de um período específico.
-- A view guarda somente as faltas e por isso não informa quantas consultas havia
-- no período; para obter a taxa, o resultado é combinado com a tabela consultas.
-- Exemplo do documento: Dermatologia, segundas-feiras, 9h.
-- Esperado: 3 consultas, 2 faltas e taxa de 66.67%.
SELECT COUNT(*) AS total_consultas,
       COUNT(*) FILTER (WHERE NOT c.compareceu) AS faltas,
       ROUND(100.0 * COUNT(*) FILTER (WHERE NOT c.compareceu)
             / COUNT(*), 2) AS taxa_faltas
FROM consultas c
JOIN especialidades e ON e.id = c.especialidade_id
WHERE e.nome = 'Dermatologia'
  AND EXTRACT(ISODOW FROM c.data_hora) = 1
  AND EXTRACT(HOUR FROM c.data_hora) = 9;
