import { useEffect, useState, type FormEvent } from 'react'
import { mensagemErro, supabase } from './dominio'
import { Erro } from './ui'

type Conta = { id: string; nome: string; email: string; papel: 'gestor' | 'secretaria'; unidades: { nome: string } | null }
type Criada = { nome: string; email: string; senha: string }

const NOVA = 'nova'

// Sem caracteres fáceis de confundir (0/O, 1/l/I) — a senha é ditada ou copiada à mão.
function senhaProvisoria() {
  const letras = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789'
  return Array.from(crypto.getRandomValues(new Uint32Array(10)), (n) => letras[n % letras.length]).join('')
}

export function Contas() {
  const [contas, setContas] = useState<Conta[]>([])
  const [unidades, setUnidades] = useState<{ id: number; nome: string }[]>([])
  const [erroLista, setErroLista] = useState('')

  const [nome, setNome] = useState('')
  const [email, setEmail] = useState('')
  const [papel, setPapel] = useState<'gestor' | 'secretaria'>('gestor')
  const [unidade, setUnidade] = useState('')
  const [novaUnidade, setNovaUnidade] = useState('')
  const [senha, setSenha] = useState(senhaProvisoria)
  const [erro, setErro] = useState('')
  const [enviando, setEnviando] = useState(false)
  const [criada, setCriada] = useState<Criada | null>(null)
  const [copiado, setCopiado] = useState(false)

  async function carregar() {
    const [c, u] = await Promise.all([
      supabase.from('perfis').select('id, nome, email, papel, unidades(nome)').order('papel').order('nome'),
      supabase.from('unidades').select('id, nome').order('nome'),
    ])
    setErroLista(mensagemErro(c.error ?? u.error))
    setContas((c.data ?? []) as unknown as Conta[])
    setUnidades(u.data ?? [])
  }
  useEffect(() => { carregar() }, [])

  async function criar(e: FormEvent) {
    e.preventDefault()
    setErro('')
    setEnviando(true)
    const { error } = await supabase.functions.invoke('criar-conta', {
      body: {
        nome, email, senha, papel,
        unidade_id: unidade === NOVA ? null : unidade,
        nova_unidade: unidade === NOVA ? novaUnidade : null,
      },
    })
    setEnviando(false)
    if (error) {
      const corpo = await error.context?.json?.().catch(() => null)
      return setErro(corpo?.erro ?? 'Não foi possível criar a conta. Verifique a conexão e tente de novo.')
    }
    setCriada({ nome, email: email.trim().toLowerCase(), senha })
    setCopiado(false)
    setNome(''); setEmail(''); setUnidade(''); setNovaUnidade(''); setSenha(senhaProvisoria())
    carregar()
  }

  return (
    <>
      <div className="cabecalho-pagina"><h1>Contas</h1></div>

      <div className="detalhe lado-a-lado">
        <form className="formulario bloco" onSubmit={criar}>
          <h2>Criar conta</h2>
          <label>
            Nome *
            <input required value={nome} onChange={(e) => setNome(e.target.value)} autoComplete="off" />
          </label>
          <label>
            E-mail *
            <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="off" />
          </label>
          <fieldset className="opcoes">
            <legend>Perfil *</legend>
            <label><input type="radio" name="papel" checked={papel === 'gestor'} onChange={() => setPapel('gestor')} /> Gestor de unidade escolar</label>
            <label><input type="radio" name="papel" checked={papel === 'secretaria'} onChange={() => setPapel('secretaria')} /> Secretaria</label>
          </fieldset>
          {papel === 'gestor' && (
            <label>
              Escola *
              <select required value={unidade} onChange={(e) => setUnidade(e.target.value)}>
                <option value="" disabled>Selecione</option>
                {unidades.map((u) => <option key={u.id} value={u.id}>{u.nome}</option>)}
                <option value={NOVA}>Cadastrar nova escola…</option>
              </select>
            </label>
          )}
          {papel === 'gestor' && unidade === NOVA && (
            <label>
              Nome da nova escola *
              <input required value={novaUnidade} onChange={(e) => setNovaUnidade(e.target.value)} placeholder="Ex.: EMEF Vila Nova" />
            </label>
          )}
          <label>
            Senha provisória *
            <span className="linha-campo">
              <input required minLength={8} value={senha} onChange={(e) => setSenha(e.target.value)} autoComplete="off" spellCheck={false} />
              <button type="button" className="botao secundario" onClick={() => setSenha(senhaProvisoria())}>Gerar outra</button>
            </span>
          </label>
          <Erro>{erro}</Erro>
          <button className="botao primario" disabled={enviando}>Criar conta</button>
        </form>

        {criada && (
          <section className="bloco" role="status">
            <h2>Conta criada</h2>
            <p className="suave">Envie estes dados para {criada.nome}. A senha pode ser trocada depois em “Esqueci minha senha”, na tela de login.</p>
            <dl className="campos">
              <dt>E-mail</dt><dd>{criada.email}</dd>
              <dt>Senha provisória</dt><dd className="senha">{criada.senha}</dd>
              <dt>Endereço</dt><dd>{location.origin}</dd>
            </dl>
            <button className="botao secundario" onClick={() => navigator.clipboard.writeText(
              `Acesso ao Sistema de Solicitações\nEndereço: ${location.origin}\nE-mail: ${criada.email}\nSenha provisória: ${criada.senha}`,
            ).then(() => setCopiado(true))}>
              {copiado ? 'Dados copiados' : 'Copiar dados de acesso'}
            </button>
          </section>
        )}
      </div>

      <h2>Contas cadastradas</h2>
      <Erro>{erroLista}</Erro>
      <table className="tabela tabela-simples">
        <thead>
          <tr><th>Nome</th><th>E-mail</th><th>Perfil</th><th>Escola</th></tr>
        </thead>
        <tbody>
          {contas.map((c) => (
            <tr key={c.id}>
              <td>{c.nome}</td>
              <td className="col-email">{c.email}</td>
              <td>{c.papel === 'gestor' ? 'Gestor' : 'Secretaria'}</td>
              <td>{c.unidades?.nome ?? '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  )
}
