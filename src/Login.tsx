import { useState, type FormEvent } from 'react'
import { mensagemErro, supabase } from './dominio'
import { Erro } from './ui'

export function Login() {
  const [modo, setModo] = useState<'entrar' | 'recuperar'>('entrar')
  const [email, setEmail] = useState('')
  const [senha, setSenha] = useState('')
  const [erro, setErro] = useState('')
  const [aviso, setAviso] = useState('')
  const [enviando, setEnviando] = useState(false)

  async function enviar(e: FormEvent) {
    e.preventDefault()
    setErro('')
    setEnviando(true)
    if (modo === 'entrar') {
      const { error } = await supabase.auth.signInWithPassword({ email, password: senha })
      setErro(mensagemErro(error))
    } else {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: location.origin,
      })
      if (error) setErro(mensagemErro(error))
      else setAviso('Se o e-mail estiver cadastrado, você receberá um link para criar uma nova senha.')
    }
    setEnviando(false)
  }

  return (
    <div className="tela-acesso">
      <div className="faixa" />
      <main className="caixa-acesso">
        <h1>Solicitações das Unidades Escolares</h1>
        <p className="suave">Secretaria Municipal de Educação</p>
        <form onSubmit={enviar} className="formulario">
          <label>
            E-mail
            <input type="email" required autoComplete="email" value={email}
              onChange={(e) => setEmail(e.target.value)} />
          </label>
          {modo === 'entrar' && (
            <label>
              Senha
              <input type="password" required autoComplete="current-password" value={senha}
                onChange={(e) => setSenha(e.target.value)} />
            </label>
          )}
          <Erro>{erro}</Erro>
          {aviso && <p className="aviso" role="status">{aviso}</p>}
          <button className="botao primario" disabled={enviando}>
            {modo === 'entrar' ? 'Entrar' : 'Enviar link de recuperação'}
          </button>
          <button type="button" className="link"
            onClick={() => { setModo(modo === 'entrar' ? 'recuperar' : 'entrar'); setErro(''); setAviso('') }}>
            {modo === 'entrar' ? 'Esqueci minha senha' : 'Voltar para o login'}
          </button>
        </form>
      </main>
    </div>
  )
}

export function NovaSenha({ aoConcluir }: { aoConcluir: () => void }) {
  const [senha, setSenha] = useState('')
  const [erro, setErro] = useState('')

  async function salvar(e: FormEvent) {
    e.preventDefault()
    const { error } = await supabase.auth.updateUser({ password: senha })
    if (error) setErro(mensagemErro(error))
    else aoConcluir()
  }

  return (
    <div className="tela-acesso">
      <div className="faixa" />
      <main className="caixa-acesso">
        <h1>Criar nova senha</h1>
        <form onSubmit={salvar} className="formulario">
          <label>
            Nova senha (mínimo 8 caracteres)
            <input type="password" required minLength={8} autoComplete="new-password"
              value={senha} onChange={(e) => setSenha(e.target.value)} />
          </label>
          <Erro>{erro}</Erro>
          <button className="botao primario">Salvar senha</button>
        </form>
      </main>
    </div>
  )
}
