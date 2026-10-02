import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { CATEGORIAS, mensagemErro, nomeBase, normalizar, supabase, type Produto } from './dominio'
import { BadgeCategoria, Erro } from './ui'
import { lerLista } from './colarLista'

// Linha do pedido: produto do catálogo (produto_id) ou "outro item" (produto_id null, nome digitado).
type Linha = {
  chave: number
  produto_id: number | null
  categoria: string
  item: string
  quantidade: string
  observacoes: string
  ultima?: number
}

let proximaChave = 0
const MAX_RESULTADOS = 40

export function Nova({ params }: { params: URLSearchParams }) {
  const base = params.get('base')
  const [produtos, setProdutos] = useState<Produto[]>([])
  const [ultimas, setUltimas] = useState<Map<number, number>>(new Map())
  const [linhas, setLinhas] = useState<Linha[]>([])
  const [busca, setBusca] = useState('')
  const [categoria, setCategoria] = useState('')
  const [observacoes, setObservacoes] = useState('')
  const [colando, setColando] = useState(false)
  const [colado, setColado] = useState('')
  const [aviso, setAviso] = useState('')
  const [erro, setErro] = useState('')
  const [enviando, setEnviando] = useState(false)
  const [focar, setFocar] = useState<number | null>(null)

  const porId = useMemo(() => new Map(produtos.map((p) => [p.id, p])), [produtos])

  const linhaDoProduto = (p: Produto, quantidade?: number): Linha => ({
    chave: proximaChave++, produto_id: p.id, categoria: p.categoria, item: p.nome,
    quantidade: String(quantidade ?? ultimas.get(p.id) ?? 1), observacoes: '', ultima: ultimas.get(p.id),
  })
  const outroItem = (item = '', quantidade = '1', cat = '', observacoes = ''): Linha =>
    ({ chave: proximaChave++, produto_id: null, categoria: cat, item, quantidade, observacoes })

  useEffect(() => {
    Promise.all([
      supabase.from('produtos').select('id, nome, categoria, ativo').eq('ativo', true).order('nome'),
      supabase.rpc('ultimas_quantidades'),
      base
        ? supabase.from('itens').select('produto_id, categoria, item, quantidade, observacoes').eq('solicitacao_id', base).order('id')
        : Promise.resolve({ data: null, error: null }),
    ]).then(([p, u, b]) => {
      setErro(mensagemErro(p.error ?? u.error ?? b.error))
      const lista = (p.data ?? []) as Produto[]
      const mapa = new Map(((u.data ?? []) as { produto_id: number; quantidade: number }[]).map((x) => [x.produto_id, x.quantidade]))
      setProdutos(lista)
      setUltimas(mapa)
      // "Repetir pedido": copia os itens da solicitação base; produto desativado vira "outro item".
      if (b.data) {
        const ativos = new Set(lista.map((x) => x.id))
        setLinhas((b.data as Omit<Linha, 'chave'>[]).map((x) => x.produto_id && ativos.has(x.produto_id)
          ? { chave: proximaChave++, produto_id: x.produto_id, categoria: x.categoria, item: x.item,
              quantidade: String(x.quantidade), observacoes: x.observacoes ?? '', ultima: mapa.get(x.produto_id) }
          : outroItem(x.item, String(x.quantidade), x.categoria, x.observacoes ?? '')))
        setAviso(`Itens copiados da solicitação nº ${base}. Ajuste as quantidades e envie.`)
      }
    })
  }, [base]) // eslint-disable-line react-hooks/exhaustive-deps

  const naLista = new Map(linhas.filter((l) => l.produto_id).map((l) => [l.produto_id, l]))
  const termo = normalizar(busca)
  // Sem busca nem categoria: mostra o que a escola já pediu antes, para pedidos recorrentes.
  const resultados = (termo || categoria
    ? produtos.filter((p) => (!categoria || p.categoria === categoria) && normalizar(p.nome).includes(termo))
    : produtos.filter((p) => ultimas.has(p.id))
  ).slice(0, MAX_RESULTADOS)

  const mudar = (chave: number, campo: keyof Linha, valor: string) =>
    setLinhas(linhas.map((l) => (l.chave === chave ? { ...l, [campo]: valor } : l)))

  function adicionar(p: Produto) {
    const nova = linhaDoProduto(p)
    setLinhas([...linhas, nova])
    setFocar(nova.chave) // cursor vai para a quantidade, ali mesmo na busca
    setAviso('')
  }

  function aplicarColagem() {
    // Nome igual ao do catálogo (ignorando embalagem, acentos e maiúsculas) vira o produto; o resto, "outro item".
    const porNome = new Map<string, Produto | null>()
    for (const p of produtos) {
      const k = nomeBase(p.nome)
      porNome.set(k, porNome.has(k) ? null : p) // nome base repetido no catálogo: ambíguo
      porNome.set(normalizar(p.nome), p)
    }
    const novas = lerLista(colado).map((x) => {
      const p = porNome.get(normalizar(x.item)) ?? porNome.get(nomeBase(x.item))
      return p ? linhaDoProduto(p, Number(x.quantidade) || undefined) : outroItem(x.item.slice(0, 200), x.quantidade, '', x.observacoes)
    })
    setLinhas([...linhas, ...novas])
    const doCatalogo = novas.filter((l) => l.produto_id).length
    setAviso(`${novas.length} ${novas.length === 1 ? 'item adicionado' : 'itens adicionados'}: ${doCatalogo} do catálogo`
      + ` e ${novas.length - doCatalogo} fora do catálogo (escolha a categoria desses). Confira as quantidades.`)
    setColado('')
    setColando(false)
  }

  async function enviar(e: FormEvent) {
    e.preventDefault()
    setEnviando(true)
    setErro('')
    // Unidade e status são definidos pelo banco; nome e categoria de produto vêm do catálogo.
    const { data, error } = await supabase.rpc('criar_solicitacao', {
      p_observacoes: observacoes.trim() || null,
      p_itens: linhas.map((l) => l.produto_id
        ? { produto_id: l.produto_id, quantidade: Number(l.quantidade), observacoes: l.observacoes.trim() || null }
        : { categoria: l.categoria, item: l.item.trim(), quantidade: Number(l.quantidade), observacoes: l.observacoes.trim() || null }),
    })
    setEnviando(false)
    if (error) return setErro(mensagemErro(error))
    location.hash = `#/solicitacao/${data}`
  }

  return (
    <>
      <div className="cabecalho-pagina"><h1>Nova solicitação</h1></div>

      <section className="bloco catalogo-busca" aria-label="Catálogo de produtos">
        <div className="busca-linha">
          <label className="busca">
            Buscar no catálogo
            <input type="search" value={busca} onChange={(e) => setBusca(e.target.value)} placeholder="Ex.: papel, luva, detergente" />
          </label>
          <label>
            Categoria
            <select value={categoria} onChange={(e) => setCategoria(e.target.value)}>
              <option value="">Todas</option>
              {Object.entries(CATEGORIAS).map(([v, n]) => <option key={v} value={v}>{n}</option>)}
            </select>
          </label>
        </div>
        <p className="dica">
          {termo || categoria
            ? `${resultados.length === MAX_RESULTADOS ? `Primeiros ${MAX_RESULTADOS}` : resultados.length} produto(s) encontrado(s).`
            : ultimas.size ? 'Produtos que a escola já pediu antes (a quantidade vem do último pedido):' : 'Busque um produto pelo nome ou escolha uma categoria.'}
        </p>
        <ul className="resultados">
          {resultados.map((p) => {
            const l = naLista.get(p.id)
            return (
              <li key={p.id}>
                {l ? <span className="nome-item">{p.nome}</span> : (
                  <button type="button" className="nome-item produto-botao" onClick={() => adicionar(p)}>{p.nome}</button>
                )}
                <BadgeCategoria categoria={p.categoria} />
                {ultimas.has(p.id) && <span className="dica">último pedido: {ultimas.get(p.id)}</span>}
                {l ? (
                  // Já na lista: a quantidade é editada aqui mesmo, sem descer até os itens do pedido.
                  <label className="qtd-rapida">
                    Quantidade
                    <input type="number" inputMode="numeric" required min={1} step={1} value={l.quantidade}
                      autoFocus={l.chave === focar} onFocus={(e) => e.target.select()}
                      onChange={(e) => mudar(l.chave, 'quantidade', e.target.value)} />
                  </label>
                ) : (
                  <button type="button" className="botao secundario" onClick={() => adicionar(p)}>Adicionar</button>
                )}
              </li>
            )
          })}
        </ul>
        <div className="acoes">
          <button type="button" className="botao secundario" onClick={() => { setLinhas([...linhas, outroItem()]); setAviso('') }}>
            Outro item (fora do catálogo)
          </button>
          <button type="button" className="botao secundario" onClick={() => { setColando(!colando); setAviso('') }}>
            Colar lista
          </button>
        </div>
        {colando && (
          <div className="colar">
            <label>
              Cole a lista (um item por linha)
              <textarea rows={6} value={colado} onChange={(e) => setColado(e.target.value)} autoFocus
                placeholder={'20 água sanitária\n4 caixas álcool líquido\nLUVA M   200 CAIXAS'} />
            </label>
            <div className="acoes">
              <button type="button" className="botao primario" onClick={aplicarColagem} disabled={!colado.trim()}>
                Adicionar itens da lista
              </button>
              <button type="button" className="botao secundario" onClick={() => setColando(false)}>Cancelar</button>
            </div>
          </div>
        )}
      </section>

      {aviso && <p className="aviso" role="status">{aviso}</p>}

      <form className="formulario bloco" onSubmit={enviar}>
        <h2>Itens do pedido ({linhas.length})</h2>
        {linhas.length === 0 && <p className="suave">Nenhum item ainda. Adicione produtos do catálogo acima.</p>}
        <ol className="linhas-itens">
          {linhas.map((l, i) => {
            const p = l.produto_id ? porId.get(l.produto_id) : null
            return (
              <li key={l.chave}>
                <fieldset className="linha-item">
                  <legend>Item {i + 1}{!l.produto_id && ' · fora do catálogo'}</legend>
                  {p ? (
                    <div className="produto-escolhido">
                      <span className="nome-item">{p.nome}</span>
                      <BadgeCategoria categoria={p.categoria} />
                    </div>
                  ) : (
                    <>
                      <label>
                        Categoria *
                        <select required value={l.categoria} onChange={(e) => mudar(l.chave, 'categoria', e.target.value)}>
                          <option value="" disabled>Selecione</option>
                          {Object.entries(CATEGORIAS).map(([v, n]) => <option key={v} value={v}>{n}</option>)}
                        </select>
                      </label>
                      <label>
                        Item *
                        <input className="campo-item" required maxLength={200} value={l.item}
                          onChange={(e) => mudar(l.chave, 'item', e.target.value)} placeholder="Nome e embalagem, ex.: cabo HDMI 3 m" />
                      </label>
                    </>
                  )}
                  <label className="campo-qtd">
                    Quantidade *
                    <input type="number" inputMode="numeric" required min={1} step={1} value={l.quantidade}
                      onChange={(e) => mudar(l.chave, 'quantidade', e.target.value)} />
                    {l.ultima !== undefined && <span className="dica">último: {l.ultima}</span>}
                  </label>
                  <label className="campo-obs">
                    Observações
                    <input value={l.observacoes} onChange={(e) => mudar(l.chave, 'observacoes', e.target.value)}
                      placeholder="Modelo, cor, tamanho…" />
                  </label>
                  <button type="button" className="link remover" onClick={() => setLinhas(linhas.filter((x) => x.chave !== l.chave))}
                    aria-label={`Remover item ${i + 1}`}>
                    Remover
                  </button>
                </fieldset>
              </li>
            )
          })}
        </ol>
        <label>
          Observações gerais do pedido
          <textarea rows={3} value={observacoes} onChange={(e) => setObservacoes(e.target.value)}
            placeholder="Informações que valem para o pedido todo" />
        </label>
        <Erro>{erro}</Erro>
        <div className="acoes">
          <button className="botao primario" disabled={enviando || linhas.length === 0}>
            Enviar solicitação ({linhas.length} {linhas.length === 1 ? 'item' : 'itens'})
          </button>
          <a className="botao secundario" href="#/">Cancelar</a>
        </div>
      </form>
    </>
  )
}
