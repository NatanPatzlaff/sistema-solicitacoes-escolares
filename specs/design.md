# Design

> Fonte de verdade visual. Não há identidade oficial da prefeitura/Secretaria; esta identidade é original e pertence ao sistema. Pedido do usuário: base clean com detalhes em dourado, amarelo e vermelho.

## 1. Direção visual

**Painel administrativo claro, denso em dados, com acentos institucionais quentes.**

- Base branca e cinza frio: a informação (tabelas, status) é a protagonista.
- Dourado, amarelo e vermelho aparecem como **detalhe**, nunca como fundo de grandes áreas.
- **Elemento marcante (único):** a *faixa institucional*, uma linha fina tricolor (dourado · amarelo · vermelho) no topo do cabeçalho, que remete a faixas de bandeira municipal. Não repetir esse recurso em outros lugares.
- Tom: sério, direto, de serviço público. Sem ilustrações decorativas.

## 2. Paleta

### Marca (detalhes)

| Token | Hex | Uso |
|---|---|---|
| `ouro` | `#B8892B` | Faixa institucional, indicador de item ativo no menu, ícones de destaque. Não usar em texto pequeno. |
| `ouro-texto` | `#8A6516` | Texto/links em tom dourado (contraste AA em branco) |
| `amarelo` | `#F2C230` | Faixa institucional, sublinhado do foco em abas, destaque de linha nova |
| `carmim` | `#A3192A` | Faixa institucional, marca/logotipo, ações destrutivas |
| `carmim-escuro` | `#7E1220` | Hover de ações destrutivas |

### Neutros (estrutura)

| Token | Hex | Uso |
|---|---|---|
| `fundo` | `#F6F7F9` | Fundo da aplicação |
| `superficie` | `#FFFFFF` | Tabelas, formulários, painéis |
| `borda` | `#DDE1E7` | Bordas e divisores |
| `texto` | `#1E2530` | Texto principal e botão primário |
| `texto-suave` | `#5B6472` | Texto secundário, rótulos |
| `desabilitado` | `#A4ABB6` | Elementos desabilitados |

**Botão primário** usa `texto` (grafite) com texto branco, e não uma cor da marca, para não competir com os status e manter a sobriedade.

### Status (fixos: mesmas cores nas telas do gestor e da Secretaria)

| Status | Texto | Fundo | Ícone |
|---|---|---|---|
| Cadastrada | `#475467` | `#EEF1F5` | círculo vazio |
| Em análise | `#8A5A00` | `#FEF3C7` | relógio |
| Adquirida | `#1D4ED8` | `#DBEAFE` | sacola/caixa |
| Entregue (sucesso) | `#166534` | `#DCFCE7` | check |
| Indisponível | `#5B4B8A` | `#EDE9FE` | traço/proibido |
| Não atendida | `#B42318` | `#FEE4E2` | X |

Todos os pares atingem contraste ≥ 4,5:1. Status sempre com **texto + ícone**, nunca só cor.

Feedback de sistema: sucesso = verde de *Entregue*; erro = vermelho de *Não atendida*; aviso = amarelo de *Em análise*.

## 3. Tipografia

- Família única: **Public Sans** (Google Fonts, livre; feita para serviço público). Fallback: `system-ui, sans-serif`.
- Números em tabelas: `font-variant-numeric: tabular-nums`.
- Sem caixa alta em rótulos; usar sentence case.

| Nível | Tamanho / altura de linha | Peso |
|---|---|---|
| Título de página | 24 / 32 px | 600 |
| Título de seção | 18 / 26 px | 600 |
| Corpo | 16 / 24 px | 400 |
| Tabela e formulários (desktop) | 14 / 20 px | 400 (cabeçalho 600) |
| Legenda / apoio | 13 / 18 px | 400 |
| Badge | 13 / 16 px | 500 |

## 4. Espaçamento, bordas e raios

- Escala de espaçamento (base 4): 4, 8, 12, 16, 24, 32, 48.
- Bordas: 1 px `borda`. Sombra só em elementos flutuantes (menus, modais): `0 4px 16px rgba(30,37,48,.12)`.
- Raios com hierarquia:
  - 4 px: campos, botões, células
  - 8 px: painéis e modais
  - 999 px: badges de status e categoria

## 5. Componentes

### Botões
- Primário: fundo `texto`, texto branco. Hover: fundo `#323B48`.
- Secundário: fundo branco, borda `borda`, texto `texto`.
- Destrutivo: fundo `carmim`, texto branco.
- Altura 40 px (desktop) / 44 px (toque). O rótulo diz a ação ("Cadastrar solicitação", "Salvar status").
- Foco: contorno de 2 px `ouro-texto` com 2 px de afastamento.

### Tabelas (principal tela da Secretaria)
- Fundo branco, cabeçalho fixo ao rolar, linhas de 48 px, divisores horizontais apenas.
- Hover da linha: `fundo`. Linha com novidade (mudança recente): borda esquerda de 3 px `amarelo`.
- Colunas: escola · categoria · item · qtd · status · atualizado em. Números alinhados à direita.

### Filtros
- Barra horizontal acima da tabela: selects de escola, categoria e status, intervalo de datas e busca por item.
- Filtros ativos aparecem como chips removíveis, com "Limpar filtros" ao final.
- No tablet/celular, a barra vira botão "Filtros" que abre um painel lateral.

### Cards de status (resumo no topo do painel)
- Um card por status, com contagem e nome; clicar aplica o filtro.
- Card branco com borda; apenas uma barra superior de 3 px na cor do status. Sem gradientes.

### Badges
- **Status:** pílula com fundo e texto do status + ícone, conforme §2.
- **Categoria:** pílula neutra (borda `borda`, texto `texto-suave`), sem cor própria, para não disputar atenção com o status.

## 6. Movimento

- Mínimo e funcional: transições de 150 ms em hover/foco, abertura de painel lateral e modal (200 ms).
- Mudança de status confirmada: o badge faz uma transição de cor única.
- Sem animações de entrada de página. Respeitar `prefers-reduced-motion`.

## 7. Desktop, tablet e celular

| Faixa | Layout |
|---|---|
| ≥ 1200 px (desktop) | Menu lateral fixo, tabela completa, filtros em linha |
| 768–1199 px (tablet) | Menu recolhível, tabela com colunas secundárias ocultas, filtros em painel. Alvos de toque de 44 px. Funcionar em retrato e paisagem. |
| < 768 px (celular) | Tabela vira lista de cartões (item, status, categoria, data); ação principal fixa no rodapé |

## 8. Evitar

- Grandes áreas de dourado, amarelo ou vermelho; gradientes; brilhos "metálicos" no dourado.
- Vermelho da marca (`carmim`) parecendo status: não usar carmim em badges.
- Cor como único indicador de status.
- Brasões, símbolos oficiais ou identidade de terceiros.
- Rótulos em caixa alta, ícones decorativos, ilustrações genéricas.
- Cards idênticos para tudo; sombra em todo elemento.
- Texto em `ouro` ou `amarelo` sobre branco (contraste insuficiente).
