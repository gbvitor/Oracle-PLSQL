-- =============================================================================
-- Projeto : 05 — API em PL/SQL com utPLSQL — carga de exemplo
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql, 02-pacote.sql
--
-- Tudo pela API, com máscaras e espaços de propósito: a package normaliza.
-- Documentos com dígito verificador válido, mas fictícios.
-- =============================================================================

DECLARE
    v_id api_pkg_clientes.t_id;
BEGIN
    v_id := api_pkg_clientes.criar('Mercado Ponto Certo Ltda', '11.222.333/0001-81', 'sp',
                                   ' Compras@PontoCerto.example ', 20000);
    v_id := api_pkg_clientes.criar('Pessoa  Física   01', '529.982.247-25', 'TO', NULL, 3000);
    v_id := api_pkg_clientes.criar('Distribuidora Norte Ltda', '12.ABC.345/01DE-35', 'PA',
                                   'contato@norte.example', 50000);
    v_id := api_pkg_clientes.criar('Pessoa Física 02', '123.456.789-09', 'SP', 'pf02@email.example', 1500);
    v_id := api_pkg_clientes.criar('Atacado Sul ME', '45.371.296/0001-95', 'RS', NULL, 10000);
END;
/

COMMIT;

-- Esperado (ordem por nome):
--   Atacado Sul ME            J 45371296000195 RS
--   Distribuidora Norte Ltda  J 12ABC34501DE35 PA
--   Mercado Ponto Certo Ltda  J 11222333000181 SP compras@pontocerto.example
--   Pessoa Física 01          F 52998224725    TO   (espaços repetidos removidos)
--   Pessoa Física 02          F 12345678909    SP
SELECT nome, tipo_pessoa, documento, uf, email, limite_credito, versao
  FROM api_clientes
 ORDER BY nome;
