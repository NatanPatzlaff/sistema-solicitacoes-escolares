-- Teste do schema.sql num Postgres local (NÃO rodar no Supabase).
-- Simula o que o Supabase fornece (auth.users, auth.uid(), papéis anon/authenticated)
-- e verifica isolamento por unidade, permissões, ciclo de status e ações em lote.
-- Uso: sh supabase/testar-local.sh

\set QUIET on
create role anon nologin;
create role authenticated nologin;
create schema auth;
create schema extensions;
create table auth.users (id uuid primary key, email text unique);
create function auth.uid() returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema public, auth, extensions to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;
alter default privileges in schema public grant execute on functions to anon, authenticated;

\ir schema.sql
\ir migracoes/001-catalogo.sql

insert into produtos (nome, categoria) values
  ('  Papel   sulfite A4 (resma) ', 'material_expediente'),
  ('Detergente (caixa com 24)', 'limpeza_higiene'),
  ('Produto antigo', 'tecnologia');
update produtos set ativo = false where nome = 'Produto antigo';

insert into auth.users values
  ('00000000-0000-0000-0000-00000000000a', 'gestor.a@teste'),
  ('00000000-0000-0000-0000-00000000000b', 'gestor.b@teste'),
  ('00000000-0000-0000-0000-00000000000c', 'secretaria@teste'),
  ('00000000-0000-0000-0000-00000000000d', 'semperfil@teste');
select vincular_usuario('gestor.a@teste', 'Gestora A', 'gestor', 'Escola A');
select vincular_usuario('gestor.b@teste', 'Gestor B', 'gestor', 'Escola B');
select vincular_usuario('secretaria@teste', 'Secretaria', 'secretaria', null);

\echo '--- gestor A'
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$
declare
  sid bigint;
  r itens;
begin
  sid := criar_solicitacao('  Pedido de setembro ', '[
    {"categoria": "limpeza_higiene", "item": "  Pá de LIXO ", "quantidade": 3},
    {"categoria": "tecnologia", "item": "Projetor", "quantidade": 1, "observacoes": "Sala 2"},
    {"categoria": "material_expediente", "item": "Papel A4 (resma)", "quantidade": 10}
  ]');
  assert (select observacoes from solicitacoes where id = sid) = 'Pedido de setembro', 'observações aparadas';
  assert (select count(*) from itens where solicitacao_id = sid) = 3, 'três itens criados';
  select * into r from itens where item = 'Pá de LIXO';
  assert r.unidade_id = (select id from unidades where nome = 'Escola A'), 'unidade herdada do gestor';
  assert r.status = 'cadastrada' and r.item_busca = 'pa de lixo', 'status inicial e busca normalizada';
  assert (select count(*) from historico) = 3, 'histórico de cadastro de cada item';
  assert (select count(*) from unidades) = 1, 'gestor vê só a própria unidade';

  begin
    perform criar_solicitacao(null, '[]');
    assert false, 'solicitação sem itens deveria falhar';
  exception when raise_exception then null;
  end;
  begin
    perform criar_solicitacao(null, '[{"categoria": "tecnologia", "item": "OK", "quantidade": 1},
                                       {"categoria": "tecnologia", "item": "X", "quantidade": 0}]');
    assert false, 'quantidade 0 deveria falhar';
  exception when check_violation then null;
  end;
  assert (select count(*) from solicitacoes) = 1, 'falha não deixa solicitação pela metade';

  -- tenta criar solicitação direto para a escola B: o banco força a escola A
  insert into solicitacoes (unidade_id) values ((select 2)) returning id into sid;
  assert (select unidade_id from solicitacoes where id = sid) = (select id from unidades where nome = 'Escola A'),
    'unidade da solicitação forçada';
end $$;

\echo '--- gestor B'
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
do $$
declare
  n int;
  sid bigint;
begin
  sid := criar_solicitacao(null, '[{"categoria": "material_expediente", "item": "Grampeador", "quantidade": 2}]');
  assert (select count(*) from solicitacoes) = 1, 'B vê só a própria solicitação';
  assert (select count(*) from itens) = 1, 'B vê só os próprios itens';
  assert (select count(*) from historico) = 1, 'B vê só o próprio histórico';
  assert (select sum(total) from contagem_por_status()) = 1, 'contagem respeita a unidade';
  assert (select count(*) from buscar_solicitacoes()) = 1, 'busca respeita a unidade';

  -- tenta pendurar item numa solicitação da escola A (id 1)
  begin
    insert into itens (solicitacao_id, categoria, item, quantidade) values (1, 'tecnologia', 'Intruso', 1);
    assert false, 'item em solicitação de outra escola';
  exception when raise_exception or insufficient_privilege or foreign_key_violation then null;
  end;

  update itens set status = 'em_analise';
  get diagnostics n = row_count;
  assert n = 0, 'gestor não altera status';
  begin
    perform atualizar_itens(array[(select id from itens limit 1)], 'em_analise');
    assert false, 'gestor não usa ação em lote';
  exception when raise_exception then null;
  end;

  select count(*) into n from perfis;
  assert n = 1, 'gestor vê só o próprio perfil';
  update perfis set papel = 'secretaria', unidade_id = null;
  get diagnostics n = row_count;
  assert n = 0, 'gestor não se promove';
  begin
    insert into perfis (id, nome, email, papel)
    values ('00000000-0000-0000-0000-00000000000d', 'X', 'x@x', 'secretaria');
    assert false, 'gestor não cria perfis';
  exception when insufficient_privilege then null;
  end;
end $$;

\echo '--- catálogo'
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$
declare
  papel bigint := (select id from produtos where nome = 'Papel sulfite A4 (resma)');
  sid bigint;
  r itens;
begin
  assert papel is not null, 'nome do produto aparado e com espaços normalizados';
  assert (select count(*) from produtos) = 3, 'gestor vê o catálogo';
  -- item do catálogo: nome e categoria vêm do produto, não do que o formulário mandou
  sid := criar_solicitacao(null, jsonb_build_array(
    jsonb_build_object('produto_id', papel, 'quantidade', 20, 'item', 'outro nome', 'categoria', 'tecnologia'),
    jsonb_build_object('categoria', 'tecnologia', 'item', 'Cabo HDMI', 'quantidade', 2)));
  select * into r from itens where solicitacao_id = sid and produto_id = papel;
  assert r.item = 'Papel sulfite A4 (resma)' and r.categoria = 'material_expediente', 'item do catálogo';
  assert (select produto_id from itens where solicitacao_id = sid and item = 'Cabo HDMI') is null, 'outro item';
  sid := criar_solicitacao(null, jsonb_build_array(jsonb_build_object('produto_id', papel, 'quantidade', 35)));
  assert (select quantidade from ultimas_quantidades() where produto_id = papel) = 35, 'última quantidade da escola';
  begin
    perform criar_solicitacao(null, jsonb_build_array(jsonb_build_object(
      'produto_id', (select id from produtos where nome = 'Produto antigo'), 'quantidade', 1)));
    assert false, 'produto desativado não pode ser pedido';
  exception when raise_exception then null;
  end;
  begin
    insert into produtos (nome, categoria) values ('Pirata', 'tecnologia');
    assert false, 'gestor não cadastra produto';
  exception when insufficient_privilege then null;
  end;
  update produtos set nome = 'hackeado';
  assert not exists (select 1 from produtos where nome = 'hackeado'), 'gestor não edita produto';
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
do $$
begin
  assert not exists (select 1 from ultimas_quantidades()), 'B não vê quantidades da escola A';
end $$;

\echo '--- Secretaria: item a item'
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
do $$
declare id_pa bigint := (select id from itens where item = 'Pá de LIXO');
begin
  assert (select count(*) from itens) = 7, 'Secretaria vê todos os itens';
  assert (select count(*) from buscar_solicitacoes()) = 5, 'Secretaria vê todas as solicitações';
  -- catálogo: Secretaria cadastra, renomeia e desativa; nome repetido (sem acento/maiúsculas) é barrado
  insert into produtos (nome, categoria) values ('Grampeador de mesa', 'material_expediente');
  begin
    insert into produtos (nome, categoria) values ('GRAMPEADOR DE MESA', 'material_expediente');
    assert false, 'produto repetido';
  exception when unique_violation then null;
  end;
  update produtos set nome = 'Grampeador de mesa grande', ativo = false where nome = 'Grampeador de mesa';
  assert (select not ativo from produtos where nome = 'Grampeador de mesa grande'), 'Secretaria edita produto';
  -- produto do item não muda depois do pedido
  update itens set produto_id = null where produto_id is not null;
  assert (select count(*) from itens where produto_id is not null) = 2, 'produto do item travado';
  assert (select count(*) from perfis where email like '%@teste') = 3, 'Secretaria lista as contas';
  begin
    perform criar_solicitacao(null, '[{"categoria": "tecnologia", "item": "X", "quantidade": 1}]');
    assert false, 'Secretaria não cadastra';
  exception when raise_exception then null;
  end;
  begin
    update itens set status = 'adquirida', quantidade_adquirida = 3 where id = id_pa;
    assert false, 'não pode pular etapa';
  exception when raise_exception then null;
  end;
  update itens set status = 'em_analise', item = 'alterado', quantidade = 99 where id = id_pa;
  assert (select item || quantidade from itens where id = id_pa) = 'Pá de LIXO3', 'pedido do gestor não muda';
  begin
    update itens set status = 'nao_atendida' where id = id_pa;
    assert false, 'não atendida exige justificativa';
  exception when raise_exception then null;
  end;
  begin
    update itens set status = 'adquirida' where id = id_pa;
    assert false, 'adquirida exige quantidade';
  exception when raise_exception then null;
  end;
  begin
    update itens set status = 'adquirida', quantidade_adquirida = 1 where id = id_pa;
    assert false, 'quantidade diferente da pedida exige justificativa';
  exception when raise_exception then null;
  end;
  update itens set status = 'adquirida', quantidade_adquirida = 1,
    justificativa = 'Falta de verba.', previsao_entrega = '2026-10-10' where id = id_pa;
  begin
    update itens set status = 'entregue' where id = id_pa;
    assert false, 'Secretaria não confirma entrega';
  exception when raise_exception then null;
  end;
  assert (select count(*) from historico where item_id = id_pa) = 3, 'histórico com 3 status';
  assert (select alterado_por_nome from historico where item_id = id_pa order by id desc limit 1) = 'Secretaria', 'nome no histórico';
  assert (select count(*) from novidades) = 0, 'Secretaria não vê avisos';
end $$;

\echo '--- Secretaria: pedido inteiro / em lote'
do $$
declare
  sid bigint := (select solicitacao_id from itens where item = 'Projetor');
  ids bigint[] := array(select id from itens where solicitacao_id = sid and status = 'cadastrada' order by id);
  papel_a4 bigint := (select id from itens where item = 'Papel A4 (resma)');
begin
  assert array_length(ids, 1) = 2, 'dois itens ainda cadastrados';
  assert atualizar_itens(ids, 'em_analise') = 2, 'lote: em análise';
  -- lote com item que não pode mudar (Grampeador ainda está "cadastrada"): nada é salvo
  begin
    perform atualizar_itens(ids || (select id from itens where item = 'Grampeador'), 'adquirida');
    assert false, 'lote com item inválido deveria falhar';
  exception when raise_exception then
    assert sqlerrm like 'Item "Grampeador"%', 'erro diz qual item impediu: ' || sqlerrm;
  end;
  assert (select count(*) from itens where id = any(ids) and status = 'em_analise') = 2, 'tudo ou nada';
  -- adquirida sem quantidade: cada item recebe o que foi pedido, sem exigir justificativa
  perform atualizar_itens(ids, 'adquirida');
  assert (select quantidade_adquirida from itens where id = papel_a4) = 10, 'quantidade pedida como padrão';
  -- ajuste de um item só, com justificativa
  begin
    perform atualizar_itens(array[papel_a4], null, 6);
    assert false, 'reduzir quantidade exige justificativa';
  exception when raise_exception then null;
  end;
  perform atualizar_itens(array[papel_a4], null, 6, 'Verba só para 6 resmas.');
  assert (select quantidade_adquirida || justificativa from itens where id = papel_a4) = '6Verba só para 6 resmas.', 'ajuste item a item';
  -- negar o pedido inteiro com uma justificativa comum
  perform atualizar_itens(array(select id from itens where item = 'Grampeador'), 'em_analise');
  perform atualizar_itens(array(select id from itens where item = 'Grampeador'), 'nao_atendida', null, 'Sem verba.');
  assert (select justificativa from itens where item = 'Grampeador') = 'Sem verba.', 'negativa com justificativa';
  assert (select count(*) from buscar_solicitacoes(p_status => 'nao_atendida')) = 1, 'filtro por status do item';
  assert (select count(*) from buscar_solicitacoes(p_item => 'PA DE lixo')) = 1, 'busca sem acento';
  -- Pá de lixo (adquirida antes) + Projetor + Papel A4
  assert (select por_status ->> 'adquirida' from buscar_solicitacoes() where id = sid) = '3', 'resumo por status';
end $$;

\echo '--- avisos (novidades)'
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
do $$
declare n int;
begin
  assert (select count(*) from novidades) = 1, 'B tem 1 aviso (grampeador)';
  delete from novidades where item_id not in (select id from itens);
  get diagnostics n = row_count;
  assert n = 0, 'B não apaga aviso da escola A';
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$
begin
  assert (select count(*) from novidades) = 3, 'A tem 3 itens com aviso';
  assert (select bool_or(novidade) from buscar_solicitacoes()), 'solicitação aparece como atualizada';
  delete from novidades;
  assert (select count(*) from novidades) = 0, 'A marcou como visto';

  -- escola confirma o recebimento
  begin
    perform atualizar_itens(array(select id from itens where item = 'Projetor'), 'entregue');
    assert (select status from itens where item = 'Projetor') = 'entregue', 'projetor adquirido pode ser confirmado';
  end;
  perform atualizar_itens(array(select id from itens where item = 'Pá de LIXO'), 'entregue', 999, 'mexi', '2030-01-01');
  assert (select status::text || quantidade_adquirida || justificativa || previsao_entrega
          from itens where item = 'Pá de LIXO') = 'entregue1Falta de verba.2026-10-10', 'gestor só muda o status';
  assert (select alterado_por_nome from historico h join itens i on i.id = h.item_id
          where i.item = 'Pá de LIXO' order by h.id desc limit 1) = 'Gestora A', 'histórico registra a escola';
  assert (select count(*) from novidades) = 0, 'confirmação da escola não gera aviso para ela mesma';
  begin
    perform atualizar_itens(array(select id from itens where item = 'Pá de LIXO'), 'em_analise');
    assert false, 'estado final não volta';
  exception when raise_exception then null;
  end;
  begin
    perform vincular_usuario('gestor.a@teste', 'X', 'secretaria', null);
    assert false, 'gestor não pode se promover';
  exception when insufficient_privilege then null;
  end;
end $$;

\echo '--- sem perfil e sem login'
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', false);
do $$
begin
  assert (select count(*) from itens) = 0, 'usuário sem perfil não vê nada';
  begin
    perform criar_solicitacao(null, '[{"categoria": "tecnologia", "item": "X", "quantidade": 1}]');
    assert false, 'sem perfil não cadastra';
  exception when raise_exception then null;
  end;
end $$;
reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  assert (select count(*) from itens) = 0, 'anônimo não vê itens';
  assert (select count(*) from solicitacoes) = 0, 'anônimo não vê solicitações';
  assert (select count(*) from perfis) = 0, 'anônimo não vê perfis';
end $$;
reset role;
\echo 'TODOS OS TESTES PASSARAM'
