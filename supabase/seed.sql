-- DADOS DE TESTE — nunca rodar no projeto de produção.
-- Itens reais das listas enviadas pelas escolas (Cinderela, EEICM, Grupo Escolar Paulo Freire).
-- Cada lista vira uma solicitação; status, datas e histórico dos itens são fictícios,
-- para testar filtros, busca, paginação, cards e ações em lote.
-- Uso: depois do schema.sql, das migrações e do catalogo.sql, num banco SEM solicitações (SQL Editor do projeto de teste, ou local).
--
-- Quantidades: número principal da lista; o texto original vai em "observações" quando
-- tinha embalagem ("3 caixas", "5 de cada cor").
-- Ficaram de fora só os itens sem quantidade na lista original ("--", "??????").

begin;

do $$ begin
  if exists (select 1 from solicitacoes) then
    raise exception 'Este banco já tem solicitações. O seed só roda em banco de teste vazio.';
  end if;
end $$;

insert into unidades (nome) values
  ('Pré-Escolar Cinderela'),
  ('Escola de Educação Infantil e Creche Municipal'),
  ('Grupo Escolar Paulo Freire'),
  ('Núcleo Educacional Municipal Nova Estrela'),
  ('Centro Educacional Esportivo e Cultural'),
  ('Secretaria de Educação')
on conflict (nome) do nothing;

create temp table pedidos (codigo text, escola text, observacoes text, criado_em timestamptz, id bigint) on commit drop;
insert into pedidos values
  ('E1', 'Escola de Educação Infantil e Creche Municipal', 'Pedido de material pedagógico — setembro de 2026.', '2026-09-03 14:00-03', null),
  ('E2', 'Escola de Educação Infantil e Creche Municipal', 'Pedidos gerais de cozinha e limpeza.', '2026-09-03 14:20-03', null),
  ('C',  'Pré-Escolar Cinderela', null, '2026-09-22 09:15-03', null),
  ('G',  'Grupo Escolar Paulo Freire', 'Lista de materiais para 2027.', '2026-09-26 10:30-03', null);

with criadas as (
  insert into solicitacoes (unidade_id, observacoes, criado_em)
  select u.id, p.observacoes, p.criado_em
  from pedidos p join unidades u on u.nome = p.escola
  order by p.criado_em
  returning id, criado_em
)
update pedidos p set id = c.id from criadas c where c.criado_em = p.criado_em;

-- Triggers de itens desligados só durante o seed, para gravar status e datas passados.
alter table itens disable trigger user;

with lista (pedido, cat, item, qtd, obs, produto) as (values
  -- Cinderela — material de limpeza (lista manuscrita)
  ('C','LH','Água sanitária',20,null,'Água sanitária'),
  ('C','LH','Álcool líquido',4,'4 caixas','Álcool líquido (caixa)'),
  ('C','LH','Desinfetante',15,null,'Desinfetante'),
  ('C','LH','Sabonete líquido',5,null,'Sabonete líquido'),
  ('C','LH','Bom Ar (aromatizador)',3,'3 caixas','Bom Ar (aromatizador)'),
  ('C','LH','Cera líquida',3,'3 caixas','Cera líquida (caixa)'),
  ('C','LH','Luva de procedimento P',4,'4 caixas','Luva de procedimento P (caixa)'),
  ('C','LH','Luva de procedimento M',4,'4 caixas','Luva de procedimento M (caixa)'),
  ('C','LH','Detergente Girando Sol',6,'6 caixas','Detergente Girando Sol (caixa)'),
  ('C','LH','Esponja verde/amarela',30,null,'Esponja verde/amarela'),
  ('C','LH','Saco de lixo 15 L',5,'5 fardos','Saco de lixo 15 L (fardo)'),
  ('C','LH','Saco de lixo 50 L',6,'6 fardos','Saco de lixo 50 L (fardo)'),
  ('C','LH','Saco de lixo 100 L',5,'5 fardos','Saco de lixo 100 L (fardo)'),
  ('C','LH','Saponáceo cremoso',3,'3 caixas','Saponáceo cremoso (caixa)'),
  ('C','LH','Touca descartável',4,'4 pacotes','Touca descartável (pacote)'),
  ('C','LH','Desengraxante',10,null,'Desengraxante'),
  ('C','LH','Limpador multiuso limpeza pesada com cloro (tira-limo)',3,'3 caixas — tipo Veja','Limpador multiuso limpeza pesada com cloro (tira-limo)'),
  ('C','LH','Limpador multiuso limpeza diária',3,'3 caixas','Limpador multiuso limpeza diária (caixa)'),
  ('C','LH','Pano de chão',8,null,'Pano de chão'),
  ('C','LH','Amaciante',10,null,'Amaciante'),
  ('C','LH','Escova de vaso sanitário',6,null,'Escova de vaso sanitário'),
  ('C','LH','Papel toalha',150,'150 fardos','Papel toalha (fardo)'),
  ('C','LH','Papel higiênico',100,'100 fardos','Papel higiênico (fardo)'),

  -- EEICM — material pedagógico (setembro/2026)
  ('E1','ME','Alfinete colorido',3,'3 caixas','Alfinete colorido (caixa)'),
  ('E1','MP','Algodão',20,'20 pacotes','Algodão (pacote)'),
  ('E1','MP','Argola plástica média',30,null,'Argola plástica média'),
  ('E1','MP','Argola plástica pequena',30,null,'Argola plástica pequena'),
  ('E1','MP','Balão tamanho 9',5,'5 pacotes de cada cor','Balão tamanho 9 (pacote)'),
  ('E1','MP','Barbante cru',8,'8 rolos','Barbante cru (rolo)'),
  ('E1','MP','Bastão de cola quente grande',5,'5 pacotes','Bastão de cola quente grande (pacote)'),
  ('E1','MP','Bastão de cola quente pequeno',2,'2 pacotes','Bastão de cola quente pequeno (pacote)'),
  ('E1','MP','Bobina de papel kraft 60x50',1,'1 rolo','Bobina de papel kraft 60x50 (rolo)'),
  ('E1','MP','Borracha',1,'1 caixinha','Borracha (caixinha)'),
  ('E1','MP','Caderno pequeno capa dura 96 folhas azul',20,null,'Caderno pequeno capa dura 96 folhas azul'),
  ('E1','TE','Caixa de som para sala',5,null,'Caixa de som para sala'),
  ('E1','ME','Canetão para quadro branco',10,'10 de cada cor: azul, vermelho, preto e verde','Canetão para quadro branco'),
  ('E1','ME','Caneta esferográfica',1,'1 caixinha de cada cor: preta, azul e vermelha','Caneta esferográfica (caixinha)'),
  ('E1','ME','Canetinha marcador para retroprojetor',20,'20 de cada cor: preta, azul, vermelha e verde','Canetinha marcador para retroprojetor'),
  ('E1','MP','Canetinha colorida',10,null,'Canetinha colorida'),
  ('E1','MP','Canudo grande (grosso)',3,'3 pacotes','Canudo grande (grosso)'),
  ('E1','MP','Canudo médio (grosso)',5,'5 pacotes','Canudo médio (grosso)'),
  ('E1','ME','Capa plástica transparente para encadernar',200,null,'Capa plástica transparente para encadernar'),
  ('E1','MP','Carrinho de bebê (brinquedo)',5,null,'Carrinho de bebê (brinquedo)'),
  ('E1','MP','Cilindro plástico vazado',40,null,'Cilindro plástico vazado'),
  ('E1','ME','Clipe tamanho G',1,'1 caixa','Clipe tamanho G (caixa)'),
  ('E1','ME','Clipe tamanho M',1,'1 caixa','Clipe tamanho M (caixa)'),
  ('E1','ME','Clipe tamanho P',1,'1 caixa','Clipe tamanho P (caixa)'),
  ('E1','MP','Cola branca pequena',20,null,'Cola branca pequena'),
  ('E1','ME','Cola de alto contato (Tec Bond)',20,null,'Cola de alto contato (Tec Bond)'),
  ('E1','MP','Cola alto-relevo',5,'5 de cada cor','Cola alto-relevo'),
  ('E1','MP','Cola glitter sortida',2,'2 de cada cor','Cola glitter sortida'),
  ('E1','MP','Utensílios de cozinha de brinquedo em madeira natural',5,'5 coleções','Utensílios de cozinha de brinquedo em madeira natural'),
  ('E1','MP','Corante alimentício em gota amarelo',10,null,'Corante alimentício em gota amarelo'),
  ('E1','MP','Corante alimentício em gota azul',10,null,'Corante alimentício em gota azul'),
  ('E1','MP','Corante alimentício em gota rosa',10,null,'Corante alimentício em gota rosa'),
  ('E1','MP','Corante alimentício em gota roxo',10,null,'Corante alimentício em gota roxo'),
  ('E1','MP','Corante alimentício em gota verde',10,null,'Corante alimentício em gota verde'),
  ('E1','MP','Corante alimentício em gota vermelho',10,null,'Corante alimentício em gota vermelho'),
  ('E1','MP','Corda (professora de movimento)',50,'50 metros','Corda (professora de movimento)'),
  ('E1','MP','Corda de varal (ambientar salas)',1,'1 rolo','Corda de varal (ambientar salas)'),
  ('E1','ME','Corretivo',5,null,'Corretivo'),
  ('E1','LH','Cotonete',20,'20 caixas com 100 unidades','Cotonete (caixa com 100 unidades)'),
  ('E1','ME','Elástico de borracha',5,null,'Elástico de borracha'),
  ('E1','ME','Espiral para encadernar 17 mm',150,null,'Espiral para encadernar 17 mm'),
  ('E1','ME','Estilete grande',5,null,'Estilete grande'),
  ('E1','MP','Fio de náilon 0,50 mm',5,null,'Fio de náilon 0,50 mm'),
  ('E1','MP','Fita crepe colorida 2 cm',5,null,'Fita crepe colorida 2 cm'),
  ('E1','ME','Fita crepe grande',10,null,'Fita crepe grande'),
  ('E1','ME','Fita crepe pequena',10,null,'Fita crepe pequena'),
  ('E1','ME','Fita isolante colorida',5,null,'Fita isolante colorida'),
  ('E1','ME','Fita adesiva marrom',30,'Boa qualidade','Fita adesiva marrom'),
  ('E1','MP','Fita mimosa 7 mm',2,'2 rolos de cada cor','Fita mimosa 7 mm (rolo)'),
  ('E1','MP','Fita mimosa 10 mm',2,'2 rolos de cada cor','Fita mimosa 10 mm (rolo)'),
  ('E1','MP','Fita mimosa 14 mm',2,'2 rolos de cada cor','Fita mimosa 14 mm (rolo)'),
  ('E1','ME','Fita transparente larga',20,null,'Fita transparente larga'),
  ('E1','ME','Fita transparente média',20,null,'Fita transparente média'),
  ('E1','ME','Fita transparente estreita',14,null,'Fita transparente estreita'),
  ('E1','MP','Folha dura 120 g',100,'100 pacotes','Folha dura 120 g (pacote)'),
  ('E1','MP','Folha dura 180 g',20,'20 pacotes','Folha dura 180 g (pacote)'),
  ('E1','ME','Folha para plastificar',40,'40 pacotes','Folha para plastificar (pacote)'),
  ('E1','MP','Giz de cera grosso',20,'20 caixinhas','Giz de cera grosso (caixinha)'),
  ('E1','ME','Giz de quadro colorido',20,'20 caixinhas','Giz de quadro colorido (caixinha)'),
  ('E1','ME','Grampeador de escritório',5,null,'Grampeador de escritório'),
  ('E1','MP','Prendedor de roupa',20,'20 pacotes com 12','Prendedor de roupa (pacote com 12)'),
  ('E1','ME','Grampo para grampeador de madeira',1,'Tamanhos diversos','Grampo para grampeador de madeira'),
  ('E1','MP','Haste de chenille',40,null,'Haste de chenille'),
  ('E1','MP','Kit 10 agulhas plásticas de tapeceiro 7 cm',1,null,'Kit 10 agulhas plásticas de tapeceiro 7 cm'),
  ('E1','MP','Kit 10 cestas pãozeiras de bambu 33x25x12',1,null,'Kit 10 cestas pãozeiras de bambu 33x25x12'),
  ('E1','MP','Kit 30 pinças plásticas de coordenação motora',2,'2 conjuntos','Kit 30 pinças plásticas de coordenação motora (conjunto)'),
  ('E1','MP','Kit panelinhas infantis de madeira (11 peças)',5,null,'Kit panelinhas infantis de madeira (11 peças)'),
  ('E1','MP','Lápis preto',1,'1 caixinha','Lápis preto (caixinha)'),
  ('E1','MP','Lápis de cor',20,'20 caixinhas','Lápis de cor (caixinha)'),
  ('E1','MP','Língua de sogra',30,null,'Língua de sogra'),
  ('E1','LH','Luva de procedimento G',80,'80 caixas','Luva de procedimento G (caixa)'),
  ('E1','LH','Luva de procedimento M',200,'200 caixas','Luva de procedimento M (caixa)'),
  ('E1','LH','Luva de procedimento P',20,'20 caixas','Luva de procedimento P (caixa)'),
  ('E1','ME','Marca-texto',16,'14 ou 16 unidades','Marca-texto'),
  ('E1','MP','Massinha de modelar',40,null,'Massinha de modelar'),
  ('E1','MP','Palito de churrasco grande',5,'5 pacotes','Palito de churrasco grande (pacote)'),
  ('E1','MP','Palito de churrasco médio',5,'5 pacotes','Palito de churrasco médio (pacote)'),
  ('E1','MP','Palito de picolé',10,'10 pacotes','Palito de picolé (pacote)'),
  ('E1','MP','Papel alumínio grosso',10,'10 rolos','Papel alumínio grosso (rolo)'),
  ('E1','ME','Papel autoadesivo',30,'30 pacotes','Papel autoadesivo (pacote)'),
  ('E1','ME','Papel fotográfico 120 g',400,'400 pacotes','Papel fotográfico 120 g (pacote)'),
  ('E1','ME','Papel fotográfico adesivo 120 g',50,'50 pacotes','Papel fotográfico adesivo 120 g (pacote)'),
  ('E1','MP','Papel kraft marrom 120 g',50,'50 pacotes','Papel kraft marrom 120 g (pacote)'),
  ('E1','MP','Papel panamá',20,'20 folhas','Papel panamá'),
  ('E1','MP','Papel pardo G',4,'4 rolos','Papel pardo G (rolo)'),
  ('E1','ME','Papel ponto (bobina grande)',200,null,'Papel ponto (bobina grande)'),
  ('E1','ME','Pasta plástica',150,null,'Pasta plástica'),
  ('E1','ME','Perfurador de papel 1 furo',1,null,'Perfurador de papel 1 furo'),
  ('E1','ME','Pilha alcalina AA',20,'20 caixas com 10','Pilha alcalina AA (caixa com 10)'),
  ('E1','ME','Pilha alcalina AAA',20,'20 caixas com 10','Pilha alcalina AAA (caixa com 10)'),
  ('E1','MP','Pistola de cola quente grande',8,null,'Pistola de cola quente grande'),
  ('E1','MP','Pistola de cola quente pequena',20,null,'Pistola de cola quente pequena'),
  ('E1','MP','Papel celofane colorido',5,'5 pacotes','Papel celofane colorido (pacote)'),
  ('E1','ME','Saco zip grande',5,null,'Saco zip grande'),
  ('E1','ME','Bloco adesivo (post-it) P, M e G',5,'5 de cada tamanho','Bloco adesivo (post-it) P, M e G'),
  ('E1','MP','Prato de papelão cru G',2,'2 pacotes','Prato de papelão cru G (pacote)'),
  ('E1','MP','Prato de papelão cru M',2,'2 pacotes','Prato de papelão cru M (pacote)'),
  ('E1','MP','Prato de papelão cru P',2,'2 pacotes','Prato de papelão cru P (pacote)'),
  ('E1','MP','Spray colorido para cabelo',10,'10 de cada cor','Spray colorido para cabelo'),
  ('E1','MP','Tecido chita floral',1,'1 rolo','Tecido chita floral (rolo)'),
  ('E1','MP','Tecido chita',1,'1 rolo','Tecido chita (rolo)'),
  ('E1','MP','Tecido oxford amarelo',1,'1 rolo','Tecido oxford amarelo (rolo)'),
  ('E1','MP','Tecido oxford azul',1,'1 rolo','Tecido oxford azul (rolo)'),
  ('E1','MP','Tecido oxford branco',1,'1 rolo','Tecido oxford branco (rolo)'),
  ('E1','MP','Tecido oxford laranja',1,'1 rolo','Tecido oxford laranja (rolo)'),
  ('E1','MP','Tecido oxford preto',1,'1 rolo','Tecido oxford preto (rolo)'),
  ('E1','MP','Tecido oxford rosa',1,'1 rolo','Tecido oxford rosa (rolo)'),
  ('E1','MP','Tecido oxford roxo',1,'1 rolo','Tecido oxford roxo (rolo)'),
  ('E1','MP','Tecido oxford vermelho',1,'1 rolo','Tecido oxford vermelho (rolo)'),
  ('E1','MP','Tecido para lençol infantil',1,'1 rolo','Tecido para lençol infantil (rolo)'),
  ('E1','MP','Tecido tule amarelo',1,'1 rolo','Tecido tule amarelo (rolo)'),
  ('E1','MP','Tecido tule azul',1,'1 rolo','Tecido tule azul (rolo)'),
  ('E1','MP','Tecido tule bege',1,'1 rolo','Tecido tule bege (rolo)'),
  ('E1','MP','Tecido tule branco',2,'Aparece 2 vezes na lista (1 rolo cada)','Tecido tule branco'),
  ('E1','MP','Tecido tule laranja',1,'1 rolo','Tecido tule laranja (rolo)'),
  ('E1','MP','Tecido tule preto',1,'1 rolo','Tecido tule preto (rolo)'),
  ('E1','MP','Tecido tule rosa',2,'Aparece 2 vezes na lista (1 rolo cada)','Tecido tule rosa'),
  ('E1','MP','Tecido tule roxo',1,'1 rolo','Tecido tule roxo (rolo)'),
  ('E1','MP','Tecido tule vermelho',1,'1 rolo','Tecido tule vermelho (rolo)'),
  ('E1','MP','Tecido voal bege',1,'1 rolo','Tecido voal bege (rolo)'),
  ('E1','MP','Tecido voal branco',1,'1 rolo','Tecido voal branco (rolo)'),
  ('E1','MP','Tecido voal preto',1,'1 rolo','Tecido voal preto (rolo)'),
  ('E1','MP','Tecido xadrez',1,'1 rolo','Tecido xadrez (rolo)'),
  ('E1','MP','Tesoura escolar sem ponta 13 cm',30,null,'Tesoura escolar sem ponta 13 cm'),
  ('E1','ME','Tesoura multiuso de escritório inox 21 cm',10,null,'Tesoura multiuso de escritório inox 21 cm'),
  ('E1','ME','Tinta para impressora Canon GI-10 ciano',10,null,'Tinta para impressora Canon GI-10 ciano'),
  ('E1','ME','Tinta para impressora Canon GI-10 magenta',10,null,'Tinta para impressora Canon GI-10 magenta'),
  ('E1','ME','Tinta para impressora Canon GI-10 preta',40,null,'Tinta para impressora Canon GI-10 preta'),
  ('E1','ME','Tinta para impressora Canon GI-10 amarela',10,null,'Tinta para impressora Canon GI-10 amarela'),
  ('E1','ME','Tinta para impressora Epson L3250 preta',10,null,'Tinta para impressora Epson L3250 preta'),
  ('E1','ME','Tinta para impressora Epson L3250 ciano',3,null,'Tinta para impressora Epson L3250 ciano'),
  ('E1','ME','Tinta para impressora Epson L3250 magenta',3,null,'Tinta para impressora Epson L3250 magenta'),
  ('E1','ME','Tinta para impressora Epson L3250 amarela',3,null,'Tinta para impressora Epson L3250 amarela'),
  ('E1','ME','Vinil adesivo transparente A4 (etiqueta para mamadeiras)',2,'2 pacotes — resistente a água e micro-ondas','Vinil adesivo transparente A4 (etiqueta para mamadeiras)'),
  ('E1','MP','Zíper dentado 20 cm',10,null,'Zíper dentado 20 cm'),
  ('E1','MP','Zíper dentado 30 cm',10,null,'Zíper dentado 30 cm'),

  -- EEICM — cozinha e limpeza (só o que cabe nas categorias atuais)
  ('E2','LH','Água sanitária 5 L',100,null,'Água sanitária 5 L'),
  ('E2','LH','Álcool em gel 70%',1,'1 caixa com 24','Álcool em gel 70% (caixa com 24)'),
  ('E2','LH','Álcool líquido 70%',30,'30 caixas com 12','Álcool líquido 70% (caixa com 12)'),
  ('E2','LH','Álcool líquido 90%',10,'10 caixas com 12','Álcool líquido 90% (caixa com 12)'),
  ('E2','LH','Amaciante 5 L',50,null,'Amaciante 5 L'),
  ('E2','LH','Bom Ar (aromatizador)',100,null,'Bom Ar (aromatizador)'),
  ('E2','LH','Pano para vassoura (bruxa) 81x14 cm',3,null,'Pano para vassoura (bruxa) 81x14 cm'),
  ('E2','LH','Desengraxante 500 mL',50,null,'Desengraxante 500 mL'),
  ('E2','LH','Desinfetante 5 L',200,null,'Desinfetante 5 L'),
  ('E2','LH','Detergente',16,'16 caixas com 24','Detergente (caixa com 24)'),
  ('E2','LH','Escova de vaso sanitário',10,null,'Escova de vaso sanitário'),
  ('E2','LH','Esponja de aço inox',50,null,'Esponja de aço inox'),
  ('E2','LH','Esponja dupla face grande',20,null,'Esponja dupla face grande'),
  ('E2','LH','Esponja lava-louças',380,null,'Esponja lava-louças'),
  ('E2','LH','Lixeira com tampa e pedal 30 L',5,null,'Lixeira com tampa e pedal 30 L'),
  ('E2','LH','Lixeira com tampa 50 L',4,null,'Lixeira com tampa 50 L'),
  ('E2','LH','Multiuso limpeza pesada 500 mL',200,null,'Multiuso limpeza pesada 500 mL'),
  ('E2','LH','Pano de chão G',10,'10 fardos com 10','Pano de chão G (fardo com 10)'),
  ('E2','LH','Pano de prato G 1x1 m',20,null,'Pano de prato G 1x1 m'),
  ('E2','LH','Pano mágico de limpeza grande',20,null,'Pano mágico de limpeza grande'),
  ('E2','LH','Pano mágico de limpeza pequeno',30,null,'Pano mágico de limpeza pequeno'),
  ('E2','LH','Papel higiênico (fardo com 26 rolos)',400,'400 fardos','Papel higiênico (fardo com 26 rolos)'),
  ('E2','LH','Papel toalha 1000 folhas',800,'800 pacotes','Papel toalha 1000 folhas (pacote)'),
  ('E2','LH','Rodo grande de plástico 80 cm',10,null,'Rodo grande de plástico 80 cm'),
  ('E2','LH','Rodo pequeno de plástico',5,null,'Rodo pequeno de plástico'),
  ('E2','LH','Sabonete líquido 5 L',100,null,'Sabonete líquido 5 L'),
  ('E2','LH','Saco de lixo preto 100 L',200,'200 rolos com 100','Saco de lixo preto 100 L (rolo com 100)'),
  ('E2','LH','Saco de lixo preto 50 L',200,'200 rolos com 100','Saco de lixo preto 50 L (rolo com 100)'),
  ('E2','LH','Saco de lixo azul 50 L',100,'100 rolos com 100','Saco de lixo azul 50 L (rolo com 100)'),
  ('E2','LH','Saponáceo cremoso',10,'10 caixas com 12','Saponáceo cremoso (caixa com 12)'),
  ('E2','LH','Touca descartável',2,'2 pacotes com 100','Touca descartável (pacote com 100)'),
  ('E2','LH','Vassoura de palha',10,null,'Vassoura de palha'),
  ('E2','LH','Vassoura de plástico',10,null,'Vassoura de plástico'),
  ('E2','MI','Torneira elétrica de bancada (Zagonel)',5,null,'Torneira elétrica de bancada (Zagonel)'),
  ('E2','MI','Torneira plástica branca para banheiro',12,null,'Torneira plástica branca para banheiro'),
  ('E2','MI','Torneira plástica preta',10,null,'Torneira plástica preta'),

  -- Grupo Escolar Paulo Freire — materiais escolares (2027)
  ('G','ME','Adesivo instantâneo',8,null,'Adesivo instantâneo'),
  ('G','ME','Apagador de quadro branco',12,null,'Apagador de quadro branco'),
  ('G','MP','Apontador com depósito',250,null,'Apontador com depósito'),
  ('G','MP','Argila',6,null,'Argila'),
  ('G','MP','Balões de cores diversas',3,'3 pacotes de cada cor','Balões de cores diversas (pacote)'),
  ('G','MP','Barbante cru fio grosso nº 6',3,null,'Barbante cru fio grosso nº 6'),
  ('G','MP','Bastão de cola quente grosso',1,'1 pacote','Bastão de cola quente grosso (pacote)'),
  ('G','MP','Borracha',250,null,'Borracha'),
  ('G','MP','Caderno de caligrafia capa dura',200,null,'Caderno de caligrafia capa dura'),
  ('G','MP','Caderno de desenho grande capa dura 48 folhas',250,null,'Caderno de desenho grande capa dura 48 folhas'),
  ('G','MP','Caderno espiral universitário capa dura 96 folhas',600,null,'Caderno espiral universitário capa dura 96 folhas'),
  ('G','MP','Caderno pequeno capa dura 48 folhas',300,null,'Caderno pequeno capa dura 48 folhas'),
  ('G','MP','Giz de cera 12 cores',20,'20 caixas','Giz de cera 12 cores (caixa)'),
  ('G','ME','Caneta azul',1,'1 caixa','Caneta azul (caixa)'),
  ('G','ME','Canetinha para retroprojetor 2.0',3,'3 caixas de cada cor','Canetinha para retroprojetor 2.0 (caixa)'),
  ('G','ME','Capa para encadernação preta fosca',1,'1 resma','Capa para encadernação preta fosca (resma)'),
  ('G','MP','Cartolina amarela',100,null,'Cartolina amarela'),
  ('G','ME','Clipe nº 2',10,null,'Clipe nº 2'),
  ('G','ME','Clipe nº 4',4,null,'Clipe nº 4'),
  ('G','ME','Clipe nº 6',4,null,'Clipe nº 6'),
  ('G','MP','Cola escolar',280,null,'Cola escolar'),
  ('G','MP','Colete infantojuvenil',15,null,'Colete infantojuvenil'),
  ('G','ME','Espiral para encadernação 9 mm',2,'2 pacotes','Espiral para encadernação 9 mm (pacote)'),
  ('G','ME','Espiral para encadernação 14 mm',4,'4 pacotes','Espiral para encadernação 14 mm (pacote)'),
  ('G','MP','Estojo de canetinha ponta fina',5,'5 caixas com 12','Estojo de canetinha ponta fina (caixa com 12)'),
  ('G','MP','Estojo de canetinha ponta grossa',20,null,'Estojo de canetinha ponta grossa'),
  ('G','ME','Etiqueta adesiva',2,'2 caixas','Etiqueta adesiva (caixa)'),
  ('G','MP','EVA preto',40,null,'EVA preto'),
  ('G','MP','EVA com brilho',20,'10 vermelho e 10 pink','EVA com brilho'),
  ('G','ME','Fita adesiva 3M',25,null,'Fita adesiva 3M'),
  ('G','ME','Fita crepe branca 2,5 cm',10,null,'Fita crepe branca 2,5 cm'),
  ('G','ME','Fita transparente larga 4 cm',30,null,'Fita transparente larga 4 cm'),
  ('G','ME','Fita transparente 2,5 cm',15,null,'Fita transparente 2,5 cm'),
  ('G','MP','Fita mimosa estreita nº 1',1,'1 de cada cor','Fita mimosa estreita nº 1'),
  ('G','MP','Fita mimosa média',4,'4 de cada cor','Fita mimosa média'),
  ('G','ME','Papel A4 120 g',50,'50 pacotes','Papel A4 120 g (pacote)'),
  ('G','ME','Papel A4 180 g',30,'30 pacotes','Papel A4 180 g (pacote)'),
  ('G','ME','Papel A4 colorido (azul, verde, amarelo, rosa)',3,'3 resmas de cada cor (500 folhas)','Papel A4 colorido (azul, verde, amarelo, rosa)'),
  ('G','ME','Papel A4 sulfite',60,'60 caixas','Papel A4 sulfite (caixa)'),
  ('G','ME','Papel A4 reciclado',20,'20 resmas','Papel A4 reciclado (resma)'),
  ('G','MP','Placa de isopor',12,null,'Placa de isopor'),
  ('G','ME','Giz de quadro colorido',30,'30 caixas','Giz de quadro colorido (caixa)'),
  ('G','ME','Grampeador',5,null,'Grampeador'),
  ('G','ME','Grampo 26/6',5,'5 caixas','Grampo 26/6 (caixa)'),
  ('G','MP','Prendedor de roupa',30,'30 pacotes','Prendedor de roupa (pacote)'),
  ('G','MP','Lápis de cor',250,null,'Lápis de cor'),
  ('G','MP','Lápis preto',5,'5 caixas','Lápis preto (caixa)'),
  ('G','ME','Livro ata',1,null,'Livro ata'),
  ('G','ME','Marcador de quadro branco',50,'50 de cada cor','Marcador de quadro branco'),
  ('G','MP','Massa de EVA sortida',10,null,'Massa de EVA sortida'),
  ('G','MP','Massa de modelar',150,null,'Massa de modelar'),
  ('G','MP','Palito de algodão-doce',2,'2 pacotes','Palito de algodão-doce (pacote)'),
  ('G','MP','Palito de churrasco',5,'5 pacotinhos','Palito de churrasco (pacote)'),
  ('G','MP','Palito de picolé',20,'20 pacotes com 100','Palito de picolé (pacote com 100)'),
  ('G','ME','Papel adesivo Contact 80 micras',5,null,'Papel adesivo Contact 80 micras'),
  ('G','MP','Papel kraft',1,'1 rolo','Papel kraft (rolo)'),
  ('G','MP','Papel dupla face',10,'10 de cada cor','Papel dupla face'),
  ('G','MP','Papel duplex',10,'10 de cada cor','Papel duplex'),
  ('G','ME','Papel fotográfico',5,'5 resmas','Papel fotográfico (resma)'),
  ('G','ME','Papel fotográfico adesivo',5,'5 resmas','Papel fotográfico adesivo (resma)'),
  ('G','ME','Pilha AAA',30,null,'Pilha AAA'),
  ('G','ME','Pilha AA',15,null,'Pilha AA'),
  ('G','ME','Pincel atômico (canetão)',2,'2 caixas de cada cor','Pincel atômico (canetão)'),
  ('G','ME','Pouch para plastificar',10,'10 resmas com 100 folhas','Pouch para plastificar (resma com 100 folhas)'),
  ('G','ME','Refil de canetão de quadro branco',30,'30 de cada cor','Refil de canetão de quadro branco'),
  ('G','MP','Régua',250,null,'Régua'),
  ('G','MP','Rolinho de espuma',5,null,'Rolinho de espuma'),
  ('G','ME','Suporte para fita adesiva larga',3,null,'Suporte para fita adesiva larga'),
  ('G','ME','Tesoura de uso geral',10,null,'Tesoura de uso geral'),
  ('G','MP','Tinta acrílica brilhante',1,'1 de cada cor','Tinta acrílica brilhante'),
  ('G','MP','Tinta PVA',1,'1 de cada cor','Tinta PVA'),
  ('G','MP','Tinta para tecido',1,'1 de cada cor','Tinta para tecido'),
  ('G','MP','Tinta facial',2,'2 pacotes','Tinta facial (pacote)'),
  ('G','ME','Tinta para impressora Canon 7010',15,'15 de cada cor','Tinta para impressora Canon 7010'),
  ('G','MP','TNT',3,'1 laranja, 1 marrom, 1 lilás claro','TNT'),

  -- Itens que dependiam das categorias Cozinha e utensílios (CZ) e Mobiliário e equipamentos (MB)
  ('E1','MB','Cadeira de rodinha (escritório)',5,null,'Cadeira de rodinha (escritório)'),
  ('E1','MB','Caminha para sono',20,null,'Caminha para sono'),
  ('E1','MB','Mesinha para ambientar as salas',2,null,'Mesinha para ambientar as salas'),
  ('E1','MB','Tatame',1,'1 conjunto — repor os velhos','Tatame (conjunto)'),
  ('E1','MB','Tenda gazebo dobrável 3x3 m azul',2,'Com proteção UV e impermeável','Tenda gazebo dobrável 3x3 m azul'),
  ('E2','CZ','Amassador de batatas inox industrial (cabo grande)',1,null,'Amassador de batatas inox industrial (cabo grande)'),
  ('E2','CZ','Bacia com tampa G',5,null,'Bacia com tampa G'),
  ('E2','CZ','Bacia com tampa M',5,null,'Bacia com tampa M'),
  ('E2','MB','Caixa plástica empilhável 52 L preta (brinquedos)',10,null,'Caixa plástica empilhável 52 L preta (brinquedos)'),
  ('E2','CZ','Caixa plástica vazada 33 L preta (frutas)',12,null,'Caixa plástica vazada 33 L preta (frutas)'),
  ('E2','CZ','Chaleira elétrica',5,null,'Chaleira elétrica'),
  ('E2','CZ','Colher pequena',24,null,'Colher pequena'),
  ('E2','CZ','Colher pequena de bebê',24,null,'Colher pequena de bebê'),
  ('E2','CZ','Copo descartável pequeno',24,'24 fardos','Copo descartável pequeno (fardo)'),
  ('E2','CZ','Faca de serrinha (adulto)',24,null,'Faca de serrinha (adulto)'),
  ('E2','CZ','Garfo (adulto)',24,null,'Garfo (adulto)'),
  ('E2','CZ','Guardanapo grande',500,'500 pacotes','Guardanapo grande (pacote)'),
  ('E2','CZ','Isqueiro',5,null,'Isqueiro'),
  ('E2','CZ','Panela de pressão 20 L',1,null,'Panela de pressão 20 L'),
  ('E2','CZ','Papel alumínio',10,'10 rolos','Papel alumínio (rolo)'),
  ('E2','CZ','Papel manteiga',10,'10 pacotes','Papel manteiga (pacote)'),
  ('E2','CZ','Pote retangular grande para frutas',5,null,'Pote retangular grande para frutas'),
  ('E2','CZ','Pote retangular médio para frutas',5,null,'Pote retangular médio para frutas'),
  ('E2','CZ','Pote plástico transparente com tampa G',5,null,'Pote plástico transparente com tampa G'),
  ('E2','CZ','Pote plástico transparente com tampa M',5,null,'Pote plástico transparente com tampa M'),
  ('E2','CZ','Prato fundo de vidro',48,null,'Prato fundo de vidro'),
  ('E2','CZ','Ralador (forte)',1,null,'Ralador (forte)'),
  ('E2','CZ','Térmica redonda 5 L com torneira (chá/suco)',1,'Para eventos — uma para cada escola','Térmica redonda 5 L com torneira (chá/suco)'),
  ('E2','CZ','Térmica para água ou café',2,null,'Térmica para água ou café'),
  ('E2','CZ','Xícara transparente lisa',100,null,'Xícara transparente lisa'),
  ('G','MB','Relógio de parede',12,null,'Relógio de parede')
),
numerados as (
  select l.*, row_number() over () as n from lista l
),
dados as (
  select
    n, p.id as solicitacao_id, u.id as unidade_id, qtd, obs, p.criado_em,
    pr.id as produto_id, pr.nome as item, pr.categoria as categoria_produto,
    case cat
      when 'LH' then 'limpeza_higiene' when 'ME' then 'material_expediente'
      when 'MP' then 'material_escolar_pedagogico' when 'TE' then 'tecnologia'
      when 'MI' then 'manutencao_infraestrutura'
      when 'CZ' then 'cozinha_utensilios' when 'MB' then 'mobiliario_equipamentos'
    end::categoria as categoria,
    case when pedido = 'G'
      -- lista recente: quase tudo ainda aguardando a Secretaria
      then (array['cadastrada','cadastrada','cadastrada','cadastrada','cadastrada',
                  'cadastrada','cadastrada','cadastrada','em_analise','em_analise'])[n % 10 + 1]
      -- demais: 20% cadastrada, 20% em análise, 15% adquirida, 15% entregue, 15% indisponível, 15% não atendida
      else (array['cadastrada','cadastrada','cadastrada','cadastrada','em_analise','em_analise','em_analise','em_analise',
                  'adquirida','adquirida','adquirida','entregue','entregue','entregue',
                  'indisponivel','indisponivel','indisponivel','nao_atendida','nao_atendida','nao_atendida'])[n % 20 + 1]
    end::status_item as status,
    -- a cada 4 itens comprados, 1 veio com quantidade reduzida
    case when n % 4 = 0 then greatest(1, qtd / 2) else qtd end as qtd_comprada
  from numerados
  join pedidos p on p.codigo = pedido
  join produtos pr on pr.nome_busca = lower(extensions.unaccent(produto))
  join solicitacoes s on s.id = p.id
  join unidades u on u.id = s.unidade_id
)
insert into itens (
  solicitacao_id, unidade_id, produto_id, categoria, item, item_busca, quantidade, observacoes, status,
  justificativa, quantidade_adquirida, previsao_entrega, criado_em, atualizado_em
)
select
  solicitacao_id, unidade_id, produto_id, categoria_produto, item, lower(extensions.unaccent(item)), qtd, obs, status,
  case
    when status = 'indisponivel' then 'Item sem fornecedor disponível no SimCatarina.'
    when status = 'nao_atendida' and n % 2 = 0 then 'Sem verba para este item neste trimestre.'
    when status = 'nao_atendida' then 'Considerado desnecessário: a escola recebeu este item no mês anterior.'
    when status in ('adquirida', 'entregue') and qtd_comprada <> qtd then 'Quantidade reduzida por falta de verba.'
  end,
  case when status in ('adquirida', 'entregue') then qtd_comprada end,
  case when status in ('adquirida', 'entregue') then (criado_em + interval '20 days')::date end,
  criado_em, criado_em
from dados
order by n;

-- Histórico coerente com o caminho de cada status (§5 da spec).
insert into historico (item_id, status, alterado_por_nome, alterado_em)
select i.id, e.status, e.quem, least(e.quando, now())
from itens i
cross join lateral (values
  ('cadastrada'::status_item, 'Gestor (teste)', i.criado_em, true),
  ('em_analise', 'Secretaria (teste)', i.criado_em + interval '1 day', i.status <> 'cadastrada'),
  ('adquirida', 'Secretaria (teste)', i.criado_em + interval '4 days', i.status in ('adquirida', 'entregue')),
  (i.status, 'Secretaria (teste)', i.criado_em + interval '4 days', i.status in ('indisponivel', 'nao_atendida')),
  ('entregue', 'Secretaria (teste)', i.criado_em + interval '12 days', i.status = 'entregue')
) as e (status, quem, quando, incluir)
where e.incluir
order by i.id, e.quando;

update itens i
set atualizado_em = (select max(alterado_em) from historico h where h.item_id = i.id);

-- Um terço dos itens já analisados aparece como "atualizado" para o gestor.
insert into novidades (item_id)
select id from itens where status <> 'cadastrada' and id % 3 = 0;

alter table itens enable trigger user;

commit;

-- Para limpar e rodar de novo (só no banco de teste):
--   truncate solicitacoes restart identity cascade;
