-- Confere a coerência do seed.sql (usado por testar-local.sh).
\pset footer off
\echo 'Itens por solicitação e status:'
select s.id as solicitacao, u.nome as escola, i.status, count(*) as itens
from itens i join solicitacoes s on s.id = i.solicitacao_id join unidades u on u.id = s.unidade_id
group by 1, 2, 3 order by 1, 3;

do $$
declare cinderela bigint := (select id from unidades where nome = 'Pré-Escolar Cinderela');
begin
  assert (select count(*) from solicitacoes) = 4, '4 solicitações (uma por lista)';
  assert (select count(*) from itens) = 301, 'todos os 301 itens ligados a um produto do catálogo';
  assert not exists (select 1 from itens i join produtos p on p.id = i.produto_id where i.item <> p.nome or i.categoria <> p.categoria),
    'item com nome/categoria diferente do produto';
  assert not exists (select 1 from itens i join solicitacoes s on s.id = i.solicitacao_id where i.unidade_id <> s.unidade_id),
    'item com unidade diferente da solicitação';
  assert not exists (select 1 from itens where status in ('adquirida', 'entregue') and quantidade_adquirida is null),
    'adquirida/entregue sem quantidade adquirida';
  assert not exists (select 1 from itens where status in ('indisponivel', 'nao_atendida') and coalesce(justificativa, '') = ''),
    'indisponível/não atendida sem justificativa';
  assert not exists (select 1 from itens where quantidade_adquirida <> quantidade and coalesce(justificativa, '') = ''),
    'quantidade alterada sem justificativa';
  assert not exists (select 1 from itens i where status <> (
      select h.status from historico h where h.item_id = i.id order by alterado_em desc, id desc limit 1)),
    'último status do histórico diferente do atual';
  assert not exists (select 1 from itens i where not exists (
      select 1 from historico h where h.item_id = i.id and h.status = 'cadastrada')),
    'item sem registro de cadastro';
  assert not exists (select 1 from itens where criado_em > now() or atualizado_em > now()),
    'data no futuro';
  assert not exists (select 1 from itens where item_busca <> lower(extensions.unaccent(item))),
    'item_busca não normalizado';
  assert (select count(*) from pg_trigger where tgrelid = 'itens'::regclass and not tgisinternal and tgenabled <> 'O') = 0,
    'triggers ficaram desligados';

  -- Um gestor da Cinderela, com o seed carregado, continua vendo só a própria escola.
  insert into auth.users values ('00000000-0000-0000-0000-0000000000c1', 'gestor@cinderela.teste');
  perform vincular_usuario('gestor@cinderela.teste', 'Gestor Cinderela', 'gestor', 'Pré-Escolar Cinderela');
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', true);
  assert (select count(*) from itens where unidade_id <> cinderela) = 0, 'gestor vê outra escola';
  assert (select count(*) from itens) = 23, 'gestor da Cinderela deveria ver 23 itens';
  assert (select count(*) from buscar_solicitacoes()) = 1, 'gestor da Cinderela vê 1 solicitação';
  assert (select count(*) from buscar_solicitacoes(p_item => 'agua sanitaria')) = 1, 'busca sem acento';
  reset role;
  raise notice 'Seed coerente: % solicitações, % itens, % eventos de histórico.',
    (select count(*) from solicitacoes), (select count(*) from itens), (select count(*) from historico);
  delete from perfis where email = 'gestor@cinderela.teste';
  delete from auth.users where email = 'gestor@cinderela.teste';
end $$;
