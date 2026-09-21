-- =============================================================================
-- 03 - Exames mais solicitados por faixa etária
-- Documento: seção 8.2 (Query 3), pergunta de negócio 2.3, teste T6
--
-- A view mv_ranking_exames_idade é construída em duas CTEs: a primeira liga cada
-- solicitação ao paciente e ao exame e define a faixa etária com
-- AGE(CURRENT_DATE, data_nascimento); a segunda conta as solicitações por faixa
-- e por exame, e RANK() OVER (PARTITION BY faixa_etaria ...) ordena os exames
-- dentro de cada faixa.
--
-- Por usar CURRENT_DATE, a view reflete a faixa etária na data do último
-- REFRESH MATERIALIZED VIEW. Caso a clínica prefira a idade do paciente no
-- momento do pedido, basta trocar CURRENT_DATE por es.data_solicitacao no
-- cálculo (database/setup.sql).
--
-- Resultado esperado: 18 linhas. Na posição 1 (Tabela 4 da seção 11):
--   Menor 18  ->  Hemograma (25), de 41 solicitações da faixa
--   18-59     ->  Endoscopia (28), de 107 solicitações da faixa
--   60+       ->  Eletrocardiograma (33), de 112 solicitações da faixa
-- =============================================================================

SELECT faixa_etaria, nome_exame, total_solicitacoes, ranking
FROM mv_ranking_exames_idade
ORDER BY faixa_etaria, ranking;
