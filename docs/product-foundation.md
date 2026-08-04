# Product Foundation

## Tese

Codex Bridge Mobile nao e um aplicativo para instalar APKs. Instalacao de APK e apenas uma capacidade dentro de um cliente Android mais amplo.

A tese correta do produto e:

> o terminal movel do Codex Bridge

Isso implica uma mudanca de desenho:

- de utilitario isolado
- para cliente oficial do ecossistema

## Funcao do Mobile

O Mobile existe para reduzir latencia de decisao humana sem tentar reproduzir o ambiente completo de desenvolvimento.

Pergunta de produto:

> isso ajuda o operador a decidir, acompanhar, revisar, autorizar ou coletar contexto longe do computador?

Se sim, tende a caber no aplicativo.

Se exige edicao pesada, navegacao tecnica complexa ou fluxo longo de implementacao, tende a permanecer no desktop.

## Regra de Escopo

### Entra

- aprovacoes
- acompanhamento
- revisao
- conversas
- artefatos
- instalacao de APK
- leitura assistida de arquivos escolhidos pelo usuario

### Nao entra

- IDE movel
- edicao pesada de codigo
- substituicao do ambiente desktop
- automacoes que pedem acesso irrestrito ao aparelho

## Objeto Central

O principal objeto de experiencia nao e o arquivo, nem a tela, nem o agente isolado.

E a decisao operacional humana dentro de um fluxo de desenvolvimento distribuido.

Por isso, o Centro de Decisoes e as Missoes devem orientar arquitetura, navegacao e notificacoes.

## Implicacoes para o desenho tecnico

- dados precisam ser sincronizaveis e funcionais offline
- contexto precisa ser resumivel e acionavel
- permissoes do aparelho devem ser granulares
- toda acao critica precisa ter trilha de auditoria
- o app deve privilegiar comandos curtos e leitura rapida

## Implicacoes para roadmap

Primeiro vem operacao e governanca.

Depois vem conveniencia local do Android.

Nao o contrario.
