import { useEffect, useState } from 'react'
import {
  CATEGORIAS, STATUS, data, dataSimples, mensagemErro, supabase,
  type Categoria, type Perfil, type ResumoSolicitacao, type Status,
} from './dominio'
import { Erro, IconeStatus, ResumoItens } from './ui'

const POR_PAGINA = 25

// Data do filtro ("2026-09-01") → início daquele dia no fuso de quem usa.
const inicioDoDia = (d: string, somarDias = 0) => {
  const x = new Date(d + 'T00:00')
  x.setDate(x.getDate() + somarDias)
  return x.toISOString()
}

export function Lista({ perfil, params }: { perfil: Perfil; params: URLSearchParams }) {
  const secretaria = perfil.papel === 'secretaria'
  const chave = params.toString()
  const f = Object.fromEntries(params) as Record<string, string>
  const pagina = Math.max(1, Number(f.pagina) || 1)

  const [linhas, setLinhas] = useState<ResumoSolicitacao[]>([])
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
    supabase.rpc('buscar_solicitacoes', {
      p_escola: f.escola || null,
      p_categoria: f.categoria || null,
      p_status: f.status || null,
      p_de: f.de ? inicioDoDia(f.de) : null,
      p_ate: f.ate ? inicioDoDia(f.ate, 1) : null,
      p_item: f.item || null,
      p_limite: POR_PAGINA,
      p_deslocamento: (pagina - 1) * POR_PAGINA,
    }).then(({ data, error }) => {
      setErro(mensagemErro(error))
      setLinhas((data ?? []) as ResumoSolicitacao[])
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
    ['status', f.status && `Itens: ${STATUS[f.status as Status]}`],
    ['de', f.de && `A partir de ${dataSimples(f.de)}`],
    ['ate', f.ate && `Até ${dataSimples(f.ate)}`],
    ['item', f.item && `Item: ${f.item}`],
  ].filter((c): c is [string, string] => Boolean(c[1]))

  const total = linhas[0]?.total ?? 0
  const paginas = Math.max(1, Math.ceil(total / POR_PAGINA))
  const abrir = (id: number) => { location.hash = `#/solicitacao/${id}` }

  return (
    <>
      <div className="cabecalho-pagina">
        <h1>Solicitações</h1>
        {!secretaria && <a className="botao primario acao-topo" href="#/nova">Nova solicitação</a>}
        {!secretaria && <p className="suave">{perfil.unidades?.nome}</p>}
      </div>

      <h2 className="sr">Itens por status</h2>
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
          Status do item
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
              <th>Solicitação</th>
              {secretaria && <th>Escola</th>}
              <th className="num">Itens</th>
              <th>Situação dos itens</th>
              <th className="col-data">Cadastrada em</th>
            </tr>
          </thead>
          <tbody>
            {linhas.map((l) => {
              // Gestor: algum item mudou de status. Secretaria: há itens aguardando análise.
              const novo = secretaria ? Boolean(l.por_status.cadastrada) : l.novidade
              return (
                <tr key={l.id} className={novo ? 'novo' : ''} onClick={() => abrir(l.id)}>
                  <td className="col-item">
                    <a href={`#/solicitacao/${l.id}`} onClick={(e) => e.stopPropagation()}>Nº {l.id}</a>
                    {novo && <span className="sr">{secretaria ? ' (itens aguardando análise)' : ' (itens atualizados)'}</span>}
                    {l.observacoes && <span className="obs-linha">{l.observacoes}</span>}
                  </td>
                  {secretaria && <td className="col-escola">{l.escola}</td>}
                  <td className="num col-qtd" data-rotulo="Itens: ">{l.total_itens}</td>
                  <td className="col-status"><ResumoItens porStatus={l.por_status} /></td>
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
