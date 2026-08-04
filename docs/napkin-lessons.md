# Napkin Lessons Learned

- [2026-08-03] WK-20260803-gh-18-configure-primary-navigation - A test for
  "state survives a tab switch" passes just as happily against a shell that
  never preserved anything, because the widget is rebuilt either way.
- Action next time: Break the mechanism on purpose and watch the test fail
  before trusting it — here, forcing `goBranch(initialLocation: true)`.

- [2026-08-03] WK-20260803-gh-18-configure-primary-navigation - Session-close is
  not atomic: a dropped connection left napkin-lessons, the issue file, and
  RESUME.md updated while `handoff.md` — the only file that narrates what
  happened — was still missing.
- Action next time: Write the `handoff.md` entry first at session close, then
  the derived artifacts; the recoverable state is worth more than tidy ordering.

- [2026-08-03] WK-20260803-gh-19-riverpod-feature-boundaries - Repository
  replacement stays local to tests when widgets depend on feature state, not data adapters.
- Action next time: Override the feature repository provider in a `ProviderScope`.

- [2026-08-03] WK-20260803-gh-17-material-3-design-system - Typography that
  represents distinct operational meanings needs a ThemeExtension; the Material
  text scale alone cannot identify code or log content.
- Action next time: Keep visual semantics central and test their presence in both
  theme variants before adding feature screens.

- [2026-08-03] WK-20260803-gh-20-configure-quality-ci - A workflow that exists
  locally is not proof that GitHub ran it or that a branch is protected.
- Action next time: Validate syntax and equivalent local commands now; report
  remote execution and branch-protection state separately until a push occurs.

- [2026-08-03] WK-20260803-gh-16-initialize-flutter-project - A generated
  Flutter Android build can inherit a broken host NDK even with no native
  project code.
- Action next time: Pin a verified side-by-side NDK in the Android module and
  prove the APK build before treating the SDK setup as ready.

- 2026-07-27: A declared reserve must reduce usable budget; a zero-use category does
  not reserve anything. Name task and risk contract costs independently so telemetry
  explains where policy tokens are spent.

- 2026-07-27: Measure canonical rules before choosing a context budget. The base is
  about 7.2k tokens and implementation adds about 8k; a 12k ceiling would weaken the
  contract. Keep mandatory documents atomic and save tokens by excluding unrelated
  roles/history rather than truncating rules.

Short, practical lessons captured at session close.
Keep each lesson concise and actionable.

## Entry format
- `[YYYY-MM-DD] <work_id> - <lesson>`
- `Action next time: <specific behavior to repeat/avoid>`

## Entries
- `[2026-05-07] WK-20260507-personal-touch-1.0.2 - Cursor ignores chain-loaded files; tool adapters must be self-contained to be effective.`
- `Action next time: Write .cursorrules to cover start gate, hard rules, session-close format, quality gates, and branch rules — no chain-loading assumption.`
- `[2026-05-07] WK-20260507-personal-touch-1.0.2 - USER.md is a global user-level file (~/.config/USER.md); never put it in the project repo or the install script.`
- `Action next time: Document the convention in README and all adapter files; keep it optional so the kit works without it.`
- `[2026-05-04] WK-20260504-low-token-contract-v2 - Keep root contracts as dispatchers and move detailed behavior to role/workflow docs to reduce repeated context.`
- `Action next time: Preserve hard gates in AGENTS.md, but push task-specific detail behind explicit load rules.`
- `[2026-05-04] WK-20260504-low-token-contract-v2 - Upgrade paths must preserve target-local context while replacing managed directories so removed kit files disappear.`
- `Action next time: Test fresh install and upgrade separately before declaring installer behavior safe.`
- `[2026-05-11] WK-20260511-php-delphi-audit-capability - When adding language support to the kit, mirror the exact output format of the existing reference (typescript-audit.md) — teams can then compare maturity scores across languages on the same scale.`
- `Action next time: Always produce the new audit workflow file first, then update programmer.md and reviewer.md; the workflow file is the source of truth that informs what rules belong in the contracts.`
- `[2026-05-11] WK-20260511-php-delphi-audit-capability - A real audit run (YeAPF2, 86 files, PHP 5.5/10) revealed that tooling baseline (PHPStan, CS-Fixer) is the single highest-leverage item: installing it costs 1 hr and gates all other type-safety improvements.`
- `Action next time: Lead audit recommendations with tooling setup, not code changes — without PHPStan, devs have no feedback loop to sustain improvements.`
- `[2026-07-01] WK-20260701-dotdocs-kit-layout - A path sweep by prefix (docs/agents etc.) misses bare directory args in shell examples (cp -r AI-Agents/docs) and links prefixed with ./ that a negative-lookbehind guard skips; adversarial skeptics caught 3 such stragglers in tutorials.`
- `Action next time: After a mechanical rename sweep, run a second grep for the bare token (word 'docs' as a path arg, './docs', 'AI-Agents/docs') — not just the prefixed forms — and verify with an independent reviewer.`
- `[2026-07-01] WK-20260701-dotdocs-kit-layout - A migration that auto-promotes files must never claim 'complete' when conflicts strand items, and must never rm -rf an existing backup.`
- `Action next time: Track a conflict counter, print an honest finished-with-N-conflicts message, and pick a free backup name (bak, bak-1, ...) instead of clobbering.`
- `[2026-07-02] WK-20260702-branch-ascii-and-identity - A branch named "development" (quotes part of the ref) corrupted tooling because issue titles were passed near-raw to git; contracts had no character allow-list.`
- `Action next time: Whenever a helper can create a ref, validate against ^[a-zA-Z0-9/_-]+$ before touching git, and document the same rule in AGENTS.md so agents sanitize slugs before checkout -b.`
- `[2026-07-02] WK-20260702-branch-ascii-and-identity - Shared governance docs on a shared branch hide host-level collisions (two hosts commit on the same branch, ports clash) because nothing individualizes the instance.`
- `Action next time: Mandate a per-instance identity file (operator/host/paths/ports/branch_ownership) read before acting, with a same-branch guard, and split shared vs individual artifacts explicitly.`
- `[2026-07-07] WK-20260707-sec-standards-hardening - ~296 catalogued vulns + 11 per-project SECURITY-ALERTs + napkin lessons across kit projects surfaced ~13 recurring classes the 8-section security-standards did not explicitly name (path-traversal/SSRF, SQL/shell injection, disabled TLS verify, weak crypto/token lifecycle, fail-open authz, secrets/PII in URLs/logs/synced dirs, mutable-ref supply chain, commit-only enforced by prompt goodwill only, prompt-injection auto-actions).`
- `Action next time: Harvest ecosystem SEC-* + napkin lessons, classify against the current standards sections, and open ONE epic (docs/issues) with a task per gap that proposes concrete rule text + notes doctor-automatability — do not edit the standard directly; let the operator approve each rule. Kit files must use Esteban, never a real name (the SEC-0102 anti-reintroduction gate this epic itself codifies).`
- `[2026-07-08] WK-20260708-deploy-gw-hub-vm - Dois planos do mesmo alvo (192.168.7.200) divergiam em topologia (1 VM vs 3 LXCs) E um deles se auto-contradizia: a intro dizia "caixa ociosa, operador aprovou wipe" mas a própria seção de descobertas listava infra VIVA (nginx :80 servindo /enviar-arquivo/, túnel :2203, OpenVPN, DHCP) com gate de limpeza ainda aberto.`
- `Action next time: Antes de gerar issues de deploy, ler os planos companheiros por inteiro e cruzar a intro com as seções de descobertas — a premissa do topo pode estar desatualizada. Escolher a topologia ADITIVA (VM isolada) quando ela evita reabrir um gate destrutivo, e escrever a lista de infra-intocável como pré-flight explícito na issue de runbook, não só na cabeça.`
- `[YYYY-MM-DD] WK-YYYYMMDD-example - <lesson learned>`
- `Action next time: <what to do differently>`
- `[2026-07-16] WK-20260716-ai-issues-sweep - Uma issue afirmava "lógica testada por unit (start/end/underflow/guard)" e o repositório não tinha teste nenhum — nem suíte, nem pytest, nem tests/. A afirmação falsa é pior que a ausência: aposentou o risco na cabeça de todo leitor seguinte, inclusive na minha, até eu ir olhar.`
- `Action next time: Antes de escrever "testado" em issue/commit/handoff, nomear o arquivo e mostrar a execução; caso contrário escrever "not validated: <o quê>". Reviewer trata claim-sem-arquivo como BLOCKER (design-standards.md §1).`
- `[2026-07-16] WK-20260716-ai-issues-sweep - O guard in-flight foi posto no chamador (um ramo do watchdog) enquanto o SIGKILL morava em _kill_stale_chrome(); e o reaper poupava só o PID pai do Chrome. O processo que o log da issue mostra morto (pid=3568219 age=376s cpu=37.9%) era um renderer FILHO — velho, quente e oculto, os três critérios de kill. O guard escondia o sintoma; a proteção não cobria o que dizia cobrir.`
- `Action next time: Guard vai DENTRO da operação perigosa, não ao lado do chamador que hoje sabe dele. E quando a proteção fala de "um processo", perguntar se ela cobre a árvore — renderers são filhos.`
- `[2026-07-16] WK-20260716-ai-issues-sweep - No cache de markdown, store() era à prova de falhas e lookup() não: um erro de leitura derrubaria a requisição que o cache existe para acelerar. Robustez assimétrica lê como robusta e não é.`
- `Action next time: Promessa transversal ("nunca levanta", "nunca quebra a request") vale em TODOS os pontos de entrada do módulo, não só no que foi revisado. Escolher a direção do fail de propósito: fechado para auth/segredo, aberto para cache/telemetria.`
- `[2026-07-16] WK-20260716-git-remote-bare-self-hosted - O installer do kit tem DOIS caminhos de cópia (upgrade na linha ~312 e instalação nova na ~366). Adicionar o script novo só no primeiro fazia uma instalação limpa não receber o gbr — e o teste de instalação foi o que pegou.`
- `Action next time: Ao adicionar arquivo distribuído pelo kit, grepar o installer pelo vizinho (agent-worktree.sh) e cobrir TODAS as ocorrências; depois rodar o installer de verdade num alvo limpo E um --upgrade sobre ele.`
- `[2026-07-17] WK-20260717-solid-council - Completar um framework conhecido (as letras faltantes de SOLID) empurra para criar seção por letra. Mas a Provenance é POR SEÇÃO: OCP como §8 obrigaria o chrome_op_guard() morto a aparecer na Provenance de §7 E §8 — um incidente lendo como dois — ou §8 nasceria sem provenance, que é a decoração que o §0 condena. Inflar evidência num arquivo cuja tese é honestidade é pior do que a lacuna.`
- `Action next time: Ao acrescentar regra a um arquivo com Provenance, achar primeiro QUAL incidente já registrado a ancora, e pôr a regra na seção desse incidente. Se nenhum ancora, a regra é preventiva: entra como IMPROVEMENT e a Provenance diz "preventiva, sem incidente; candidata a remoção se nunca pegar nada". Nunca MANDATORY sem incidente.`
- `[2026-07-17] WK-20260717-solid-council - O kit tinha um instrumento que funcionou e sumiu: 3 adversarial skeptics na epic 002 renderam 6 findings, todos corrigidos e retestados — e viraram nota de rodapé no handoff, nunca contrato. Um instrumento sem contrato não roda de novo; ele vira anedota que prova que o trabalho era bom.`
- `Action next time: Quando uma técnica ad-hoc render resultado real, o session-close pergunta "isto vira contrato?" antes de virar só evidência retroativa no handoff. E ao contratualizá-la, achar o arquivo vizinho que trata o caso OPOSTO (aqui: governance-precedence trata papéis que discordam; o concílio trata ninguém discordar) e escrever a fronteira em tabela — senão os dois brigam pelo mesmo gatilho.`
- `[2026-07-17] WK-20260717-solid-council - Escrevi um contrato (council.md §4) cujo trigger MANDATORY "mudança em contrato kit-owned que propaga para outros repos" descreve exatamente o épico que o estava criando. O contrato pede um concílio sobre si mesmo, e eu não rodei.`
- `Action next time: Depois de escrever um gate, reler os próprios triggers contra o trabalho em curso ANTES do session-close — se o gate novo se aplica ao commit que o introduz, ou roda, ou a exceção fica escrita no handoff. Um gate que o próprio autor pula na estreia ensina que ele é opcional.`
- `[2026-07-23] WK-20260723-agents-md-protegido - O kit já tinha a proteção certa (sync_dir: manifesto + sha256 + stash em .gk/overwritten/) e ela não alcançava os arquivos de RAIZ, que passam por copy_file_replace — um cp -a seco. Passei a issue inteira achando que ia projetar um mecanismo; o trabalho real era ligar o mecanismo existente num segundo caminho de código.`
- `Action next time: Antes de desenhar proteção nova, grepar o repositório pela proteção que já resolve o caso vizinho. Dois caminhos de cópia no mesmo instalador já mordeu antes (WK-20260716: gbr só no caminho de upgrade) — quando um arquivo tem mais de um caminho de escrita, a pergunta é sempre "os dois foram cobertos?".`
- `[2026-07-23] WK-20260723-agents-md-protegido - A proteção funcionava e o write_manifest a desfazia: ele grava o hash do que está em disco, e o disco tem a versão do PROJETO quando o arquivo é preservado. O manifesto passaria a dizer "conteúdo intocado do kit" e o upgrade SEGUINTE apagaria tudo. Perda idêntica, um turno depois — e o teste de um upgrade só passa verde.`
- `Action next time: Ao adicionar um caminho "preserva em vez de escrever", perguntar o que o registro de estado grava depois dele. E testar a operação DUAS vezes seguidas: proteção com estado só se prova no segundo ciclo, nunca no primeiro.`
- `[2026-07-23] WK-20260723-agents-md-protegido - O --check reportou "No drift" em 20 alvos reais, incluindo o jk-structure que MOTIVOU a issue. Ele iterava as chaves do manifesto; arquivo ausente do manifesto era invisível — enquanto o upgrade trata ausência como fail-closed e preserva. Relatório e comportamento discordavam, e o relatório era o otimista: dizia "pode subir" sobre exatamente os alvos onde o upgrade pararia. Causa raiz: a lista de arquivos de raiz existia em três lugares e uma delas divergiu.`
- `Action next time: Um relatório dry-run tem que percorrer a MESMA lista e a MESMA tabela de decisão que a operação real — de preferência a lista literal compartilhada, não uma reconstrução. E quando o dry-run contradiz o que a issue afirma sobre um alvo conhecido, o suspeito é o dry-run, não a issue: ir olhar o alvo antes de acreditar no verde.`
- `[2026-07-23] WK-20260723-agents-md-protegido (Parte 3, planejamento) - Ia construir uma allowlist de tokens para distinguir o placeholder Esteban do vocabulário de conteúdo [MANDATORY]/[PROHIBITED]/[DEFAULT], que compartilham a forma [MAIÚSCULA]. O operador propôs mudar o delimitador para {{TOKEN}}; verifiquei que {{ e ${{ não ocorrem no kit. A ambiguidade que exigia a allowlist simplesmente evaporou — {{...}} é sempre slot, [...] é sempre conteúdo. Detecção vira sintática, sem lista para manter.`
- `Action next time: Quando a detecção precisa de uma allowlist para separar sinal de ruído que TÊM a mesma sintaxe, perguntar antes se dá para trocar o delimitador e deixar a própria sintaxe carregar a distinção — costuma ser mais barato e mais robusto que manter a lista. Confirmar que o novo delimitador tem namespace vazio (grepar por ele e pelas variantes vizinhas, ex. ${{ do GitHub Actions) antes de adotar.`
- `[2026-07-24] WK-20260723-agents-md-protegido (Parte 3) - Adotei {{...}} como sintaxe de slot e escrevi, na própria prosa que explica a convenção, o token genérico {{TOKEN}} literal. Isso teria (a) sido substituído junto com os slots de verdade, colocando o nome real do operador exatamente no parágrafo que manda mantê-lo fora dos arquivos rastreados, e (b) feito o grep do Start Gate acusar o arquivo para sempre. Só apareceu porque rodei o cenário 1 num alvo sintético em vez de confiar no bash -n.`
- `Action next time: Documentação de um mecanismo de substituição não pode escrever o padrão substituível literalmente — usar uma grafia que o motor comprovadamente não casa ({{…}} com reticências Unicode, aqui) e travar isso com uma checagem, porque a próxima pessoa vai escrever o literal de novo por ser mais legível. Vale para qualquer template engine, não só este.`
- `[2026-07-24] WK-20260723-agents-md-protegido (Parte 3) - Depois do --migrate, o arquivo É a versão renderizada do kit, mas o manifesto ainda guardava o hash pré-migração — e o copy_file_replace, que julgava só pelo manifesto, marcava como deriva um arquivo byte a byte idêntico ao que estava prestes a escrever, pedindo merge do arquivo contra ele mesmo. A regra que faltava era trivial: dst == src, não há o que preservar nem o que reportar.`
- `Action next time: Quando a decisão depende de um registro de estado (manifesto, lockfile, cache de hash), comparar ANTES com a realidade que está à mão — se origem e destino são idênticos, o registro é irrelevante e não deve poder produzir um veredito. Registro de estado envelhece; comparação direta, não. E a regra tem que entrar no dry-run e na operação real ao mesmo tempo, senão eles voltam a discordar.`
- `[2026-08-04] WK-20260804-gh-1-introduce-app-layer - O critério de aceite da épica dizia "analyze e test passam na CI" e cinco issues foram fechadas com "analyze limpo, test verde" — tudo local. O workflow existia, estava correto e pinado por SHA, e nunca havia rodado: ele dispara em pull_request/workflow_dispatch, e a fase inteira foi integrada por merges locais. `gh run list` vazio não é "não achei", é "nunca rodou"; e `gh workflow list` também vinha vazio porque lista os workflows do branch PADRÃO, e o arquivo só existia em development. Ausência de sinal lia como verde por três sessões.`
- `Action next time: Quando o critério disser "na CI", provar com a URL do run e o conclusion — nunca com execução local. E ao criar o workflow, cruzar os triggers com o modo real de integração do projeto: se o time faz merge local em development e o gatilho é só pull_request, o CI é decorativo e nunca falha, que é pior do que não existir.`
- `[2026-08-04] WK-20260804-gh-1-introduce-app-layer - O escopo pedia "criar estrutura app/, core/ e features/" e a leitura literal (mover todo core/navigation/ para app/) inverteria a dependência: quatro telas de feature importam AppDestination/AppRoutes para navegar, então elas passariam a depender do composition root — exatamente a fronteira que a issue #18 tinha estabelecido. O grep de imports respondeu em um comando o que o nome do diretório não dizia.`
- `Action next time: Item de escopo que nomeia diretório é sobre fronteira, não sobre nome. Antes de mover, grepar quem importa cada arquivo do conjunto e separar o que é contrato compartilhado (fica em core/) do que é composição (vai para app/); se o move faz uma camada de baixo importar uma de cima, o move está errado por mais que case com o texto da épica.`
- `[2026-08-04] WK-20260804-phase-1-auth-and-connection - Ia propor um contrato de API inventado (GET /api/health com shape meu) porque o software-overview diz que "o backend é dependência externa, não operada por este repositório" — li isso como "não há spec". O operador respondeu "revisa de novo, acabo de criar issues em CodexBridge": o épico EDortta/CodexBridge#1, com 14 issues, incluía a #3 fixando GET /health, GET /ready e GET /api/version, criada horas antes. O contrato autoritativo existia, num tracker que eu não olhei.`
- `Action next time: Antes de assumir contrato de dependência externa, listar as issues do repositório DELA (gh issue list -R owner/repo) e procurar o épico de API — "externo a este repo" descreve quem opera, não onde a spec mora. E quando a spec existe mas está incompleta (paths fixados na #3, shape só na #2 ainda não escrita), a decisão certa não é inventar o resto: é exigir só os campos que a issue já garante e ignorar desconhecidos, para o contrato final não quebrar o cliente.`
