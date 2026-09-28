import { useState, type FormEvent } from 'react'
import { CATEGORIAS, mensagemErro, supabase } from './dominio'
import { Erro } from './ui'

export function Nova() {
  const [categoria, setCategoria] = useState('')
  const [item, setItem] = useState('')
  const [quantidade, setQuantidade] = useState('1')
  const [observacoes, setObservacoes] = useState('')
  const [erro, setErro] = useState('')
  const [enviando, setEnviando] = useState(false)

  async function cadastrar(e: FormEvent) {
    e.preventDefault()
    setEnviando(true)
    // Unidade e status são definidos pelo banco a partir do gestor logado.
    const { data, error } = await supabase.from('solicitacoes').insert({
      categoria,
      item: item.trim(),
      quantidade: Number(quantidade),
      observacoes: observacoes.trim() || null,
    }).select('id').single()
    setEnviando(false)
    if (error) return setErro(mensagemErro(error))
    location.hash = `#/solicitacao/${data.id}`
  }

  return (
    <>
      <div className="cabecalho-pagina"><h1>Nova solicitação</h1></div>
      <form className="formulario bloco estreito" onSubmit={cadastrar}>
        <label>
          Categoria *
          <select required value={categoria} onChange={(e) => setCategoria(e.target.value)}>
            <option value="" disabled>Selecione</option>
            {Object.entries(CATEGORIAS).map(([v, n]) => <option key={v} value={v}>{n}</option>)}
          </select>
        </label>
        <label>
          Item *
          <input required maxLength={200} value={item} onChange={(e) => setItem(e.target.value)}
            placeholder="Ex.: papel sulfite A4 (resma)" />
        </label>
        <label>
          Quantidade *
          <input type="number" inputMode="numeric" required min={1} step={1} value={quantidade}
            onChange={(e) => setQuantidade(e.target.value)} />
        </label>
        <label>
          Observações
          <textarea rows={4} value={observacoes} onChange={(e) => setObservacoes(e.target.value)}
            placeholder="Detalhes que ajudem a Secretaria: modelo, tamanho, local do problema…" />
        </label>
        <Erro>{erro}</Erro>
        <div className="acoes">
          <button className="botao primario" disabled={enviando}>Cadastrar solicitação</button>
          <a className="botao secundario" href="#/">Cancelar</a>
        </div>
      </form>
    </>
  )
}
