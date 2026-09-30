import { useEffect, useState } from 'react'
import { CATEGORIAS, STATUS, mensagemErro, supabase, type Categoria, type Status } from './dominio'
import { Erro } from './ui'

type Linha = {
  id: number
  categoria: Categoria
  item: string
  item_busca: string
  quantidade: number
  observacoes: string | null
  solicitacao_id: number
  unidades: { nome: string } | null
}
type Grupo = { item: string; categoria: Categoria; linhas: Linha[] }

// Itens com o mesmo nome (sem diferenciar maiúsculas/acentos) viram uma linha só.
function agrupar(linhas: Linha[]) {
  const grupos = new Map<string, Grupo>()
  for (const l of linhas) {
    const chave = `${l.categoria}|${l.item_busca}`
    const g = grupos.get(chave) ?? { item: l.item, categoria: l.categoria, linhas: [] }
    g.linhas.push(l)
    grupos.set(chave, g)
  }
  return [...grupos.values()]
}

// Só soma quando nenhuma linha tem embalagem anotada (senão "20 caixas + 5 unidades" daria errado).
const total = (g: Grupo) => g.linhas.some((l) => l.observacoes) ? null : g.linhas.reduce((s, l) => s + l.quantidade, 0)

// "4 caixas" em vez de "4 (4 caixas)" quando a observação já traz a quantidade.
const quantidadeTexto = (l: Linha) =>
  l.observacoes?.startsWith(`${l.quantidade} `) ? l.observacoes
    : `${l.quantidade}${l.observacoes ? ` (${l.observacoes})` : ''}`

function comoTexto(grupos: Grupo[]) {
  return grupos.map((g) => {
    const t = total(g)
    const partes = g.linhas.map((l) => `  ${quantidadeTexto(l)} — ${l.unidades?.nome}`)
    return `${g.item}${t !== null ? `: ${t}` : ''}\n${partes.join('\n')}`
  }).join('\n\n')
}

export function Compras() {
  const [status, setStatus] = useState<Status>('em_analise')
  const [grupos, setGrupos] = useState<Grupo[]>([])
  const [carregando, setCarregando] = useState(true)
  const [erro, setErro] = useState('')
  const [copiado, setCopiado] = useState(false)

  useEffect(() => {
    setCarregando(true)
    setCopiado(false)
    supabase.from('itens')
      .select('id, categoria, item, item_busca, quantidade, observacoes, solicitacao_id, unidades(nome)')
      .eq('status', status).order('categoria').order('item_busca')
      .then(({ data, error }) => {
        setErro(mensagemErro(error))
        setGrupos(agrupar((data ?? []) as unknown as Linha[]))
        setCarregando(false)
      })
  }, [status])

  const porCategoria = Object.keys(CATEGORIAS)
    .map((c) => [c as Categoria, grupos.filter((g) => g.categoria === c)] as const)
    .filter(([, gs]) => gs.length > 0)

  return (
    <>
      <div className="cabecalho-pagina">
        <h1>Lista de compras</h1>
        <p className="suave">Itens de todas as escolas, juntos por nome, para lançar no SimCatarina.</p>
      </div>

      <div className="selecao-rapida" role="group" aria-label="Mostrar itens">
        <span className="suave">Mostrar itens:</span>
        {(['em_analise', 'cadastrada'] as Status[]).map((s) => (
          <button key={s} className="chip" aria-pressed={status === s} onClick={() => setStatus(s)}>{STATUS[s]}</button>
        ))}
        {grupos.length > 0 && (
          <button className="botao secundario copiar-compras"
            onClick={() => navigator.clipboard.writeText(comoTexto(grupos)).then(() => setCopiado(true))}>
            {copiado ? 'Lista copiada' : 'Copiar lista'}
          </button>
        )}
      </div>

      <Erro>{erro}</Erro>

      {!carregando && grupos.length === 0 && !erro && (
        <div className="vazio"><p>Nenhum item {status === 'em_analise' ? 'em análise' : 'cadastrado aguardando análise'} no momento.</p></div>
      )}

      {porCategoria.map(([c, gs]) => (
        <section key={c} className="bloco compras-categoria">
          <h2>{CATEGORIAS[c]}</h2>
          <ul className="compras">
            {gs.map((g) => {
              const t = total(g)
              return (
                <li key={g.item + g.linhas[0].id}>
                  <div className="compras-item">
                    <span className="nome-item">{g.item}</span>
                    {t !== null && <span className="compras-total">{t}</span>}
                  </div>
                  <ul className="compras-escolas">
                    {g.linhas.map((l) => (
                      <li key={l.id}>
                        <span className="num-esq compras-qtd">{quantidadeTexto(l)}</span>
                        {' — '}{l.unidades?.nome}
                        {' · '}<a href={`#/solicitacao/${l.solicitacao_id}`}>Solicitação nº {l.solicitacao_id}</a>
                      </li>
                    ))}
                  </ul>
                </li>
              )
            })}
          </ul>
        </section>
      ))}
    </>
  )
}
