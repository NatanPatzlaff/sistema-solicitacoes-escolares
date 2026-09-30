-- DADOS DE TESTE — nunca rodar no projeto de produção.
-- Itens reais das listas enviadas pelas escolas (Cinderela, EEICM, Grupo Escolar Paulo Freire).
-- Cada lista vira uma solicitação; status, datas e histórico dos itens são fictícios,
-- para testar filtros, busca, paginação, cards e ações em lote.
-- Uso: depois do schema.sql, num banco SEM solicitações (SQL Editor do projeto de teste, ou local).
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
  ('Pré Escolar Cinderela'),
  ('Creche Municipal'),
  ('Grupo Escolar Paulo Freire'),
  ('Marcolino Pedroso')
on conflict (nome) do nothing;

create temp table pedidos (codigo text, escola text, observacoes text, criado_em timestamptz, id bigint) on commit drop;
insert into pedidos values
  ('E1', 'Creche Municipal', 'Pedido de material pedagógico — setembro de 2026.', '2026-09-03 14:00-03', null),
  ('E2', 'Creche Municipal', 'Pedidos gerais de cozinha e limpeza.', '2026-09-03 14:20-03', null),
  ('C',  'Pré Escolar Cinderela', null, '2026-09-22 09:15-03', null),
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

with lista (pedido, cat, item, qtd, obs) as (values
  -- Cinderela — material de limpeza (lista manuscrita)
  ('C','LH','Água sanitária',20,null),
  ('C','LH','Álcool líquido',4,'4 caixas'),
  ('C','LH','Desinfetante',15,null),
  ('C','LH','Sabonete líquido',5,null),
  ('C','LH','Bom Ar (aromatizador)',3,'3 caixas'),
  ('C','LH','Cera líquida',3,'3 caixas'),
  ('C','LH','Luva de procedimento P',4,'4 caixas'),
  ('C','LH','Luva de procedimento M',4,'4 caixas'),
  ('C','LH','Detergente Girando Sol',6,'6 caixas'),
  ('C','LH','Esponja verde/amarela',30,null),
  ('C','LH','Saco de lixo 15 L',5,'5 fardos'),
  ('C','LH','Saco de lixo 50 L',6,'6 fardos'),
  ('C','LH','Saco de lixo 100 L',5,'5 fardos'),
  ('C','LH','Saponáceo cremoso',3,'3 caixas'),
  ('C','LH','Touca descartável',4,'4 pacotes'),
  ('C','LH','Desengraxante',10,null),
  ('C','LH','Limpador multiuso limpeza pesada com cloro (tira-limo)',3,'3 caixas — tipo Veja'),
  ('C','LH','Limpador multiuso limpeza diária',3,'3 caixas'),
  ('C','LH','Pano de chão',8,null),
  ('C','LH','Amaciante',10,null),
  ('C','LH','Escova de vaso sanitário',6,null),
  ('C','LH','Papel toalha',150,'150 fardos'),
  ('C','LH','Papel higiênico',100,'100 fardos'),

  -- EEICM — material pedagógico (setembro/2026)
  ('E1','ME','Alfinete colorido',3,'3 caixas'),
  ('E1','MP','Algodão',20,'20 pacotes'),
  ('E1','MP','Argola plástica média',30,null),
  ('E1','MP','Argola plástica pequena',30,null),
  ('E1','MP','Balão tamanho 9',5,'5 pacotes de cada cor'),
  ('E1','MP','Barbante cru',8,'8 rolos'),
  ('E1','MP','Bastão de cola quente grande',5,'5 pacotes'),
  ('E1','MP','Bastão de cola quente pequeno',2,'2 pacotes'),
  ('E1','MP','Bobina de papel kraft 60x50',1,'1 rolo'),
  ('E1','MP','Borracha',1,'1 caixinha'),
  ('E1','MP','Caderno pequeno capa dura 96 folhas azul',20,null),
  ('E1','TE','Caixa de som para sala',5,null),
  ('E1','ME','Canetão para quadro branco',10,'10 de cada cor: azul, vermelho, preto e verde'),
  ('E1','ME','Caneta esferográfica',1,'1 caixinha de cada cor: preta, azul e vermelha'),
  ('E1','ME','Canetinha marcador para retroprojetor',20,'20 de cada cor: preta, azul, vermelha e verde'),
  ('E1','MP','Canetinha colorida',10,null),
  ('E1','MP','Canudo grande (grosso)',3,'3 pacotes'),
  ('E1','MP','Canudo médio (grosso)',5,'5 pacotes'),
  ('E1','ME','Capa plástica transparente para encadernar',200,null),
  ('E1','MP','Carrinho de bebê (brinquedo)',5,null),
  ('E1','MP','Cilindro plástico vazado',40,null),
  ('E1','ME','Clipe tamanho G',1,'1 caixa'),
  ('E1','ME','Clipe tamanho M',1,'1 caixa'),
  ('E1','ME','Clipe tamanho P',1,'1 caixa'),
  ('E1','MP','Cola branca pequena',20,null),
  ('E1','ME','Cola de alto contato (Tec Bond)',20,null),
  ('E1','MP','Cola alto-relevo',5,'5 de cada cor'),
  ('E1','MP','Cola glitter sortida',2,'2 de cada cor'),
  ('E1','MP','Utensílios de cozinha de brinquedo em madeira natural',5,'5 coleções'),
  ('E1','MP','Corante alimentício em gota amarelo',10,null),
  ('E1','MP','Corante alimentício em gota azul',10,null),
  ('E1','MP','Corante alimentício em gota rosa',10,null),
  ('E1','MP','Corante alimentício em gota roxo',10,null),
  ('E1','MP','Corante alimentício em gota verde',10,null),
  ('E1','MP','Corante alimentício em gota vermelho',10,null),
  ('E1','MP','Corda (professora de movimento)',50,'50 metros'),
  ('E1','MP','Corda de varal (ambientar salas)',1,'1 rolo'),
  ('E1','ME','Corretivo',5,null),
  ('E1','LH','Cotonete',20,'20 caixas com 100 unidades'),
  ('E1','ME','Elástico de borracha',5,null),
  ('E1','ME','Espiral para encadernar 17 mm',150,null),
  ('E1','ME','Estilete grande',5,null),
  ('E1','MP','Fio de náilon 0,50 mm',5,null),
  ('E1','MP','Fita crepe colorida 2 cm',5,null),
  ('E1','ME','Fita crepe grande',10,null),
  ('E1','ME','Fita crepe pequena',10,null),
  ('E1','ME','Fita isolante colorida',5,null),
  ('E1','ME','Fita adesiva marrom',30,'Boa qualidade'),
  ('E1','MP','Fita mimosa 7 mm',2,'2 rolos de cada cor'),
  ('E1','MP','Fita mimosa 10 mm',2,'2 rolos de cada cor'),
  ('E1','MP','Fita mimosa 14 mm',2,'2 rolos de cada cor'),
  ('E1','ME','Fita transparente larga',20,null),
  ('E1','ME','Fita transparente média',20,null),
  ('E1','ME','Fita transparente estreita',14,null),
  ('E1','MP','Folha dura 120 g',100,'100 pacotes'),
  ('E1','MP','Folha dura 180 g',20,'20 pacotes'),
  ('E1','ME','Folha para plastificar',40,'40 pacotes'),
  ('E1','MP','Giz de cera grosso',20,'20 caixinhas'),
  ('E1','ME','Giz de quadro colorido',20,'20 caixinhas'),
  ('E1','ME','Grampeador de escritório',5,null),
  ('E1','MP','Prendedor de roupa',20,'20 pacotes com 12'),
  ('E1','ME','Grampo para grampeador de madeira',1,'Tamanhos diversos'),
  ('E1','MP','Haste de chenille',40,null),
  ('E1','MP','Kit 10 agulhas plásticas de tapeceiro 7 cm',1,null),
  ('E1','MP','Kit 10 cestas pãozeiras de bambu 33x25x12',1,null),
  ('E1','MP','Kit 30 pinças plásticas de coordenação motora',2,'2 conjuntos'),
  ('E1','MP','Kit panelinhas infantis de madeira (11 peças)',5,null),
  ('E1','MP','Lápis preto',1,'1 caixinha'),
  ('E1','MP','Lápis de cor',20,'20 caixinhas'),
  ('E1','MP','Língua de sogra',30,null),
  ('E1','LH','Luva de procedimento G',80,'80 caixas'),
  ('E1','LH','Luva de procedimento M',200,'200 caixas'),
  ('E1','LH','Luva de procedimento P',20,'20 caixas'),
  ('E1','ME','Marca-texto',16,'14 ou 16 unidades'),
  ('E1','MP','Massinha de modelar',40,null),
  ('E1','MP','Palito de churrasco grande',5,'5 pacotes'),
  ('E1','MP','Palito de churrasco médio',5,'5 pacotes'),
  ('E1','MP','Palito de picolé',10,'10 pacotes'),
  ('E1','MP','Papel alumínio grosso',10,'10 rolos'),
  ('E1','ME','Papel autoadesivo',30,'30 pacotes'),
  ('E1','ME','Papel fotográfico 120 g',400,'400 pacotes'),
  ('E1','ME','Papel fotográfico adesivo 120 g',50,'50 pacotes'),
  ('E1','MP','Papel kraft marrom 120 g',50,'50 pacotes'),
  ('E1','MP','Papel panamá',20,'20 folhas'),
  ('E1','MP','Papel pardo G',4,'4 rolos'),
  ('E1','ME','Papel ponto (bobina grande)',200,null),
  ('E1','ME','Pasta plástica',150,null),
  ('E1','ME','Perfurador de papel 1 furo',1,null),
  ('E1','ME','Pilha alcalina AA',20,'20 caixas com 10'),
  ('E1','ME','Pilha alcalina AAA',20,'20 caixas com 10'),
  ('E1','MP','Pistola de cola quente grande',8,null),
  ('E1','MP','Pistola de cola quente pequena',20,null),
  ('E1','MP','Papel celofane colorido',5,'5 pacotes'),
  ('E1','ME','Saco zip grande',5,null),
  ('E1','ME','Bloco adesivo (post-it) P, M e G',5,'5 de cada tamanho'),
  ('E1','MP','Prato de papelão cru G',2,'2 pacotes'),
  ('E1','MP','Prato de papelão cru M',2,'2 pacotes'),
  ('E1','MP','Prato de papelão cru P',2,'2 pacotes'),
  ('E1','MP','Spray colorido para cabelo',10,'10 de cada cor'),
  ('E1','MP','Tecido chita floral',1,'1 rolo'),
  ('E1','MP','Tecido chita',1,'1 rolo'),
  ('E1','MP','Tecido oxford amarelo',1,'1 rolo'),
  ('E1','MP','Tecido oxford azul',1,'1 rolo'),
  ('E1','MP','Tecido oxford branco',1,'1 rolo'),
  ('E1','MP','Tecido oxford laranja',1,'1 rolo'),
  ('E1','MP','Tecido oxford preto',1,'1 rolo'),
  ('E1','MP','Tecido oxford rosa',1,'1 rolo'),
  ('E1','MP','Tecido oxford roxo',1,'1 rolo'),
  ('E1','MP','Tecido oxford vermelho',1,'1 rolo'),
  ('E1','MP','Tecido para lençol infantil',1,'1 rolo'),
  ('E1','MP','Tecido tule amarelo',1,'1 rolo'),
  ('E1','MP','Tecido tule azul',1,'1 rolo'),
  ('E1','MP','Tecido tule bege',1,'1 rolo'),
  ('E1','MP','Tecido tule branco',2,'Aparece 2 vezes na lista (1 rolo cada)'),
  ('E1','MP','Tecido tule laranja',1,'1 rolo'),
  ('E1','MP','Tecido tule preto',1,'1 rolo'),
  ('E1','MP','Tecido tule rosa',2,'Aparece 2 vezes na lista (1 rolo cada)'),
  ('E1','MP','Tecido tule roxo',1,'1 rolo'),
  ('E1','MP','Tecido tule vermelho',1,'1 rolo'),
  ('E1','MP','Tecido voal bege',1,'1 rolo'),
  ('E1','MP','Tecido voal branco',1,'1 rolo'),
  ('E1','MP','Tecido voal preto',1,'1 rolo'),
  ('E1','MP','Tecido xadrez',1,'1 rolo'),
  ('E1','MP','Tesoura escolar sem ponta 13 cm',30,null),
  ('E1','ME','Tesoura multiuso de escritório inox 21 cm',10,null),
  ('E1','ME','Tinta para impressora Canon GI-10 ciano',10,null),
  ('E1','ME','Tinta para impressora Canon GI-10 magenta',10,null),
  ('E1','ME','Tinta para impressora Canon GI-10 preta',40,null),
  ('E1','ME','Tinta para impressora Canon GI-10 amarela',10,null),
  ('E1','ME','Tinta para impressora Epson L3250 preta',10,null),
  ('E1','ME','Tinta para impressora Epson L3250 ciano',3,null),
  ('E1','ME','Tinta para impressora Epson L3250 magenta',3,null),
  ('E1','ME','Tinta para impressora Epson L3250 amarela',3,null),
  ('E1','ME','Vinil adesivo transparente A4 (etiqueta para mamadeiras)',2,'2 pacotes — resistente a água e micro-ondas'),
  ('E1','MP','Zíper dentado 20 cm',10,null),
  ('E1','MP','Zíper dentado 30 cm',10,null),

  -- EEICM — cozinha e limpeza (só o que cabe nas categorias atuais)
  ('E2','LH','Água sanitária 5 L',100,null),
  ('E2','LH','Álcool em gel 70%',1,'1 caixa com 24'),
  ('E2','LH','Álcool líquido 70%',30,'30 caixas com 12'),
  ('E2','LH','Álcool líquido 90%',10,'10 caixas com 12'),
  ('E2','LH','Amaciante 5 L',50,null),
  ('E2','LH','Bom Ar (aromatizador)',100,null),
  ('E2','LH','Pano para vassoura (bruxa) 81x14 cm',3,null),
  ('E2','LH','Desengraxante 500 mL',50,null),
  ('E2','LH','Desinfetante 5 L',200,null),
  ('E2','LH','Detergente',16,'16 caixas com 24'),
  ('E2','LH','Escova de vaso sanitário',10,null),
  ('E2','LH','Esponja de aço inox',50,null),
  ('E2','LH','Esponja dupla face grande',20,null),
  ('E2','LH','Esponja lava-louças',380,null),
  ('E2','LH','Lixeira com tampa e pedal 30 L',5,null),
  ('E2','LH','Lixeira com tampa 50 L',4,null),
  ('E2','LH','Multiuso limpeza pesada 500 mL',200,null),
  ('E2','LH','Pano de chão G',10,'10 fardos com 10'),
  ('E2','LH','Pano de prato G 1x1 m',20,null),
  ('E2','LH','Pano mágico de limpeza grande',20,null),
  ('E2','LH','Pano mágico de limpeza pequeno',30,null),
  ('E2','LH','Papel higiênico (fardo com 26 rolos)',400,'400 fardos'),
  ('E2','LH','Papel toalha 1000 folhas',800,'800 pacotes'),
  ('E2','LH','Rodo grande de plástico 80 cm',10,null),
  ('E2','LH','Rodo pequeno de plástico',5,null),
  ('E2','LH','Sabonete líquido 5 L',100,null),
  ('E2','LH','Saco de lixo preto 100 L',200,'200 rolos com 100'),
  ('E2','LH','Saco de lixo preto 50 L',200,'200 rolos com 100'),
  ('E2','LH','Saco de lixo azul 50 L',100,'100 rolos com 100'),
  ('E2','LH','Saponáceo cremoso',10,'10 caixas com 12'),
  ('E2','LH','Touca descartável',2,'2 pacotes com 100'),
  ('E2','LH','Vassoura de palha',10,null),
  ('E2','LH','Vassoura de plástico',10,null),
  ('E2','MI','Torneira elétrica de bancada (Zagonel)',5,null),
  ('E2','MI','Torneira plástica branca para banheiro',12,null),
  ('E2','MI','Torneira plástica preta',10,null),

  -- Grupo Escolar Paulo Freire — materiais escolares (2027)
  ('G','ME','Adesivo instantâneo',8,null),
  ('G','ME','Apagador de quadro branco',12,null),
  ('G','MP','Apontador com depósito',250,null),
  ('G','MP','Argila',6,null),
  ('G','MP','Balões de cores diversas',3,'3 pacotes de cada cor'),
  ('G','MP','Barbante cru fio grosso nº 6',3,null),
  ('G','MP','Bastão de cola quente grosso',1,'1 pacote'),
  ('G','MP','Borracha',250,null),
  ('G','MP','Caderno de caligrafia capa dura',200,null),
  ('G','MP','Caderno de desenho grande capa dura 48 folhas',250,null),
  ('G','MP','Caderno espiral universitário capa dura 96 folhas',600,null),
  ('G','MP','Caderno pequeno capa dura 48 folhas',300,null),
  ('G','MP','Giz de cera 12 cores',20,'20 caixas'),
  ('G','ME','Caneta azul',1,'1 caixa'),
  ('G','ME','Canetinha para retroprojetor 2.0',3,'3 caixas de cada cor'),
  ('G','ME','Capa para encadernação preta fosca',1,'1 resma'),
  ('G','MP','Cartolina amarela',100,null),
  ('G','ME','Clipe nº 2',10,null),
  ('G','ME','Clipe nº 4',4,null),
  ('G','ME','Clipe nº 6',4,null),
  ('G','MP','Cola escolar',280,null),
  ('G','MP','Colete infantojuvenil',15,null),
  ('G','ME','Espiral para encadernação 9 mm',2,'2 pacotes'),
  ('G','ME','Espiral para encadernação 14 mm',4,'4 pacotes'),
  ('G','MP','Estojo de canetinha ponta fina',5,'5 caixas com 12'),
  ('G','MP','Estojo de canetinha ponta grossa',20,null),
  ('G','ME','Etiqueta adesiva',2,'2 caixas'),
  ('G','MP','EVA preto',40,null),
  ('G','MP','EVA com brilho',20,'10 vermelho e 10 pink'),
  ('G','ME','Fita adesiva 3M',25,null),
  ('G','ME','Fita crepe branca 2,5 cm',10,null),
  ('G','ME','Fita transparente larga 4 cm',30,null),
  ('G','ME','Fita transparente 2,5 cm',15,null),
  ('G','MP','Fita mimosa estreita nº 1',1,'1 de cada cor'),
  ('G','MP','Fita mimosa média',4,'4 de cada cor'),
  ('G','ME','Papel A4 120 g',50,'50 pacotes'),
  ('G','ME','Papel A4 180 g',30,'30 pacotes'),
  ('G','ME','Papel A4 colorido (azul, verde, amarelo, rosa)',3,'3 resmas de cada cor (500 folhas)'),
  ('G','ME','Papel A4 sulfite',60,'60 caixas'),
  ('G','ME','Papel A4 reciclado',20,'20 resmas'),
  ('G','MP','Placa de isopor',12,null),
  ('G','ME','Giz de quadro colorido',30,'30 caixas'),
  ('G','ME','Grampeador',5,null),
  ('G','ME','Grampo 26/6',5,'5 caixas'),
  ('G','MP','Prendedor de roupa',30,'30 pacotes'),
  ('G','MP','Lápis de cor',250,null),
  ('G','MP','Lápis preto',5,'5 caixas'),
  ('G','ME','Livro ata',1,null),
  ('G','ME','Marcador de quadro branco',50,'50 de cada cor'),
  ('G','MP','Massa de EVA sortida',10,null),
  ('G','MP','Massa de modelar',150,null),
  ('G','MP','Palito de algodão-doce',2,'2 pacotes'),
  ('G','MP','Palito de churrasco',5,'5 pacotinhos'),
  ('G','MP','Palito de picolé',20,'20 pacotes com 100'),
  ('G','ME','Papel adesivo Contact 80 micras',5,null),
  ('G','MP','Papel kraft',1,'1 rolo'),
  ('G','MP','Papel dupla face',10,'10 de cada cor'),
  ('G','MP','Papel duplex',10,'10 de cada cor'),
  ('G','ME','Papel fotográfico',5,'5 resmas'),
  ('G','ME','Papel fotográfico adesivo',5,'5 resmas'),
  ('G','ME','Pilha AAA',30,null),
  ('G','ME','Pilha AA',15,null),
  ('G','ME','Pincel atômico (canetão)',2,'2 caixas de cada cor'),
  ('G','ME','Pouch para plastificar',10,'10 resmas com 100 folhas'),
  ('G','ME','Refil de canetão de quadro branco',30,'30 de cada cor'),
  ('G','MP','Régua',250,null),
  ('G','MP','Rolinho de espuma',5,null),
  ('G','ME','Suporte para fita adesiva larga',3,null),
  ('G','ME','Tesoura de uso geral',10,null),
  ('G','MP','Tinta acrílica brilhante',1,'1 de cada cor'),
  ('G','MP','Tinta PVA',1,'1 de cada cor'),
  ('G','MP','Tinta para tecido',1,'1 de cada cor'),
  ('G','MP','Tinta facial',2,'2 pacotes'),
  ('G','ME','Tinta para impressora Canon 7010',15,'15 de cada cor'),
  ('G','MP','TNT',3,'1 laranja, 1 marrom, 1 lilás claro'),

  -- Itens que dependiam das categorias Cozinha e utensílios (CZ) e Mobiliário e equipamentos (MB)
  ('E1','MB','Cadeira de rodinha (escritório)',5,null),
  ('E1','MB','Caminha para sono',20,null),
  ('E1','MB','Mesinha para ambientar as salas',2,null),
  ('E1','MB','Tatame',1,'1 conjunto — repor os velhos'),
  ('E1','MB','Tenda gazebo dobrável 3x3 m azul',2,'Com proteção UV e impermeável'),
  ('E2','CZ','Amassador de batatas inox industrial (cabo grande)',1,null),
  ('E2','CZ','Bacia com tampa G',5,null),
  ('E2','CZ','Bacia com tampa M',5,null),
  ('E2','MB','Caixa plástica empilhável 52 L preta (brinquedos)',10,null),
  ('E2','CZ','Caixa plástica vazada 33 L preta (frutas)',12,null),
  ('E2','CZ','Chaleira elétrica',5,null),
  ('E2','CZ','Colher pequena',24,null),
  ('E2','CZ','Colher pequena de bebê',24,null),
  ('E2','CZ','Copo descartável pequeno',24,'24 fardos'),
  ('E2','CZ','Faca de serrinha (adulto)',24,null),
  ('E2','CZ','Garfo (adulto)',24,null),
  ('E2','CZ','Guardanapo grande',500,'500 pacotes'),
  ('E2','CZ','Isqueiro',5,null),
  ('E2','CZ','Panela de pressão 20 L',1,null),
  ('E2','CZ','Papel alumínio',10,'10 rolos'),
  ('E2','CZ','Papel manteiga',10,'10 pacotes'),
  ('E2','CZ','Pote retangular grande para frutas',5,null),
  ('E2','CZ','Pote retangular médio para frutas',5,null),
  ('E2','CZ','Pote plástico transparente com tampa G',5,null),
  ('E2','CZ','Pote plástico transparente com tampa M',5,null),
  ('E2','CZ','Prato fundo de vidro',48,null),
  ('E2','CZ','Ralador (forte)',1,null),
  ('E2','CZ','Térmica redonda 5 L com torneira (chá/suco)',1,'Para eventos — uma para cada escola'),
  ('E2','CZ','Térmica para água ou café',2,null),
  ('E2','CZ','Xícara transparente lisa',100,null),
  ('G','MB','Relógio de parede',12,null)
),
numerados as (
  select l.*, row_number() over () as n from lista l
),
dados as (
  select
    n, p.id as solicitacao_id, u.id as unidade_id, item, qtd, obs, p.criado_em,
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
  join solicitacoes s on s.id = p.id
  join unidades u on u.id = s.unidade_id
)
insert into itens (
  solicitacao_id, unidade_id, categoria, item, item_busca, quantidade, observacoes, status,
  justificativa, quantidade_adquirida, previsao_entrega, criado_em, atualizado_em
)
select
  solicitacao_id, unidade_id, categoria, item, lower(extensions.unaccent(item)), qtd, obs, status,
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
