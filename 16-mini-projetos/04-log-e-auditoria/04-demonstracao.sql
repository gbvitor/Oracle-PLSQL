-- =============================================================================
-- Projeto : 04 — Log e auditoria genéricos — demonstração
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01 a 03
--
-- Cria a tabela de demonstração, gera o trigger de auditoria dela e roda um
-- processo de exemplo que usa o log do começo ao fim.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE TABLE log_demo_contas (
    id_conta  NUMBER(6)     CONSTRAINT pk_log_demo_contas PRIMARY KEY,
    titular   VARCHAR2(60)  NOT NULL,
    saldo     NUMBER(12,2)  NOT NULL,
    abertura  DATE          NOT NULL,
    situacao  CHAR(1)
);

-- O texto que será gerado, para revisar.
SET LONG 100000
SET PAGESIZE 0
SELECT log_pkg_auditoria.texto_trigger('log_demo_contas') FROM dual;
SET PAGESIZE 100

EXEC log_pkg_auditoria.gerar_trigger('log_demo_contas')

-- Esperado: LOG_AUD_LOG_DEMO_CONTAS ENABLED VALID
SELECT t.trigger_name, t.status, o.status AS compilacao
  FROM user_triggers t
  JOIN user_objects o ON o.object_name = t.trigger_name AND o.object_type = 'TRIGGER'
 WHERE t.table_name = 'LOG_DEMO_CONTAS';

-- Um processo de exemplo: abre a execução, loga os passos, trata o erro de uma
-- linha sem parar o resto, fecha a execução com a situação final.
DECLARE
    v_exec  NUMBER;
    v_erros PLS_INTEGER := 0;
BEGIN
    v_exec := log_pkg.iniciar_execucao('demo_abertura_contas');
    log_pkg.info('Início da abertura de contas');

    FOR i IN 1 .. 3 LOOP
        BEGIN
            log_pkg.debug('Conta ' || i);
            -- A conta 2 falha de propósito: divisão por zero no saldo inicial.
            INSERT INTO log_demo_contas (id_conta, titular, saldo, abertura, situacao)
            VALUES (i, 'Conta ' || TO_CHAR(i, 'FM00'),
                    100 * i / CASE WHEN i = 2 THEN 0 ELSE 1 END,
                    DATE '2026-11-01', 'A');
        EXCEPTION
            WHEN OTHERS THEN
                v_erros := v_erros + 1;
                log_pkg.erro('Conta ' || i || ' não aberta');
        END;
    END LOOP;

    COMMIT;
    log_pkg.info('Fim: ' || (3 - v_erros) || ' conta(s) aberta(s), ' || v_erros || ' erro(s)');
    log_pkg.finalizar_execucao(CASE WHEN v_erros > 0 THEN 'ERRO' ELSE 'OK' END);
END;
/

-- Esperado: INFO Início... | ERRO Conta 2 não aberta | INFO Fim: 2 conta(s) aberta(s), 1 erro(s)
--           (DEBUG não aparece: o nível padrão é INFO)
SELECT e.nivel, e.mensagem
  FROM log_eventos e
 WHERE e.id_execucao = (SELECT MAX(id_execucao) FROM log_execucoes WHERE modulo = 'demo_abertura_contas')
 ORDER BY e.id_evento;

-- O detalhe do erro: pilha (ORA-01476), backtrace com a linha e pilha de chamadas.
SET LONG 4000
SELECT e.detalhe
  FROM log_eventos e
 WHERE e.nivel = 'ERRO'
   AND e.id_execucao = (SELECT MAX(id_execucao) FROM log_execucoes WHERE modulo = 'demo_abertura_contas');

-- Esperado: ERRO, com início, fim e duração
SELECT id_execucao, modulo, situacao, fim - inicio AS duracao
  FROM log_execucoes
 WHERE modulo = 'demo_abertura_contas'
 ORDER BY id_execucao DESC
 FETCH FIRST 1 ROW ONLY;

-- A auditoria das duas contas inseridas: 4 colunas cada (a chave vai em CHAVE).
-- Esperado: 8 linhas, operação I, valor antigo nulo
SELECT chave, operacao, coluna, valor_antigo, valor_novo
  FROM log_aud_alteracoes
 WHERE tabela = 'LOG_DEMO_CONTAS'
 ORDER BY id_alteracao;

-- Limpeza da demonstração (o trigger e a tabela ficam para os testes).
DELETE FROM log_demo_contas;
DELETE FROM log_aud_alteracoes WHERE tabela = 'LOG_DEMO_CONTAS';
COMMIT;
