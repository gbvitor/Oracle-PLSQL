-- =============================================================================
-- Tópico : Criação do usuário de estudo
-- Seção  : 00-ambiente
-- Versão : 19c
-- Requer : conexão como SYSTEM (ou outro usuário com CREATE USER) no PDB
--          Exemplo: sql system/<senha>@localhost:1521/FREEPDB1
-- Não usar no FreeSQL: lá o schema já é criado para a sua conta.
-- =============================================================================

-- Usuário dono do schema de exemplo. Troque a senha se quiser.
CREATE USER estudo IDENTIFIED BY "Estudo#2026"
    DEFAULT TABLESPACE users
    TEMPORARY TABLESPACE temp
    QUOTA UNLIMITED ON users;

-- Privilégios para criar os objetos usados no repositório.
GRANT CREATE SESSION,
      CREATE TABLE,
      CREATE VIEW,
      CREATE MATERIALIZED VIEW,
      CREATE SEQUENCE,
      CREATE SYNONYM,
      CREATE PROCEDURE,
      CREATE TRIGGER,
      CREATE TYPE,
      CREATE JOB
   TO estudo;

-- Leitura do dicionário de dados e das visões V$ (seções 10, 11 e 13).
GRANT SELECT_CATALOG_ROLE TO estudo;

-- O mesmo acesso como privilégio direto. Privilégio recebido por role não vale
-- dentro de procedure/function/package armazenada (AUTHID DEFINER); este vale.
GRANT SELECT ANY DICTIONARY TO estudo;

-- [23ai+] Alternativa: a role DB_DEVELOPER_ROLE reúne os privilégios usuais
-- de desenvolvimento. Em 19c ela não existe.
-- GRANT DB_DEVELOPER_ROLE TO estudo;
