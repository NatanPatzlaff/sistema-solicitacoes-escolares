-- 001 — Catálogo de produtos (2026-09-30). Rodar depois do schema.sql.
-- Cada item de pedido aponta para um produto do catálogo, ou fica sem produto ("outro item").
-- O nome e a categoria de itens do catálogo vêm do produto, nunca do formulário.

create table produtos (
  id bigint generated always as identity primary key,
  nome text not null check (length(trim(nome)) between 1 and 200),
  nome_busca text not null default '',
  categoria categoria not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create unique index produtos_nome_unico on produtos (nome_busca);

create function antes_de_salvar_produto() returns trigger
language plpgsql set search_path = public
as $$
begin
  new.nome := trim(regexp_replace(new.nome, '\s+', ' ', 'g'));
  new.nome_busca := lower(extensions.unaccent(new.nome));
  return new;
end $$;

create trigger antes_de_salvar_produto before insert or update on produtos
for each row execute function antes_de_salvar_produto();

alter table produtos enable row level security;
create policy ver on produtos for select to authenticated using (true);
create policy cadastrar on produtos for insert to authenticated
with check ((select meu_papel()) = 'secretaria');
create policy editar on produtos for update to authenticated
using ((select meu_papel()) = 'secretaria') with check ((select meu_papel()) = 'secretaria');

alter table itens add column produto_id bigint references produtos;
create index on itens (unidade_id, produto_id, criado_em desc);

-- Item novo: herda a unidade da solicitação; se vier do catálogo, nome e categoria vêm do produto.
create or replace function antes_de_cadastrar_item() returns trigger
language plpgsql set search_path = public
as $$
declare p produtos;
begin
  new.unidade_id := (select unidade_id from solicitacoes where id = new.solicitacao_id);
  if via_api() then
    if meu_papel() is distinct from 'gestor' then
      raise exception 'Apenas gestores cadastram itens.';
    end if;
    if new.unidade_id is distinct from minha_unidade() then
      raise exception 'Solicitação de outra unidade.';
    end if;
  end if;
  if new.produto_id is not null then
    select * into p from produtos where id = new.produto_id;
    if not found or (not p.ativo and via_api()) then
      raise exception 'Produto não está disponível no catálogo.';
    end if;
    new.item := p.nome;
    new.categoria := p.categoria;
  end if;
  new.status := 'cadastrada';
  new.justificativa := null;
  new.quantidade_adquirida := null;
  new.previsao_entrega := null;
  new.item := trim(new.item);
  new.item_busca := lower(extensions.unaccent(new.item));
  new.observacoes := nullif(trim(new.observacoes), '');
  new.criado_em := now();
  new.atualizado_em := now();
  return new;
end $$;

-- Atualização: igual à versão anterior, agora também travando o produto do item.
create or replace function antes_de_atualizar_item() returns trigger
language plpgsql set search_path = public
as $$
begin
  -- dados do pedido não mudam depois de cadastrados
  new.solicitacao_id := old.solicitacao_id;
  new.unidade_id := old.unidade_id;
  new.produto_id := old.produto_id;
  new.categoria := old.categoria;
  new.item := old.item;
  new.item_busca := old.item_busca;
  new.quantidade := old.quantidade;
  new.observacoes := old.observacoes;
  new.criado_em := old.criado_em;
  new.justificativa := nullif(trim(new.justificativa), '');

  if via_api() then
    case meu_papel()
      when 'gestor' then
        if not (old.status = 'adquirida' and new.status = 'entregue') then
          raise exception 'A escola só pode confirmar o recebimento de itens adquiridos.';
        end if;
        new.justificativa := old.justificativa;
        new.quantidade_adquirida := old.quantidade_adquirida;
        new.previsao_entrega := old.previsao_entrega;
      when 'secretaria' then
        if new.status = 'entregue' and old.status <> 'entregue' then
          raise exception 'Quem confirma a entrega é a escola.';
        end if;
      else
        raise exception 'Sem permissão para alterar itens.';
    end case;
  end if;

  if new.status <> old.status and not (
       (old.status = 'cadastrada' and new.status = 'em_analise')
    or (old.status = 'em_analise' and new.status in ('adquirida', 'indisponivel', 'nao_atendida'))
    or (old.status = 'adquirida' and new.status = 'entregue')
  ) then
    raise exception 'Mudança de status não permitida.';
  end if;

  if new.status in ('adquirida', 'entregue') and new.quantidade_adquirida is null then
    raise exception 'Informe a quantidade adquirida.';
  end if;
  if new.status in ('indisponivel', 'nao_atendida') and new.justificativa is null then
    raise exception 'Informe a justificativa.';
  end if;
  if new.quantidade_adquirida is distinct from old.quantidade_adquirida
     and new.quantidade_adquirida <> new.quantidade and new.justificativa is null then
    raise exception 'Quantidade adquirida diferente da pedida: informe a justificativa.';
  end if;

  new.atualizado_em := now();
  return new;
end $$;

-- Gestor: cria a solicitação com todos os itens de uma vez (tudo ou nada).
-- p_itens: [{"produto_id": 12, "quantidade": 3, "observacoes": "..."},            -- do catálogo
--           {"categoria": "...", "item": "...", "quantidade": 1}, ...]            -- outro item
create or replace function criar_solicitacao(p_observacoes text, p_itens jsonb) returns bigint
language plpgsql set search_path = public
as $$
declare sid bigint;
begin
  if jsonb_typeof(p_itens) is distinct from 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'Inclua pelo menos um item.';
  end if;
  insert into solicitacoes (observacoes) values (p_observacoes) returning id into sid;
  insert into itens (solicitacao_id, produto_id, categoria, item, quantidade, observacoes)
  select sid, (x ->> 'produto_id')::bigint, (x ->> 'categoria')::categoria, x ->> 'item',
         (x ->> 'quantidade')::int, x ->> 'observacoes'
  from jsonb_array_elements(p_itens) x;
  return sid;
end $$;

-- Última quantidade pedida pela escola de quem chama, por produto (preenche o novo pedido).
create function ultimas_quantidades() returns table (produto_id bigint, quantidade int)
language sql stable set search_path = public
as $$
  select distinct on (i.produto_id) i.produto_id, i.quantidade
  from itens i
  where i.produto_id is not null and i.unidade_id = minha_unidade()
  order by i.produto_id, i.criado_em desc, i.id desc
$$;
