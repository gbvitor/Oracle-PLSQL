-- =============================================================================
-- Tópico : Synonyms
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE SYNONYM
-- =============================================================================

-- 1. Synonym privado para uma tabela do próprio schema.
CREATE SYNONYM tmp_syn_clientes FOR clientes;

-- Esperado: 12
SELECT COUNT(*) FROM tmp_syn_clientes;

-- 2. Synonym para um objeto de outro schema (o dicionário do SYS).
--    O acesso funciona porque DUAL tem grant para todos.
CREATE SYNONYM tmp_syn_dual FOR sys.dual;

-- Esperado: X
SELECT dummy FROM tmp_syn_dual;

-- 3. Synonym para objeto sem permissão: o synonym é criado, mas o uso falha.
--    SYS.USER$ é uma tabela interna sem grant para usuários comuns.
CREATE SYNONYM tmp_syn_sem_grant FOR sys.user$;

-- Esperado: ORA-00942 (tabela ou view não existe)
SELECT COUNT(*) FROM tmp_syn_sem_grant;

-- 4. Synonym órfão: o destino foi apagado.
CREATE TABLE tmp_destino (x NUMBER);
CREATE SYNONYM tmp_syn_destino FOR tmp_destino;
DROP TABLE tmp_destino PURGE;

-- Esperado: ORA-00980 (a conversão de sinônimos não é mais válida)
SELECT * FROM tmp_syn_destino;

-- Encontrar synonyms órfãos do schema.
-- Esperado: TMP_SYN_DESTINO (e TMP_SYN_SEM_GRANT, cujo destino não é visível)
SELECT s.synonym_name, s.table_owner, s.table_name
  FROM user_synonyms s
 WHERE NOT EXISTS (SELECT 1
                     FROM all_objects o
                    WHERE o.owner       = s.table_owner
                      AND o.object_name = s.table_name)
   AND s.db_link IS NULL
 ORDER BY s.synonym_name;

-- 5. Objeto local esconde synonym público de mesmo nome.
--    DUAL, USER_TABLES e ALL_OBJECTS, por exemplo, são synonyms públicos para
--    objetos do SYS. Uma tabela local com um desses nomes passaria a ser lida no
--    lugar do objeto do sistema, por este usuário e por todo código que roda
--    com os direitos dele. O exemplo não é executado de propósito: se o script
--    parasse no meio, a tabela falsa ficaria no schema e quebraria os demais.
-- Esperado: DUAL é synonym público de SYS.DUAL
SELECT owner, synonym_name, table_owner, table_name
  FROM all_synonyms
 WHERE owner = 'PUBLIC'
   AND synonym_name IN ('DUAL', 'USER_TABLES', 'ALL_OBJECTS')
 ORDER BY synonym_name;

-- 6. Synonyms do schema no dicionário.
SELECT synonym_name, table_owner, table_name, db_link
  FROM user_synonyms
 WHERE synonym_name LIKE 'TMP_SYN%'
 ORDER BY synonym_name;

-- Limpeza
DROP SYNONYM tmp_syn_destino;
DROP SYNONYM tmp_syn_sem_grant;
DROP SYNONYM tmp_syn_dual;
DROP SYNONYM tmp_syn_clientes;
