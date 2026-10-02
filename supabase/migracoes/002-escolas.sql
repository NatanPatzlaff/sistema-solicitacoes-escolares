-- 002 — Lista correta das unidades (2026-10-02). Renomeia as que já existem (mantém os IDs),
-- remove Marcolino Pedroso (sem pedidos) e cria as novas. A Secretaria de Educação também
-- faz pedidos para si mesma, como uma unidade comum.

update unidades set nome = 'Pré-Escolar Cinderela' where nome = 'Pré Escolar Cinderela';
update unidades set nome = 'Escola de Educação Infantil e Creche Municipal' where nome = 'Creche Municipal';
delete from unidades where nome = 'Marcolino Pedroso';

insert into unidades (nome) values
  ('Grupo Escolar Paulo Freire'),
  ('Núcleo Educacional Municipal Nova Estrela'),
  ('Pré-Escolar Cinderela'),
  ('Escola de Educação Infantil e Creche Municipal'),
  ('Centro Educacional Esportivo e Cultural'),
  ('Secretaria de Educação')
on conflict (nome) do nothing;
