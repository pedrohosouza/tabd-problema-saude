-- =============================================================================
-- 02 - Dias e horários críticos de faltas
-- Documento: seção 8.1.2 (Query 2), pergunta de negócio 2.2, testes T4 e T5
--
-- A view mv_horarios_criticos_faltas conta apenas as consultas com falta, por
-- especialidade, dia da semana e hora. RANK() OVER (PARTITION BY nome ...)
-- reinicia a classificação a cada especialidade, de modo que cada uma é
-- comparada apenas com os próprios horários; empates recebem a mesma posição.
--
-- Como a view guarda somente as faltas, ela não informa quantas consultas havia
-- em cada período. Por isso o ranking é cruzado com a tabela consultas, o que
-- traz o total de agendamentos e permite calcular a taxa de cada período.
--
-- O TRIM é necessário porque TO_CHAR(data_hora, 'Day') devolve o nome do dia em
-- inglês preenchido com espaços à direita (seção 6.3).
-- =============================================================================


-- T4 - Períodos mais críticos de cada especialidade, com agendamentos e taxa.
--
-- Esperado: 14 linhas. As três primeiras têm 2 faltas:
--   Clinica Geral  Saturday  14h   2 agendamentos   2 faltas   100.00%
--   Dermatologia   Monday     9h   3 agendamentos   2 faltas    66.67%
--   Pediatria      Saturday   7h   3 agendamentos   2 faltas    66.67%
-- As demais têm 1 falta cada (empates dentro da especialidade).
--
-- Para ver o ranking completo, e não só o topo de cada especialidade, basta
-- remover a linha "WHERE mv.rank_criticidade = 1".
SELECT mv.nome_especialidade,
       TRIM(mv.dia_semana) AS dia_semana,
       mv.hora,
       agendados.total_agendamentos,
       mv.total_faltas,
       ROUND(100.0 * mv.total_faltas / agendados.total_agendamentos, 2)
           AS taxa_faltas,
       mv.rank_criticidade
FROM mv_horarios_criticos_faltas mv
JOIN (
    SELECT e.nome AS nome_especialidade,
           TO_CHAR(c.data_hora, 'Day') AS dia_semana,
           EXTRACT(HOUR FROM c.data_hora) AS hora,
           COUNT(*) AS total_agendamentos
    FROM consultas c
    JOIN especialidades e ON e.id = c.especialidade_id
    GROUP BY e.nome, TO_CHAR(c.data_hora, 'Day'), EXTRACT(HOUR FROM c.data_hora)
) agendados
    ON agendados.nome_especialidade = mv.nome_especialidade
   AND agendados.dia_semana = mv.dia_semana
   AND agendados.hora = mv.hora
WHERE mv.rank_criticidade = 1
ORDER BY mv.total_faltas DESC, taxa_faltas DESC, mv.nome_especialidade;


-- T5 - Taxa de faltas de um período específico, direto da tabela consultas.
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
