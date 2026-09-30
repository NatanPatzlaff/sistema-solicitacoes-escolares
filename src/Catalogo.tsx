import { useEffect, useState, type FormEvent } from 'react'
import { CATEGORIAS, mensagemErro, normalizar, supabase, type Categoria, type Produto } from './dominio'
import { BadgeCategoria, Erro } from './ui'

type Avulso = { item: string; categoria: Categoria; vezes: number }

export function Catalogo() {
  const [produtos, setProdutos] = useState<Produto[]>([])
  const [avulsos, setAvulsos] = useState<Avulso[]>([])
  const [busca, setBusca] = useState('')
  const [filtroCategoria, setFiltroCategoria] = useState('')
  const [nome, setNome] = useState('')
  const [categoria, setCategoria] = useState('')
  const [editando, setEditando] = useState<Produto | null>(null)
  const [erro, setErro] = useState('')
  const [aviso, setAviso] = useState('')

  async function carregar() {
    const [p, a] = await Promise.all([
      supabase.from('produtos').select('id, nome, categoria, ativo').order('nome'),
      supabase.from('itens').select('item, categoria').is('produto_id', null),
    ])
    setErro(mensagemErro(p.error ?? a.error))
    const lista = (p.data ?? []) as Produto[]
    setProdutos(lista)
    // Itens pedidos fora do catálogo, sem repetir e sem os que já viraram produto.
    const noCatalogo = new Set(lista.map((x) => normalizar(x.nome)))
    const contagem = new Map<string, Avulso>()
    for (const x of (a.data ?? []) as { item: string; categoria: Categoria }[]) {
      const k = normalizar(x.item)
      if (noCatalogo.has(k)) continue
      const atual = contagem.get(k)
      contagem.set(k, { item: x.item, categoria: x.categoria, vezes: (atual?.vezes ?? 0) + 1 })
    }
    setAvulsos([...contagem.values()].sort((x, y) => y.vezes - x.vezes))
  }
  useEffect(() => { carregar() }, [])

  async function salvarNovo(e: FormEvent) {
    e.preventDefault()
    setErro('')
    const { error } = await supabase.from('produtos').insert({ nome, categoria })
    if (error) return setErro(mensagemErro(error))
    setAviso(`“${nome.trim()}” adicionado ao catálogo.`)
    setNome('')
    carregar()
  }

  async function atualizar(p: Produto, mudancas: Partial<Produto>, msg: string) {
    setErro('')
    const { error } = await supabase.from('produtos').update(mudancas).eq('id', p.id)
    if (error) return setErro(mensagemErro(error))
    setAviso(msg)
    setEditando(null)
    carregar()
  }

  async function catalogar(a: Avulso) {
    setErro('')
    const { error } = await supabase.from('produtos').insert({ nome: a.item, categoria: a.categoria })
    if (error) return setErro(mensagemErro(error))
    setAviso(`“${a.item}” agora faz parte do catálogo.`)
    carregar()
  }

  const termo = normalizar(busca)
  const visiveis = produtos.filter((p) => (!filtroCategoria || p.categoria === filtroCategoria) && normalizar(p.nome).includes(termo))
  const ativos = produtos.filter((p) => p.ativo).length

  return (
    <>
      <div className="cabecalho-pagina">
        <h1>Catálogo</h1>
        <p className="suave">{ativos} produtos disponíveis para as escolas{produtos.length > ativos && ` · ${produtos.length - ativos} desativados`}.</p>
      </div>

      <Erro>{erro}</Erro>
      {aviso && <p className="aviso" role="status">{aviso}</p>}

      <div className="detalhe lado-a-lado">
        <form className="formulario bloco" onSubmit={salvarNovo}>
          <h2>Novo produto</h2>
          <label>
            Nome (com a embalagem) *
            <input required maxLength={200} value={nome} onChange={(e) => setNome(e.target.value)}
              placeholder="Ex.: Papel sulfite A4 (resma com 500 folhas)" />
          </label>
          <label>
            Categoria *
            <select required value={categoria} onChange={(e) => setCategoria(e.target.value)}>
              <option value="" disabled>Selecione</option>
              {Object.entries(CATEGORIAS).map(([v, n]) => <option key={v} value={v}>{n}</option>)}
            </select>
          </label>
          <button className="botao primario">Adicionar ao catálogo</button>
        </form>

        <section className="bloco">
          <h2>Pedidos fora do catálogo</h2>
          {avulsos.length === 0 ? (
            <p className="suave">Nenhum item pedido fora do catálogo.</p>
          ) : (
            <ul className="avulsos">
              {avulsos.map((a) => (
                <li key={a.item}>
                  <span className="nome-item">{a.item}</span>
                  <BadgeCategoria categoria={a.categoria} />
                  <span className="dica">{a.vezes === 1 ? 'pedido 1 vez' : `pedido ${a.vezes} vezes`}</span>
                  <button className="botao secundario" onClick={() => catalogar(a)}>Adicionar ao catálogo</button>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>

      <div className="busca-linha">
        <label className="busca">
          Buscar produto
          <input type="search" value={busca} onChange={(e) => setBusca(e.target.value)} />
        </label>
        <label>
          Categoria
          <select value={filtroCategoria} onChange={(e) => setFiltroCategoria(e.target.value)}>
            <option value="">Todas</option>
            {Object.entries(CATEGORIAS).map(([v, n]) => <option key={v} value={v}>{n}</option>)}
          </select>
        </label>
      </div>

      <table className="tabela tabela-simples tabela-catalogo">
        <thead>
          <tr><th>Produto</th><th>Categoria</th><th>Situação</th><th><span className="sr">Ações</span></th></tr>
        </thead>
        <tbody>
          {visiveis.map((p) => editando?.id === p.id ? (
            <tr key={p.id}>
              <td colSpan={2}>
                <form className="edicao-produto" onSubmit={(e) => { e.preventDefault(); atualizar(p, { nome: editando.nome, categoria: editando.categoria }, 'Produto atualizado.') }}>
                  <input aria-label="Nome do produto" required maxLength={200} value={editando.nome}
                    onChange={(e) => setEditando({ ...editando, nome: e.target.value })} />
                  <select aria-label="Categoria" value={editando.categoria}
                    onChange={(e) => setEditando({ ...editando, categoria: e.target.value as Categoria })}>
                    {Object.entries(CATEGORIAS).map(([v, n]) => <option key={v} value={v}>{n}</option>)}
                  </select>
                  <button className="botao primario">Salvar</button>
                  <button type="button" className="botao secundario" onClick={() => setEditando(null)}>Cancelar</button>
                </form>
              </td>
              <td colSpan={2} />
            </tr>
          ) : (
            <tr key={p.id} className={p.ativo ? '' : 'inativo'}>
              <td className="col-item">{p.nome}</td>
              <td><BadgeCategoria categoria={p.categoria} /></td>
              <td>{p.ativo ? 'Disponível' : 'Desativado'}</td>
              <td className="acoes-produto">
                <button className="link" onClick={() => setEditando(p)}>Editar</button>
                <button className="link" onClick={() => atualizar(p, { ativo: !p.ativo },
                  p.ativo ? `“${p.nome}” desativado: não aparece mais para as escolas.` : `“${p.nome}” disponível de novo.`)}>
                  {p.ativo ? 'Desativar' : 'Reativar'}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  )
}
