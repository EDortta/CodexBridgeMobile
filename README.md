# Codex Bridge Mobile

Codex Bridge Mobile e o cliente Android oficial do ecossistema Codex Bridge.

Ele nao existe para transformar o telefone em uma IDE nem para ser "um app de instalar APK". Ele existe para colocar o operador humano no centro da execucao distribuida: acompanhar, autorizar, revisar, discutir e destravar trabalho mesmo longe do computador.

## Posicionamento

Se o Codex Bridge e o centro de comando, o Mobile e a presenca dele no bolso.

O aplicativo complementa o desktop. Seu foco e:

- aprovar
- acompanhar
- revisar
- conversar
- instalar
- coletar informacoes

Seu foco nao e:

- substituir o computador
- editar codigo de forma pesada
- virar uma IDE
- ampliar escopo so porque o dispositivo e movel

## Visao do Produto

> Codex Bridge Mobile e o cliente Android oficial do ecossistema Codex Bridge, permitindo acompanhar, autorizar, revisar e colaborar em projetos de desenvolvimento mesmo longe do computador.

## Dominios Principais

O produto se organiza em oito dominios.

### 1. Sessoes

Permite observar execucao em andamento:

- agentes ativos
- worktrees
- branches
- tarefas em execucao
- tempo de execucao
- consumo aproximado
- ultimo log

Cada sessao precisa aceitar interacao curta e objetiva, por exemplo:

- `Pare`
- `Continue`
- `Explique esse erro`

### 2. Issues

Este tende a ser o modulo operacional principal.

Capacidades esperadas:

- criar Epic
- discutir Epic
- quebrar Epic em Issues
- revisar Issues
- aprovar planejamento
- mandar implementar
- cancelar
- repriorizar

Toda a interacao deve continuar conversacional.

### 3. Conversas

Historico persistente de discussoes vinculadas a contexto real:

- projeto
- Epic
- Issue
- dominio

O objetivo e impedir que decisoes fiquem dispersas em canais informais.

### 4. Aprovacoes

Fila operacional de tudo o que exige julgamento humano:

- novo dominio detectado
- alteracao de contrato
- expansao de escopo
- merge
- deploy

Esse dominio converge no conceito de Centro de Decisoes.

### 5. Artefatos

Entrega, consulta e download simples de:

- APK
- PDF
- Markdown
- diagramas
- imagens
- builds
- logs
- relatorios

### 6. Android

Modulo especifico do aparelho, nao o produto inteiro.

Responsabilidades iniciais:

- receber APK
- validar assinatura
- baixar
- pedir instalacao
- mostrar changelog
- manter historico

### 7. Arquivos

Integracao com Storage Access Framework para acesso consentido e restrito.

O usuario escolhe pastas e arquivos relevantes, por exemplo:

- Downloads
- Documents
- Livros
- Markdown
- Projetos

O Bridge pode entao solicitar acoes como:

- analisar este PDF
- ler este Markdown
- comparar estes documentos

### 8. Configuracoes

Configuracao operacional do cliente:

- servidor
- usuario
- autenticacao
- projetos favoritos
- agentes preferidos
- notificacoes
- LLM preferido
- permissoes

## Missoes

O aplicativo precisa de um conceito mais forte que "lista de tarefas": Missoes.

Uma missao acompanha um trabalho longo, como "Resolver Issue 314", e organiza:

- planejamento
- implementacao
- testes
- validacao
- documentacao
- tempo gasto
- agente responsavel

O operador deve conseguir acompanhar a missao quase como um GPS de execucao.

## Centro de Decisoes

Este e o diferencial central do produto.

Aprovacoes hoje aparecem espalhadas. No Mobile, tudo o que exige julgamento humano precisa convergir para um unico lugar:

- merge
- novo dominio
- contrato
- deploy
- credenciais
- instalacao de APK
- expansao de escopo

Cada decisao deve apresentar:

- contexto resumido
- impacto
- riscos
- recomendacao do agente
- evidencias

Acoes padrao:

- Aprovar
- Rejeitar
- Pedir revisao
- Discutir

Isso transforma interrupcoes isoladas em uma experiencia de operacao deliberada.

## Navegacao

O aplicativo deve evitar proliferacao de telas. A navegacao base proposta e de quatro abas:

### Projetos

Visao organizada por projeto.

### Trabalho

Issues, Missoes e Sessoes.

### Conversas

Chat, historico e discussoes.

### Conta

Configuracoes, servidor e permissoes.

## Notificacoes Inteligentes

O app nao deve gerar ruido. Apenas eventos de alto valor operacional:

- a implementacao precisa de aprovacao
- os testes falharam
- foi detectado risco de contrato
- APK disponivel
- merge aguardando

## Offline

Sem conectividade, o aplicativo ainda precisa ser util. Exemplos:

- ler documentacao sincronizada
- revisar uma Issue
- escrever comentarios
- aprovar rascunhos locais

Ao recuperar conexao, sincroniza.

## Seguranca

Requisitos basicos:

- nao guardar tokens permanentes em texto
- usar Android Keystore sempre que aplicavel
- preferir OAuth e sessoes renovaveis
- suportar revogacao remota

## Voz e Operacao Remota

O produto pode evoluir para um controle remoto do desenvolvimento.

Fluxo esperado:

1. O operador pergunta por voz sobre um projeto ou missao.
2. O aplicativo responde com estado resumido e riscos.
3. Quando houver decisao pendente, o aplicativo pergunta objetivamente.
4. O operador responde com uma acao curta, como autorizar, parar ou adiar.

Esse modelo e mais coerente com o uso movel do que qualquer tentativa de portar uma IDE para o Android.

## Papel no Ecossistema

Os projetos se encaixam assim:

- AI-Agents define a politica de trabalho
- GovernanceKit instala, valida e fiscaliza a politica
- Codex Bridge orquestra agentes, contexto, execucao e governanca
- Codex Bridge Mobile coloca o operador no centro das decisoes

O Mobile deve ser tratado como a interface humana do processo de desenvolvimento distribuido.

## Recorte Inicial Recomendado

Um MVP coerente com essa visao deve priorizar:

1. autenticacao segura e conexao com o servidor
2. lista de projetos e estado resumido
3. Centro de Decisoes
4. Missoes e Issues em modo acompanhamento/revisao
5. Conversa curta com sessoes/agentes
6. Artefatos com foco em APK, logs e Markdown
7. modulo Android para recebimento e instalacao de APK

Tudo que parecer IDE movel deve ficar fora do primeiro ciclo.

## Desenvolvimento

Toolchain validado para este projeto:

- Flutter 3.44.8
- Dart 3.12.2
- Android application ID: `com.edortta.codexbridge.mobile`

Com o SDK instalado em `/opt/flutter`, execute:

```bash
export PATH=/opt/flutter/bin:$PATH
flutter doctor -v
flutter analyze
flutter test
flutter build apk --debug
```

GitHub Actions executes the same dependency resolution, analysis, test, and
debug APK build checks for every pull request.
