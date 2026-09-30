# Especificação do sistema

> Fonte de verdade sobre o que deve ser construído. Itens **a confirmar** são provisórios.

## 1. Objetivo

Substituir pedidos informais (telefone, e-mail, papel) por um canal único em que as unidades escolares registram necessidades e a Secretaria Municipal de Educação analisa, atende e dá retorno, com histórico rastreável por unidade.

**Fluxo real (confirmado em 2026-09-30):** o gestor pede o que a escola precisa → alguém da Secretaria analisa e **compra manualmente no SimCatarina** (fora deste sistema) → registra aqui o resultado de cada item. Por falta de verba ou de necessidade, a Secretaria pode **alterar a quantidade** ou **negar** um item, sempre com justificativa, para o gestor saber o motivo.

## 2. Perfis de usuário

### Gestor da unidade escolar
- Cadastra solicitações **somente para a própria unidade**.
- Acompanha o status das solicitações da própria unidade.
- Consulta o histórico da própria unidade.
- Vê (sem editar) justificativa, quantidade adquirida e previsão de entrega registradas pela Secretaria.
- Não altera status. *(Exceção possível: cancelar ou confirmar entrega — ver §12.)*

### Secretaria
- Vê solicitações de **todas** as unidades.
- Filtra e busca (ver §7).
- Altera status conforme o ciclo de vida (§5).
- Registra justificativa, quantidade adquirida e previsão de entrega.
- Cria contas de gestores e da Secretaria pela tela **Contas** (nome, e-mail, perfil, escola, senha provisória). Pode cadastrar uma escola nova no mesmo formulário. *(Aprovado em 2026-09-28.)*
- Editar, desativar ou excluir contas: **fora da primeira versão** (feito no painel do Supabase se necessário).

## 3. Acesso e isolamento de dados

- Todo usuário pertence a um perfil. Todo gestor está vinculado a **exatamente uma** unidade escolar.
- O isolamento é garantido **no banco de dados** (regra por linha/unidade), não apenas na interface. Uma consulta de gestor nunca retorna dados de outra unidade, mesmo com a URL ou o ID alterados manualmente.
- A unidade da solicitação vem do vínculo do gestor logado, nunca de um campo editável do formulário.
- Autenticação: e-mail e senha. Cadastro público **desligado**: só a Secretaria cria contas (tela Contas → Edge Function `criar-conta`, que confere se quem chama é da Secretaria). A primeira conta da Secretaria é criada no painel do Supabase + `vincular_usuario()` (ver README.md).
- A chave `service_role` fica só na Edge Function, nunca no site.

## 4. Categorias

Lista fechada, idêntica em todas as telas:

1. Limpeza e higiene
2. Material de expediente
3. Material escolar e pedagógico
4. Tecnologia
5. Manutenção e infraestrutura — exemplos: **(a confirmar)**

Não criar subcategorias sem aprovação.

## 5. Ciclo de vida de cada item

Uma **solicitação** é um pedido com **um ou mais itens** (aprovado em 2026-09-30). O status é **de cada item**; a solicitação não tem status próprio, só um resumo dos itens (ex.: "12 itens · 5 adquiridos · 2 não atendidos").

```
Cadastrada → Em análise → Adquirida ──→ Entregue
                        ├→ Indisponível
                        └→ Não atendida
```

| De | Para | Quem altera |
|---|---|---|
| — | Cadastrada | Gestor (ao criar) |
| Cadastrada | Em análise | Secretaria |
| Em análise | Adquirida | Secretaria |
| Em análise | Indisponível | Secretaria |
| Em análise | Não atendida | Secretaria |
| Adquirida | Entregue | Secretaria **(a confirmar se o gestor confirma o recebimento)** |

Significado de cada status no fluxo real:

| Status | Significa |
|---|---|
| Cadastrada | O gestor pediu |
| Em análise | A Secretaria está avaliando / comprando |
| Adquirida | Comprado no SimCatarina (quantidade pode ser diferente da pedida) |
| Indisponível | Produto não disponível para compra |
| Não atendida | Negado (falta de verba ou considerado desnecessário) |
| Entregue | Chegou à escola |

- **Indisponível**, **Não atendida** e **Entregue** são estados finais.
- Nenhuma outra transição é permitida (sem voltar status, sem pular etapas) até decisão em contrário.
- Toda mudança de status registra quem mudou e quando (histórico visível para ambos os perfis).
- **Justificativa obrigatória** em *Indisponível*, *Não atendida* e sempre que a **quantidade adquirida for diferente da pedida**.
- A Secretaria atua **item por item** ou em **vários itens de uma vez** (todos ou os selecionados): mesmo status, uma justificativa comum, quantidade adquirida = pedida (ajustável item a item). A ação em lote é **tudo ou nada**: se um item não puder mudar, nada é salvo e o sistema diz qual item impediu.

## 6. Campos

### Solicitação (o pedido)

| Campo | Preenchido por | Obrigatório | Observação |
|---|---|---|---|
| Número | Sistema | Sim | Sequencial |
| Unidade escolar | Sistema | Sim | Vem do vínculo do gestor |
| Observações gerais | Gestor | Não | Texto livre |
| Data de cadastro | Sistema | Sim | Automático |

### Item da solicitação

| Campo | Preenchido por | Obrigatório | Observação |
|---|---|---|---|
| Categoria | Gestor | Sim | Lista do §4 (por item: as listas misturam categorias) |
| Item | Gestor | Sim | Texto livre, curto. A embalagem, quando houver, vai no texto (ex.: "Luva M — caixa"); não há campo de unidade |
| Quantidade | Gestor | Sim | Inteiro > 0 |
| Observações | Gestor | Não | Texto livre |
| Status | Sistema / Secretaria | Sim | Ver §5 |
| Justificativa | Secretaria | Ver §5 | Motivo de alteração ou negativa |
| Quantidade adquirida | Secretaria | Sim ao marcar *Adquirida* | Inteiro ≥ 0; pode ser diferente da pedida (com justificativa) |
| Previsão de entrega | Secretaria | Não | Data |
| Data de cada mudança | Sistema | Sim | Automático (histórico) |

## 7. Filtros e busca

A lista principal mostra **solicitações** (escola, data, nº de itens, resumo por status). Filtros combináveis:
- Escola (só Secretaria)
- Período (data de cadastro: de / até)
- Categoria, status e nome do item — mostram as solicitações que têm **algum item** assim (busca sem diferenciar maiúsculas/acentos)

O gestor tem os mesmos filtros, **exceto escola**, restritos à própria unidade.

## 8. Notificações

- Primeira versão: sinal de novidade dentro do sistema quando o status de uma solicitação do gestor muda. **(a confirmar)**
- E-mail: fora da primeira versão, salvo decisão em contrário.

## 9. Stack técnica (aprovada em 2026-09-24)

**Restrição: custo zero.** Nenhum serviço pago, nem domínio próprio.

- **Interface:** React + Vite + TypeScript, site estático (sem servidor próprio).
- **Banco, login e isolamento:** Supabase (plano gratuito): PostgreSQL, Auth e Row Level Security para o isolamento por unidade.
- **Criação de contas:** uma Edge Function do Supabase (`criar-conta`, plano gratuito), única parte que roda em servidor.
- **Hospedagem:** Cloudflare Pages (plano gratuito; permite uso comercial/institucional). Endereço `*.pages.dev`.
- **Código:** GitHub, repositório **privado** `NatanPatzlaff/sistema-solicitacoes-escolares`.
- **Manutenção automática (GitHub Actions, repositório privado):**
  - Consulta diária ao Supabase para impedir a pausa após 7 dias sem uso.
  - Backup semanal do banco (`pg_dump`) guardado como artefato privado do GitHub.
  - Criar os dois quando o projeto Supabase existir, pois dependem das chaves dele.

Limites do plano gratuito do Supabase a respeitar: 500 MB de banco, e-mails de autenticação limitados por hora (só para recuperação de senha, nunca para notificações).

Não trocar sem autorização (ver CLAUDE.md).

## 10. Requisitos não funcionais

### Responsividade
- Três alvos: **desktop** (uso principal da Secretaria), **tablet** (uso frequente dos gestores nas escolas) e **celular** (consulta e cadastro rápido).
- Todas as funcionalidades devem estar disponíveis nos três; nada exclusivo de desktop.
- Detalhes visuais em @specs/design.md.

### Acessibilidade
- WCAG 2.1 nível AA.
- Navegação completa por teclado, com foco visível.
- Status nunca informado apenas por cor (sempre texto + ícone).
- Formulários com rótulos explícitos e mensagens de erro ligadas ao campo.
- Áreas de toque de no mínimo 44×44 px.

### Desempenho
- Listagens paginadas no servidor; filtros executados no banco.
- Primeira carga útil em até ~2,5 s em conexão 4G comum.
- Listagem filtrada da Secretaria responde em até ~1 s com o volume esperado.
- Volume esperado: **5 unidades escolares** (cidade pequena), lançamentos manuais e esporádicos. Nº de gestores por unidade: **(a confirmar)**.

## 11. Escopo

### Dentro (primeira versão)
- Login e perfis (gestor / Secretaria)
- Cadastro e acompanhamento de solicitações pelo gestor
- Painel da Secretaria com filtros, busca e mudança de status
- Registro de justificativa, quantidade adquirida e previsão de entrega
- Histórico de mudanças por solicitação
- Aviso de mudança de status dentro do sistema **(a confirmar)**

### Fora (primeira versão)
- Relatórios, gráficos e exportação (PDF/planilha)
- Notificação por e-mail/WhatsApp
- Controle de estoque, compras, licitações ou orçamento
- Anexos/fotos nas solicitações **(avaliar depois — útil para manutenção)**
- Aplicativo nativo

## 12. A definir

- **Categorias para cozinha e mobiliário/equipamentos** — hoje não há onde encaixar (§4).
- "Colar lista" no cadastro (uma linha por item) para não digitar listas longas.
- Gestores por unidade e usuários da Secretaria
- Notificações: formato definitivo (§8)
- Exemplos da categoria Manutenção e infraestrutura (§4)
- Gestor pode editar/cancelar solicitação em *Cadastrada*?
- Quem confirma *Entregue*: Secretaria ou gestor?
- Prazo e prioridades da primeira entrega
