-- =============================================================================
-- Projeto : 04 — Log e auditoria genéricos — testes de aceite
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : instalação completa (o trigger de LOG_DEMO_CONTAS já gerado)
--
-- Os eventos de log gravados pelos testes ficam na tabela (são autônomos: é o que
-- se testa). Os testes contam só os eventos da própria execução. O resto termina
-- com ROLLBACK.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    v_total   PLS_INTEGER := 0;
    v_falhas  PLS_INTEGER := 0;
    v_exec    NUMBER;
    v_qtd     NUMBER;
    v_texto   VARCHAR2(4000);
    v_texto2  VARCHAR2(4000);
    v_clob    CLOB;

    PROCEDURE conferir (p_teste IN VARCHAR2, p_ok IN BOOLEAN) IS
    BEGIN
        v_total := v_total + 1;
        IF NVL(p_ok, FALSE) THEN
            DBMS_OUTPUT.PUT_LINE('OK      ' || p_teste);
        ELSE
            v_falhas := v_falhas + 1;
            DBMS_OUTPUT.PUT_LINE('FALHOU  ' || p_teste);
        END IF;
    END conferir;

    PROCEDURE conferir_erro (
        p_teste    IN VARCHAR2,
        p_esperado IN PLS_INTEGER,
        p_sqlcode  IN PLS_INTEGER,
        p_sqlerrm  IN VARCHAR2
    ) IS
    BEGIN
        conferir(p_teste || ' (ORA-' || TO_CHAR(-p_esperado, 'FM00000') || ')'
                 || CASE WHEN p_sqlcode <> p_esperado THEN ' — veio: ' || p_sqlerrm END,
                 p_sqlcode = p_esperado);
    END conferir_erro;

    FUNCTION eventos (p_nivel IN VARCHAR2 DEFAULT NULL) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v
          FROM log_eventos
         WHERE id_execucao = v_exec
           AND (p_nivel IS NULL OR nivel = p_nivel);
        RETURN v;
    END eventos;

    FUNCTION auditorias (p_operacao IN VARCHAR2 DEFAULT NULL) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v
          FROM log_aud_alteracoes
         WHERE tabela = 'LOG_DEMO_CONTAS'
           AND chave = '900'
           AND (p_operacao IS NULL OR operacao = p_operacao);
        RETURN v;
    END auditorias;

    -- Grava um evento antigo, fora da transação do teste (o expurgo é autônomo
    -- e só enxerga o que foi confirmado).
    PROCEDURE evento_antigo IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO log_eventos (momento, nivel, id_execucao, mensagem)
        VALUES (SYSTIMESTAMP - INTERVAL '400' DAY(3), 'INFO', v_exec, 'Evento antigo para o teste de expurgo');
        COMMIT;
    END evento_antigo;
BEGIN
    log_pkg.definir_nivel('INFO');
    v_exec := log_pkg.iniciar_execucao('testes_log');

    -- T01: a execução marca a sessão (V$SESSION.MODULE vem do mesmo lugar).
    conferir('T01 execução aberta e módulo da sessão definido',
             log_pkg.execucao_atual = v_exec AND SYS_CONTEXT('USERENV', 'MODULE') = 'testes_log');

    -- T02: INFO grava; DEBUG abaixo do nível não grava.
    log_pkg.info('teste info');
    log_pkg.debug('teste debug invisível');
    conferir('T02 INFO grava, DEBUG não', eventos('INFO') = 1 AND eventos('DEBUG') = 0);

    -- T03: com o nível em DEBUG, grava.
    log_pkg.definir_nivel('DEBUG');
    log_pkg.debug('teste debug visível');
    conferir('T03 DEBUG grava depois de definir_nivel', eventos('DEBUG') = 1 AND log_pkg.nivel_atual = 'DEBUG');
    log_pkg.definir_nivel('INFO');

    -- T04: nível inválido.
    BEGIN
        log_pkg.definir_nivel('TUDO');
        conferir('T04 nível inválido recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T04 nível inválido recusado', -20401, SQLCODE, SQLERRM);
    END;

    -- T05: o log sobrevive ao ROLLBACK de quem logou.
    SAVEPOINT t05;
    INSERT INTO log_demo_contas VALUES (901, 'Conta desfeita', 1, DATE '2026-11-01', 'A');
    log_pkg.aviso('aviso antes do rollback');
    ROLLBACK TO t05;
    SELECT COUNT(*) INTO v_qtd FROM log_demo_contas WHERE id_conta = 901;
    conferir('T05 aviso ficou, a conta não', eventos('AVISO') = 1 AND v_qtd = 0);

    -- T06: erro com pilha e backtrace, chamado de dentro do handler.
    BEGIN
        v_qtd := 0;
        v_qtd := 1 / v_qtd;
    EXCEPTION
        WHEN OTHERS THEN
            log_pkg.erro;
    END;
    SELECT mensagem, detalhe INTO v_texto, v_clob
      FROM log_eventos
     WHERE id_execucao = v_exec AND nivel = 'ERRO';
    conferir('T06 erro grava a mensagem ORA-01476 e o backtrace com ORA-06512',
             v_texto LIKE 'ORA-01476%'
             AND DBMS_LOB.INSTR(v_clob, 'Backtrace:') > 0
             AND DBMS_LOB.INSTR(v_clob, 'ORA-06512') > 0);

    -- T07: finalizar fecha a execução com a situação e limpa o estado da sessão.
    log_pkg.finalizar_execucao('OK');
    SELECT situacao INTO v_texto FROM log_execucoes WHERE id_execucao = v_exec;
    SELECT COUNT(*) INTO v_qtd FROM log_execucoes WHERE id_execucao = v_exec AND fim IS NOT NULL;
    conferir('T07 execução fechada como OK', v_texto = 'OK' AND v_qtd = 1 AND log_pkg.execucao_atual IS NULL);

    -- T08: expurgo apaga só o que passou do prazo.
    evento_antigo;
    v_qtd := log_pkg.expurgar(365);
    conferir('T08 expurgo apagou o evento de 400 dias e manteve os de hoje',
             v_qtd >= 1 AND eventos() = 4);

    -- T09: o texto gerado tem uma chamada por coluna não chave (4) e a chave pelo OLD e pelo NEW.
    v_clob := log_pkg_auditoria.texto_trigger('log_demo_contas');
    v_qtd  := REGEXP_COUNT(v_clob, 'log_pkg_auditoria\.registrar');
    conferir('T09 texto do trigger com 4 colunas auditadas',
             v_qtd = 4 AND DBMS_LOB.INSTR(v_clob, ':OLD.ID_CONTA') > 0 AND DBMS_LOB.INSTR(v_clob, ':NEW.ID_CONTA') > 0);

    -- T10: nome inválido e tabela inexistente.
    BEGIN
        v_clob := log_pkg_auditoria.texto_trigger('log_demo_contas; DROP TABLE x');
        conferir('T10 nome com injeção recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T10 nome com injeção recusado', -20402, SQLCODE, SQLERRM);
    END;

    BEGIN
        v_clob := log_pkg_auditoria.texto_trigger('tabela_que_nao_existe');
        conferir('T11 tabela inexistente recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T11 tabela inexistente recusada', -20402, SQLCODE, SQLERRM);
    END;

    -- T12: INSERT audita as 4 colunas não nulas.
    INSERT INTO log_demo_contas VALUES (900, 'Conta 900', 100, DATE '2026-11-01', 'A');
    SELECT valor_novo INTO v_texto
      FROM log_aud_alteracoes
     WHERE tabela = 'LOG_DEMO_CONTAS' AND chave = '900' AND coluna = 'ABERTURA';
    conferir('T12 insert: 4 linhas, data em ISO', auditorias('I') = 4 AND v_texto = '2026-11-01 00:00:00');

    -- T13: UPDATE de uma coluna audita só ela, com ponto decimal fixo.
    UPDATE log_demo_contas SET saldo = 150.5 WHERE id_conta = 900;
    SELECT valor_antigo, valor_novo INTO v_texto, v_texto2
      FROM log_aud_alteracoes
     WHERE tabela = 'LOG_DEMO_CONTAS' AND chave = '900' AND operacao = 'U';
    conferir('T13 update do saldo: 100 -> 150.5', v_texto = '100' AND v_texto2 = '150.5');

    -- T14: UPDATE sem mudança real não audita.
    UPDATE log_demo_contas SET saldo = saldo, titular = titular WHERE id_conta = 900;
    conferir('T14 update sem mudança não grava', auditorias('U') = 1);

    -- T15: troca de valor por NULL é detectada.
    UPDATE log_demo_contas SET situacao = NULL WHERE id_conta = 900;
    SELECT COUNT(*) INTO v_qtd
      FROM log_aud_alteracoes
     WHERE tabela = 'LOG_DEMO_CONTAS' AND chave = '900' AND coluna = 'SITUACAO'
       AND operacao = 'U' AND valor_antigo = 'A' AND valor_novo IS NULL;
    conferir('T15 valor para NULL auditado', v_qtd = 1);

    -- T16: DELETE audita as colunas não nulas (situação já está nula: 3 linhas).
    DELETE FROM log_demo_contas WHERE id_conta = 900;
    conferir('T16 delete: 3 linhas', auditorias('D') = 3 AND auditorias() = 9);

    -- T17: a auditoria é da transação: desfeita a alteração, some a auditoria.
    SAVEPOINT t17;
    INSERT INTO log_demo_contas VALUES (902, 'Conta 902', 1, DATE '2026-11-01', 'A');
    ROLLBACK TO t17;
    SELECT COUNT(*) INTO v_qtd FROM log_aud_alteracoes WHERE tabela = 'LOG_DEMO_CONTAS' AND chave = '902';
    conferir('T17 auditoria desfeita junto com a alteração', v_qtd = 0);

    -- T18: gerar o trigger de novo não confirma o trabalho pendente (DDL em transação
    --      autônoma). O pendente fica em outra tabela: DML pendente na própria tabela
    --      seguraria uma trava que o CREATE TRIGGER precisa, e a geração falharia;
    --      por isso o ROLLBACK antes, que solta as travas dos testes T12 a T16.
    ROLLBACK;
    INSERT INTO log_execucoes (modulo) VALUES ('pendente_t18');
    log_pkg_auditoria.gerar_trigger('log_demo_contas');
    ROLLBACK;
    SELECT COUNT(*) INTO v_qtd FROM log_execucoes WHERE modulo = 'pendente_t18';
    conferir('T18 DDL do gerador não fez COMMIT da transação de quem chamou', v_qtd = 0);

    DBMS_OUTPUT.PUT_LINE('----');
    DBMS_OUTPUT.PUT_LINE(v_total - v_falhas || ' de ' || v_total || ' testes passaram');
END;
/

ROLLBACK;
