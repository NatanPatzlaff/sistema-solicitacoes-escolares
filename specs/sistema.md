# Especificação do sistema

> Fonte de verdade sobre o que deve ser construído. Itens **a confirmar** são provisórios.

## 1. Objetivo

Substituir pedidos informais (telefone, e-mail, papel) por um canal único em que as unidades escolares registram necessidades e a Secretaria Municipal de Educação analisa, atende e dá retorno, com histórico rastreável por unidade.

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
- Gerencia unidades escolares e contas de gestores. **(a confirmar)**

## 3. Acesso e isolamento de dados

- Todo usuário pertence a um perfil. Todo gestor está vinculado a **exatamente uma** unidade escolar.
- O isolamento é garantido **no banco de dados** (regra por linha/unidade), não apenas na interface. Uma consulta de gestor nunca retorna dados de outra unidade, mesmo com a URL ou o ID alterados manualmente.
- A unidade da solicitação vem do vínculo do gestor logado, nunca de um campo editável do formulário.
- Autenticação: e-mail e senha, com contas criadas pela Secretaria. **(a confirmar)**

## 4. Categorias

Lista fechada, idêntica em todas as telas:

1. Limpeza e higiene
2. Material de expediente
3. Material escolar e pedagógico
4. Tecnologia
5. Manutenção e infraestrutura — exemplos: **(a confirmar)**

Não criar subcategorias sem aprovação.

## 5. Ciclo de vida da solicitação

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

- **Indisponível**, **Não atendida** e **Entregue** são estados finais.
- Nenhuma outra transição é permitida (sem voltar status, sem pular etapas) até decisão em contrário.
- Toda mudança de status registra quem mudou e quando (histórico visível para ambos os perfis).

## 6. Campos da solicitação

| Campo | Preenchido por | Obrigatório | Observação |
|---|---|---|---|
| Unidade escolar | Sistema | Sim | Vem do vínculo do gestor |
| Categoria | Gestor | Sim | Lista do §4 |
| Item | Gestor | Sim | Texto livre, curto |
| Quantidade | Gestor | Sim | Inteiro > 0 |
| Observações | Gestor | Não | Texto livre |
| Status | Sistema / Secretaria | Sim | Ver §5 |
| Justificativa | Secretaria | Obrigatória em *Indisponível* e *Não atendida* **(a confirmar)** | |
| Quantidade adquirida | Secretaria | Sim ao marcar *Adquirida* | Inteiro ≥ 0; pode ser menor que a solicitada |
| Previsão de entrega | Secretaria | Não | Data |
| Data de cadastro / de cada mudança | Sistema | Sim | Automático |

## 7. Filtros e busca (Secretaria)

Combináveis entre si:
- Escola
- Categoria
- Período (data de cadastro: de / até)
- Status
- Nome do item (busca por texto, sem diferenciar maiúsculas/acentos)

O gestor tem os mesmos filtros, **exceto escola**, restritos à própria unidade.

## 8. Notificações

- Primeira versão: sinal de novidade dentro do sistema quando o status de uma solicitação do gestor muda. **(a confirmar)**
- E-mail: fora da primeira versão, salvo decisão em contrário.

## 9. Stack técnica (aprovada em 2026-09-24)

**Restrição: custo zero.** Nenhum serviço pago, nem domínio próprio.

- **Interface:** React + Vite + TypeScript, site estático (sem servidor próprio).
- **Banco, login e isolamento:** Supabase (plano gratuito): PostgreSQL, Auth e Row Level Security para o isolamento por unidade.
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

- Método de autenticação e quem cria as contas (§3)
- Gestores por unidade e usuários da Secretaria
- Notificações: formato definitivo (§8)
- Exemplos da categoria Manutenção e infraestrutura (§4)
- Gestor pode editar/cancelar solicitação em *Cadastrada*?
- Quem confirma *Entregue*: Secretaria ou gestor?
- Justificativa obrigatória em *Indisponível* / *Não atendida*?
- Prazo e prioridades da primeira entrega
