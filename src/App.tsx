import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { configurado, mensagemErro, supabase, type Perfil } from './dominio'
import { Login, NovaSenha } from './Login'
import { Lista } from './Lista'
import { Detalhe } from './Detalhe'
import { Nova } from './Nova'
import { Contas } from './Contas'

// Rotas por hash (#/, #/nova, #/solicitacao/12?…): funciona em hospedagem estática.
function useRota() {
  const [hash, setHash] = useState(location.hash)
  useEffect(() => {
    const mudar = () => setHash(location.hash)
    addEventListener('hashchange', mudar)
    return () => removeEventListener('hashchange', mudar)
  }, [])
  const [caminho, query = ''] = hash.replace(/^#/, '').split('?')
  return { caminho: caminho || '/', params: new URLSearchParams(query), hash }
}

export default function App() {
  const [sessao, setSessao] = useState<Session | null | undefined>(undefined)
  const [recuperando, setRecuperando] = useState(false)
  const [perfil, setPerfil] = useState<Perfil | null | undefined>(undefined)
  const [erroPerfil, setErroPerfil] = useState('')

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSessao(data.session))
    const { data } = supabase.auth.onAuthStateChange((evento, s) => {
      if (evento === 'PASSWORD_RECOVERY') setRecuperando(true)
      setSessao(s)
    })
    return () => data.subscription.unsubscribe()
  }, [])

  const uid = sessao?.user.id
  useEffect(() => {
    if (!uid) return setPerfil(undefined)
    supabase.from('perfis').select('*, unidades(nome)').eq('id', uid).maybeSingle()
      .then(({ data, error }) => {
        if (error) setErroPerfil(mensagemErro(error))
        else setPerfil(data as Perfil | null)
      })
  }, [uid])

  if (!configurado) {
    return <Aviso titulo="Configuração pendente">
      Crie o arquivo .env.local com VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY (veja .env.example).
    </Aviso>
  }
  if (recuperando) return <NovaSenha aoConcluir={() => setRecuperando(false)} />
  if (sessao === undefined) return null
  if (!sessao) return <Login />
  if (erroPerfil) {
    return <Aviso titulo="Não foi possível carregar seus dados" tentar>{erroPerfil}</Aviso>
  }
  if (perfil === undefined) return null
  if (!perfil) {
    return <Aviso titulo="Conta sem perfil" sair>
      Sua conta ainda não foi vinculada a uma unidade escolar ou à Secretaria. Procure a Secretaria de Educação.
    </Aviso>
  }
  return <Painel perfil={perfil} />
}

function Painel({ perfil }: { perfil: Perfil }) {
  const { caminho, params, hash } = useRota()
  const [menuAberto, setMenuAberto] = useState(false)
  const [novidades, setNovidades] = useState(0)
  const gestor = perfil.papel === 'gestor'

  useEffect(() => {
    setMenuAberto(false)
    if (!gestor) return
    supabase.from('novidades').select('*', { count: 'exact', head: true })
      .then(({ count }) => setNovidades(count ?? 0))
  }, [hash, gestor])

  const idDetalhe = caminho.match(/^\/solicitacao\/(\d+)$/)?.[1]
  const pagina = idDetalhe ? <Detalhe id={Number(idDetalhe)} perfil={perfil} />
    : caminho === '/nova' && gestor ? <Nova />
    : caminho === '/contas' && !gestor ? <Contas />
    : <Lista perfil={perfil} params={params} />

  return (
    <div className="painel">
      <header className="topo">
        <div className="faixa" />
        <div className="topo-barra">
          <button className="botao-menu" aria-expanded={menuAberto} aria-controls="menu"
            onClick={() => setMenuAberto(!menuAberto)}>
            <svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true">
              <path d="M3 5h14M3 10h14M3 15h14" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            </svg>
            <span className="sr">Menu</span>
          </button>
          <span className="marca">Solicitações Escolares</span>
        </div>
      </header>

      <nav id="menu" className={`menu ${menuAberto ? 'aberto' : ''}`} aria-label="Principal"
        onKeyDown={(e) => e.key === 'Escape' && setMenuAberto(false)}>
        <span className="marca">Solicitações Escolares</span>
        <a href="#/" aria-current={caminho === '/' ? 'page' : undefined}>
          Solicitações
          {novidades > 0 && <span className="contador" aria-label={`${novidades} ${novidades === 1 ? 'item atualizado' : 'itens atualizados'}`}>{novidades}</span>}
        </a>
        {gestor && <a href="#/nova" aria-current={caminho === '/nova' ? 'page' : undefined}>Nova solicitação</a>}
        {!gestor && <a href="#/contas" aria-current={caminho === '/contas' ? 'page' : undefined}>Contas</a>}
        <div className="usuario">
          <strong>{perfil.nome}</strong>
          <span>{gestor ? perfil.unidades?.nome : 'Secretaria de Educação'}</span>
          <button className="link" onClick={() => supabase.auth.signOut()}>Sair</button>
        </div>
      </nav>
      {menuAberto && <div className="veu" onClick={() => setMenuAberto(false)} />}

      <main className="conteudo">{pagina}</main>

      {gestor && caminho !== '/nova' && (
        <a href="#/nova" className="botao primario acao-rodape">Nova solicitação</a>
      )}
    </div>
  )
}

function Aviso({ titulo, children, sair, tentar }: { titulo: string; children: string; sair?: boolean; tentar?: boolean }) {
  return (
    <div className="tela-acesso">
      <div className="faixa" />
      <main className="caixa-acesso">
        <h1>{titulo}</h1>
        <p>{children}</p>
        {tentar && <button className="botao primario" onClick={() => location.reload()}>Tentar de novo</button>}
        {sair && <button className="botao secundario" onClick={() => supabase.auth.signOut()}>Sair</button>}
      </main>
    </div>
  )
}
