import { useEffect, useState } from 'react'
import {
  CATEGORIAS, STATUS, data, dataSimples, mensagemErro, normalizar, supabase,
  type Categoria, type Perfil, type Solicitacao, type Status,
} from './dominio'
import { BadgeCategoria, BadgeStatus, Erro, IconeStatus } from './ui'

const POR_PAGINA = 25

type Linha = Pick<Solicitacao, 'id' | 'categoria' | 'item' | 'quantidade' | 'status' | 'criado_em' | 'atualizado_em' | 'unidades'> & {
  novidades: unknown
}

export function Lista({ perfil, params }: { perfil: Perfil; params: URLSearchParams }) {
  const secretaria = perfil.papel === 'secretaria'
  const chave = params.toString()
  const f = Object.fromEntries(params) as Record<string, string>
  const pagina = Math.max(1, Number(f.pagina) || 1)

  const [linhas, setLinhas] = useState<Linha[]>([])
  const [total, setTotal] = useState(0)
  const [contagem, setContagem] = useState<Partial<Record<Status, number>>>({})
  const [unidades, setUnidades] = useState<{ id: number; nome: string }[]>([])
  const [carregando, setCarregando] = useState(true)
  const [erro, setErro] = useState('')
  const [filtrosAbertos, setFiltrosAbertos] = useState(false)
  const [texto, setTexto] = useState(f.item ?? '')

  function aplicar(novos: Record<string, string>) {
    const p = new URLSearchParams({ ...f, ...novos })
    if (!('pagina' in novos)) p.delete('pagina')
    for (const [k, v] of [...p]) if (!v) p.delete(k)
    location.hash = '#/?' + p
  }

  useEffect(() => setTexto(f.item ?? ''), [f.item])
  useEffect(() => {
    if (texto === (f.item ?? '')) return
    const t = setTimeout(() => aplicar({ item: texto }), 350)
    return () => clearTimeout(t)
  }, [texto]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!secretaria) return
    supabase.from('unidades').select('id, nome').order('nome')
      .then(({ data }) => setUnidades(data ?? []))
  }, [secretaria])

  useEffect(() => {
    setCarregando(true)
    let q = supabase.from('solicitacoes')
      .select('id, categoria, item, quantidade, status, criado_em, atualizado_em, unidades(nome), novidades(solicitacao_id)', { count: 'exact' })
    if (f.escola) q = q.eq('unidade_id', f.escola)
    if (f.categoria) q = q.eq('categoria', f.categoria)
    if (f.status) q = q.eq('status', f.status)
    if (f.de) q = q.gte('criado_em', new Date(f.de + 'T00:00').toISOString())
    if (f.ate) {
      const fim = new Date(f.ate + 'T00:00')
      fim.setDate(fim.getDate() + 1)
      q = q.lt('criado_em', fim.toISOString())
    }
    if (f.item) q = q.ilike('item_busca', `%${normalizar(f.item).replace(/[\\%_]/g, '\\$&')}%`)
    const inicio = (pagina - 1) * POR_PAGINA
    q.order('criado_em', { ascending: false }).range(inicio, inicio + POR_PAGINA - 1)
      .then(({ data, count, error }) => {
        setErro(mensagemErro(error))
        setLinhas((data ?? []) as unknown as Linha[])
        setTotal(count ?? 0)
        setCarregando(false)
      })
    supabase.rpc('contagem_por_status').then(({ data }) => {
      setContagem(Object.fromEntries(((data ?? []) as { status: Status; total: number }[]).map((c) => [c.status, c.total])))
    })
  }, [chave]) // eslint-disable-line react-hooks/exhaustive-deps

  const nomeUnidade = (id: string) => unidades.find((u) => String(u.id) === id)?.nome ?? 'Escola'
  const chips: [string, string][] = [
    ['escola', f.escola && nomeUnidade(f.escola)],
    ['categoria', f.categoria && CATEGORIAS[f.categoria as Categoria]],
    ['status', f.status && STATUS[f.status as Status]],
    ['de', f.de && `A partir de ${dataSimples(f.de)}`],
    ['ate', f.ate && `Até ${dataSimples(f.ate)}`],
    ['item', f.item && `Item: ${f.item}`],
  ].filter((c): c is [string, string] => Boolean(c[1]))

  const paginas = Math.max(1, Math.ceil(total / POR_PAGINA))
  const abrir = (id: number) => { location.hash = `#/solicitacao/${id}` }

  return (
    <>
      <div className="cabecalho-pagina">
        <h1>Solicitações</h1>
        {!secretaria && <a className="botao primario acao-topo" href="#/nova">Nova solicitação</a>}
        {!secretaria && <p className="suave">{perfil.unidades?.nome}</p>}
      </div>

      <div className="cards-status">
        {(Object.keys(STATUS) as Status[]).map((s) => (
          <button key={s} className={`card-status status-${s}`} aria-pressed={f.status === s}
            onClick={() => aplicar({ status: f.status === s ? '' : s })}>
            <span className="numero">{contagem[s] ?? 0}</span>
            <span className="rotulo"><IconeStatus status={s} />{STATUS[s]}</span>
          </button>
        ))}
      </div>

      <button className="botao secundario abrir-filtros" aria-expanded={filtrosAbertos}
        aria-controls="filtros" onClick={() => setFiltrosAbertos(true)}>
        Filtros{chips.length > 0 && ` (${chips.length})`}
      </button>

      <form id="filtros" className={`filtros ${filtrosAbertos ? 'aberto' : ''}`}
        onKeyDown={(e) => e.key === 'Escape' && setFiltrosAbertos(false)}
        onSubmit={(e) => { e.preventDefault(); aplicar({ item: texto }); setFiltrosAbertos(false) }}>
        <div className="filtros-topo">
          <h2>Filtros</h2>
          <button type="button" className="link" onClick={() => setFiltrosAbertos(false)}>Fechar</button>
        </div>
        <label className="busca">
          Nome do item
          <input type="search" value={texto} onChange={(e) => setTexto(e.target.value)} placeholder="Ex.: papel sulfite" />
        </label>
        {secretaria && (
          <label>
            Escola
            <select value={f.escola ?? ''} onChange={(e) => aplicar({ escola: e.target.value })}>
              <option value="">Todas</option>
              {unidades.map((u) => <option key={u.id} value={u.id}>{u.nome}</option>)}
            </select>
          </label>
        )}
        <label>
          Categoria
          <select value={f.categoria ?? ''} onChange={(e) => aplicar({ categoria: e.target.value })}>
            <option value="">Todas</option>
            {Object.entries(CATEGORIAS).map(([v, n]) => <option key={v} value={v}>{n}</option>)}
          </select>
        </label>
        <label>
          Status
          <select value={f.status ?? ''} onChange={(e) => aplicar({ status: e.target.value })}>
            <option value="">Todos</option>
            {Object.entries(STATUS).map(([v, n]) => <option key={v} value={v}>{n}</option>)}
          </select>
        </label>
        <label>
          Cadastrada de
          <input type="date" value={f.de ?? ''} onChange={(e) => aplicar({ de: e.target.value })} />
        </label>
        <label>
          até
          <input type="date" value={f.ate ?? ''} onChange={(e) => aplicar({ ate: e.target.value })} />
        </label>
        <button className="botao primario so-painel">Ver resultados</button>
      </form>
      {filtrosAbertos && <div className="veu" onClick={() => setFiltrosAbertos(false)} />}

      {chips.length > 0 && (
        <div className="chips">
          {chips.map(([k, rotulo]) => (
            <button key={k} className="chip" onClick={() => aplicar({ [k]: '' })} aria-label={`Remover filtro ${rotulo}`}>
              {rotulo} <span aria-hidden="true">×</span>
            </button>
          ))}
          <button className="link" onClick={() => { location.hash = '#/' }}>Limpar filtros</button>
        </div>
      )}

      <Erro>{erro}</Erro>

      {!carregando && linhas.length === 0 && !erro ? (
        <div className="vazio">
          {chips.length > 0 ? (
            <>
              <p>Nenhuma solicitação com esses filtros.</p>
              <button className="botao secundario" onClick={() => { location.hash = '#/' }}>Limpar filtros</button>
            </>
          ) : secretaria ? (
            <p>Nenhuma solicitação recebida ainda.</p>
          ) : (
            <>
              <p>Sua unidade ainda não tem solicitações.</p>
              <a className="botao primario" href="#/nova">Cadastrar solicitação</a>
            </>
          )}
        </div>
      ) : (
        <table className="tabela" aria-busy={carregando}>
          <thead>
            <tr>
              {secretaria && <th>Escola</th>}
              <th>Item</th>
              <th className="col-categoria">Categoria</th>
              <th className="num">Qtd.</th>
              <th>Status</th>
              <th className="col-data">Cadastrada em</th>
            </tr>
          </thead>
          <tbody>
            {linhas.map((l) => {
              const novo = secretaria ? l.status === 'cadastrada' : Array.isArray(l.novidades) ? l.novidades.length > 0 : Boolean(l.novidades)
              return (
                <tr key={l.id} className={novo ? 'novo' : ''} onClick={() => abrir(l.id)}>
                  {secretaria && <td className="col-escola">{l.unidades?.nome}</td>}
                  <td className="col-item">
                    <a href={`#/solicitacao/${l.id}`} onClick={(e) => e.stopPropagation()}>{l.item}</a>
                    {novo && !secretaria && <span className="sr"> (status atualizado)</span>}
                  </td>
                  <td className="col-categoria"><BadgeCategoria categoria={l.categoria} /></td>
                  <td className="num col-qtd">{l.quantidade}</td>
                  <td className="col-status"><BadgeStatus status={l.status} /></td>
                  <td className="col-data">{data(l.criado_em)}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      )}

      {total > POR_PAGINA && (
        <nav className="paginacao" aria-label="Paginação">
          <button className="botao secundario" disabled={pagina <= 1}
            onClick={() => aplicar({ pagina: String(pagina - 1) })}>Anterior</button>
          <span>{(pagina - 1) * POR_PAGINA + 1}–{Math.min(pagina * POR_PAGINA, total)} de {total}</span>
          <button className="botao secundario" disabled={pagina >= paginas}
            onClick={() => aplicar({ pagina: String(pagina + 1) })}>Próxima</button>
        </nav>
      )}
    </>
  )
}
