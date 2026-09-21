-- =============================================================================
-- 00 - KDD: seleção, limpeza, verificação e derivação
-- Documento: seção 6 (PROCESSO DE KDD E PRÉ PROCESSAMENTO)
--
-- Todas as consultas deste arquivo são de VERIFICAÇÃO: nenhuma altera dados.
-- A massa fornecida pelo docente é preservada como está, inclusive as
-- duplicidades identificadas na seção 6.2.
--
-- A única limpeza executada por código é a conversão "Sim"/"Nao" -> TRUE/FALSE
-- e o bloco de validação que aborta a carga, ambos em scripts/seed.sql.
--
-- Resultados esperados medidos em 20/09/2026 sobre os CSVs de data/.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 6.1 Seleção e limpeza
-- -----------------------------------------------------------------------------

-- Volume carregado por tabela.
-- Esperado: especialidades 6, pacientes 70, exames 6, consultas 320,
--           exames_solicitados 260.
SELECT 'especialidades' AS tabela, COUNT(*) AS registros FROM especialidades
UNION ALL SELECT 'pacientes', COUNT(*) FROM pacientes
UNION ALL SELECT 'exames', COUNT(*) FROM exames
UNION ALL SELECT 'consultas', COUNT(*) FROM consultas
UNION ALL SELECT 'exames_solicitados', COUNT(*) FROM exames_solicitados
ORDER BY tabela;

-- Varredura de valores nulos coluna a coluna.
-- As colunas são NOT NULL no DDL; a consulta serve como evidência explícita da
-- afirmação da seção 6 ("não há valores nulos").
-- Esperado: todas as contagens em 0.
SELECT 'pacientes' AS tabela,
       COUNT(*) FILTER (WHERE nome IS NULL) AS nulos_nome,
       COUNT(*) FILTER (WHERE data_nascimento IS NULL) AS nulos_data_nascimento,
       COUNT(*) FILTER (WHERE sexo IS NULL) AS nulos_sexo
FROM pacientes;

SELECT 'consultas' AS tabela,
       COUNT(*) FILTER (WHERE paciente_id IS NULL) AS nulos_paciente_id,
       COUNT(*) FILTER (WHERE especialidade_id IS NULL) AS nulos_especialidade_id,
       COUNT(*) FILTER (WHERE data_hora IS NULL) AS nulos_data_hora,
       COUNT(*) FILTER (WHERE compareceu IS NULL) AS nulos_compareceu
FROM consultas;

SELECT 'exames_solicitados' AS tabela,
       COUNT(*) FILTER (WHERE paciente_id IS NULL) AS nulos_paciente_id,
       COUNT(*) FILTER (WHERE exame_id IS NULL) AS nulos_exame_id,
       COUNT(*) FILTER (WHERE data_solicitacao IS NULL) AS nulos_data_solicitacao
FROM exames_solicitados;

-- Chaves estrangeiras sem correspondência.
-- Garantido pelas constraints do setup.sql; documentado aqui como verificação.
-- Esperado: todas as contagens em 0.
SELECT
    COUNT(*) FILTER (WHERE p.id IS NULL) AS consultas_sem_paciente,
    COUNT(*) FILTER (WHERE e.id IS NULL) AS consultas_sem_especialidade
FROM consultas c
LEFT JOIN pacientes p ON p.id = c.paciente_id
LEFT JOIN especialidades e ON e.id = c.especialidade_id;

SELECT
    COUNT(*) FILTER (WHERE p.id IS NULL) AS solicitacoes_sem_paciente,
    COUNT(*) FILTER (WHERE ex.id IS NULL) AS solicitacoes_sem_exame
FROM exames_solicitados es
LEFT JOIN pacientes p ON p.id = es.paciente_id
LEFT JOIN exames ex ON ex.id = es.exame_id;

-- Domínio da coluna compareceu, já normalizada na carga.
-- Nos CSVs a coluna vem como "Sim"/"Nao"; scripts/seed.sql converte para
-- TRUE/FALSE e aborta a carga se encontrar qualquer outro valor.
-- Esperado: TRUE = 284 e FALSE = 36, sem nulos.
SELECT compareceu, COUNT(*) AS total
FROM consultas
GROUP BY compareceu
ORDER BY compareceu;

-- Consultas agendadas depois da data de execução da análise.
-- Sustenta a afirmação de que não há consultas passadas sem status a serem
-- marcadas como pendentes de auditoria.
-- Esperado: 0.
SELECT COUNT(*) AS consultas_futuras
FROM consultas
WHERE data_hora > CURRENT_DATE;

-- Janela de datas da massa.
-- Esperado: consultas de 2026-03-02 a 2026-05-31 e solicitações de exame na
-- mesma janela.
SELECT 'consultas' AS tabela,
       MIN(data_hora)::date AS data_inicial,
       MAX(data_hora)::date AS data_final
FROM consultas
UNION ALL
SELECT 'exames_solicitados',
       MIN(data_solicitacao),
       MAX(data_solicitacao)
FROM exames_solicitados;


-- -----------------------------------------------------------------------------
-- 6.2 Verificação de duplicidades
--
-- Os dois pares abaixo foram MANTIDOS: a carga preserva a massa fornecida pelo
-- docente. Nenhuma das duas duplicidades é uma falta e nenhuma altera o período
-- nem o exame que lidera os rankings das seções 8 e 11.
-- -----------------------------------------------------------------------------

-- Consultas idênticas (mesmo paciente, especialidade, data/hora e comparecimento).
-- Esperado: 1 linha, ids {49,240} - paciente 56, Pediatria, 14/04/2026 16h,
--           com comparecimento.
SELECT
    c.paciente_id,
    e.nome AS nome_especialidade,
    c.data_hora,
    c.compareceu,
    COUNT(*) AS ocorrencias,
    ARRAY_AGG(c.id ORDER BY c.id) AS ids
FROM consultas c
JOIN especialidades e ON e.id = c.especialidade_id
GROUP BY c.paciente_id, e.nome, c.especialidade_id, c.data_hora, c.compareceu
HAVING COUNT(*) > 1
ORDER BY c.paciente_id;

-- Solicitações de exame idênticas (mesmo paciente, exame e data).
-- Esperado: 1 linha, ids {12,164} - paciente 47, Hemograma, 13/05/2026.
SELECT
    es.paciente_id,
    ex.nome AS nome_exame,
    es.data_solicitacao,
    COUNT(*) AS ocorrencias,
    ARRAY_AGG(es.id ORDER BY es.id) AS ids
FROM exames_solicitados es
JOIN exames ex ON ex.id = es.exame_id
GROUP BY es.paciente_id, ex.nome, es.exame_id, es.data_solicitacao
HAVING COUNT(*) > 1
ORDER BY es.paciente_id;


-- -----------------------------------------------------------------------------
-- 6.3 Transformação (derivação)
-- -----------------------------------------------------------------------------

-- Derivação de dia da semana e hora a partir de data_hora.
-- TO_CHAR(..., 'Day') devolve o nome em inglês preenchido com espaços à direita
-- (ex.: "Monday   "), por isso as consultas da seção 8.1.2 aplicam TRIM.
SELECT
    c.data_hora,
    TO_CHAR(c.data_hora, 'Day') AS dia_semana_bruto,
    TRIM(TO_CHAR(c.data_hora, 'Day')) AS dia_semana,
    EXTRACT(HOUR FROM c.data_hora) AS hora,
    EXTRACT(ISODOW FROM c.data_hora) AS dia_semana_iso
FROM consultas c
ORDER BY c.id
LIMIT 10;

-- Derivação de idade e faixa etária a partir de data_nascimento.
-- Mesma regra usada em mv_ranking_exames_idade.
SELECT
    p.id,
    p.data_nascimento,
    AGE(CURRENT_DATE, p.data_nascimento) AS idade,
    CASE
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.data_nascimento)) < 18
            THEN 'Menor 18'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.data_nascimento)) BETWEEN 18 AND 59
            THEN '18-59'
        ELSE '60+'
    END AS faixa_etaria
FROM pacientes p
ORDER BY p.id
LIMIT 10;

-- Distribuição dos pacientes por faixa etária.
-- O cálculo usa CURRENT_DATE, portanto a distribuição muda se a análise for
-- refeita em outra data.
-- Esperado em 20/09/2026: Menor 18 = 14, 18-59 = 27, 60+ = 29.
SELECT
    CASE
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.data_nascimento)) < 18
            THEN 'Menor 18'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.data_nascimento)) BETWEEN 18 AND 59
            THEN '18-59'
        ELSE '60+'
    END AS faixa_etaria,
    COUNT(*) AS total_pacientes
FROM pacientes p
GROUP BY 1
ORDER BY 1;


-- -----------------------------------------------------------------------------
-- 6.4 Observações sobre a massa (incoerências não tratadas)
--
-- Os dados são sintéticos e apresentam incoerências clínicas conhecidas. Elas
-- ficaram fora do escopo por não afetarem as perguntas de agenda e de
-- solicitação de exames; as consultas abaixo apenas as quantificam.
-- -----------------------------------------------------------------------------

-- Consultas de Pediatria com paciente de 18 anos ou mais NA DATA DA CONSULTA.
-- A idade é calculada sobre c.data_hora, e não sobre CURRENT_DATE.
-- Esperado: 48 de 58.
SELECT
    COUNT(*) AS consultas_pediatria,
    COUNT(*) FILTER (
        WHERE EXTRACT(YEAR FROM AGE(c.data_hora, p.data_nascimento)) >= 18
    ) AS com_paciente_adulto
FROM consultas c
JOIN especialidades e ON e.id = c.especialidade_id
JOIN pacientes p ON p.id = c.paciente_id
WHERE e.nome = 'Pediatria';

-- Consultas de Ginecologia com paciente do sexo M.
-- Esperado: 28 de 43.
SELECT
    COUNT(*) AS consultas_ginecologia,
    COUNT(*) FILTER (WHERE p.sexo = 'M') AS com_paciente_masculino
FROM consultas c
JOIN especialidades e ON e.id = c.especialidade_id
JOIN pacientes p ON p.id = c.paciente_id
WHERE e.nome = 'Ginecologia';

-- Solicitações de Mamografia para paciente do sexo M.
-- Esperado: 22 de 40.
SELECT
    COUNT(*) AS solicitacoes_mamografia,
    COUNT(*) FILTER (WHERE p.sexo = 'M') AS com_paciente_masculino
FROM exames_solicitados es
JOIN exames ex ON ex.id = es.exame_id
JOIN pacientes p ON p.id = es.paciente_id
WHERE ex.nome = 'Mamografia';
