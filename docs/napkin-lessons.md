# Napkin Lessons Learned

- [2026-08-20] WK-20260820-gh-28-mission-detail-timeline-and-controls
  (retroactive reviewer + council pass) - #28 shipped in the previous
  session's entry below with no review step at all — `council.md` is
  explicit that it only runs on work `./reviewer.md` already approved, and
  #28 had never been through that gate. Running `reviewer.md` first (not
  skipping straight to council) surfaced two real findings the original
  session missed: `Mission.copyWith` could silently produce a `blocked`
  mission with no `blockedReason` (the class's own doc comment already
  claimed the opposite direction of that invariant — auto-clear on exit —
  without enforcing entry), and `MissionDetailScreen`'s not-found/generic
  error branches had zero test coverage. Only after both were fixed and
  green did the council round run, and it found something a straight
  reviewer pass would plausibly not have looked for: `_CurrentMissionCard`
  (#24's dashboard) still linked to the bare Work destination instead of
  carrying `?mission=<id>` the way #28's own `_MissionCard` now does — a
  second call site of the same "tap a mission summary -> see its detail"
  mechanism, left behind. The council's other finding was a genuine
  concurrency bug in `MockMissionRepository`: `pause`/`resume`/`cancel`
  read the current mission via `await loadMission(...)`, and that `await` —
  even against an already-resolved Future — still yields to the microtask
  queue, so two calls issued back-to-back (no `await` between them) could
  both observe the pre-mutation state, both "succeed", and the second would
  silently overwrite the first's update. Reproducing it needed no real
  concurrency, just two unawaited calls in the same test body — and finding
  it needed no exotic tooling, just tracing the exact `await`
  `design-standards.md` §2 already warns "clock/randomness/network arrive
  through a parameter" is really about: an `await` that looks harmless
  because the mock has no real latency is still a real yield point.
- Action next time: When a delivery shipped without a review step (check
  its own DoD checklist — an unchecked "Operator review"/"Council pass" box
  is the tell), do not run the council directly against it even if asked
  for "a council pass" in isolation — `council.md` itself says it is not a
  second review, and running it on unapproved work just makes it a review
  with extra ceremony. Run `reviewer.md` straight first, fix to APPROVED,
  *then* council. Also: when a synchronous-looking mock method has any
  `await` at all — even one that resolves instantly — do not assume it is
  race-free; write the "two unawaited calls" test once per mutating method
  that reads its own state back through an `await` before writing it, the
  same way this session did for `pause` (and would extend to any future
  mutating method built the same way).

- [2026-08-20] WK-20260820-gh-28-mission-detail-timeline-and-controls - An
  overnight cloud routine (`RemoteTrigger`, armed at the close of the #27
  session for #28/#29) was checked the next session and had produced
  nothing — no branch, no PR, no issue comment, well past its scheduled
  fire time. The `RemoteTrigger` tool itself was not loadable in the
  resuming session (`ToolSearch select:RemoteTrigger` found no match), so
  the routine's own run log could not be read to learn why. The absence of
  any artifact was still conclusive enough to act on without the log: no
  branch/PR/comment means no work happened, regardless of cause.
- Action next time: Do not treat "the routine was armed" as equivalent to
  "the routine ran." A session that resumes after an armed unattended run
  must check for concrete artifacts (branch, PR, issue comment) first, and
  treat their total absence as sufficient grounds to fall back to manual
  pickup — do not block on inspecting the run log if the tool that reads it
  is unavailable in the resuming session; note the gap and move on. Also
  worth an operator check outside any single session: confirm from
  `https://claude.ai/code/routines` whether a routine that produced nothing
  is still enabled, errored, or was silently disabled — a session with no
  `RemoteTrigger` access cannot self-diagnose that.
- [2026-08-19] WK-20260819-gh-27-missions-list-and-lifecycle-model - Wrote
  "Epic #3's remaining issues (#25 decision inbox/filters, #26 decision
  detail, #29/#30 epics/issues browser, #35/#36 artifacts)" into
  `phase-2/RESUME.md` from memory of the epic numbering, without checking.
  All four were wrong: #25/#26 are Epic #4, #29/#30 are Epic #6, #35/#36 are
  Epic #9 — and Epic #3 was already fully done (#23/#24 were its only two
  issues). The mistake propagated once before being caught (had to be
  corrected twice, in two different sessions/commits).
- Action next time: Never state an issue's parent epic from memory or
  pattern-matching on nearby issue numbers. Run
  `gh issue view <n> --json body -q '.body'` (the body's first line is
  always `Parent epic: #N`) for every issue before writing which epic it
  belongs to, especially before picking "the next appropriate issue" — a
  wrong epic assignment doesn't just mislabel a doc, it can pick the wrong
  next issue entirely.

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

- [2026-08-06] WK-20260806-phase-0-council - O `grep -r` deste ambiente é uma
  função que exec um binário ugrep-compatível com `--ignore-files`, então ele
  respeita o `.gitignore` — e os 8 arquivos que carregam o contrato de leitura
  (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, `.windsurfrules`,
  `.github/copilot-instructions.md`, `.amazonq/`, `handoff.md`) são justamente
  gitignored pelo kit. A varredura do move `.docs/` → `docs/` feita do jeito
  óbvio reportou limpo e escondeu 20 das 23 referências quebradas.
- Action next time: Para varredura de path, enumerar os arquivos explicitamente
  (`find . -type f -print0 | xargs -0 grep -In <padrão>`) ou usar `command grep`;
  nunca confiar num `grep -r` limpo num repo cujo `.gitignore` cobre os próprios
  contratos. E cruzar o resultado recursivo com um `grep -c` por arquivo conhecido
  antes de declarar a varredura completa.

- [2026-08-06] WK-20260806-phase-0-council - Pôr os ignores do projeto (`.env`,
  `build/`, `.dart_tool/`) DENTRO do bloco `# AI-Agents kit … # end` fez uma
  reescrita do bloco levá-los junto: 711 untracked e `.env` deixando de ser
  ignorado, no repo cujo `limits.md` proíbe segredo em qualquer artefato.
- Action next time: Tudo que é do projeto vai FORA de bloco gerenciado por
  ferramenta — o bloco é território de quem o reescreve. Depois de qualquer
  upgrade de kit, rodar `git check-ignore -v .env build/ .dart_tool/` antes de
  qualquer `git add`.

- [2026-08-06] WK-20260806-phase-0-council - Provar o build só com
  `flutter build apk --debug` esconde exatamente o que o template Flutter deixa
  para o desenvolvedor: `INTERNET` só existe nos manifests de debug/profile, e
  `release` assina com a debug keystore. A Phase 0 declarou o build "provado" com
  a única variante que não expõe nenhum dos dois.
- Action next time: Quando o gate prova uma variante de build, escrever quais
  variantes ele NÃO prova e o que cada uma resolve de forma diferente (merge de
  manifest, assinatura, R8). Antes da primeira feature de rede, conferir o
  manifest `main/`, não o mergeado do debug.

- [2026-08-06] WK-20260806-phase-0-council - O concílio rodou violando o próprio
  §5: o gate manda ler `.docs/software-overview.md` e parar se não estiver pronto,
  o arquivo tinha sido movido para `docs/`, e eu li do lugar novo e segui. O gate
  que existe para impedir o concílio de adivinhar as próprias lentes virou path
  pendurado e falhou ABERTO.
- Action next time: Quando um `[MANDATORY]` aponta para um arquivo que não existe
  mais, isso não é divergência de path a anotar de passagem — é o gate falhando.
  Parar, dizer, e só então decidir se segue com exceção escrita.

- [2026-08-06] WK-20260806-phase-0-council - Escrevi "o installer é território do
  kit e não é corrigível daqui" e registrei um risco aceito em cima disso. A
  fonte do kit estava um diretório ao lado (`~/Sync/Projects/AI/Agents`), já lia
  `docs/` nas linhas 2070-2071, e trazia `migrate_readiness_files_to_docs()` para
  fazer exatamente a migração que eu tratei como desvio. A cópia vendorizada
  aqui estava 90 linhas atrasada. Confundi "este arquivo é gerado" com "a
  correção está fora de alcance", e o operador pegou perguntando se não estávamos
  na pasta pai dos dois projetos.
- Action next time: Antes de declarar algo não-corrigível ou de escrever risco
  aceito por limitação de ferramenta, achar a FONTE da ferramenta e ler a versão
  dela — `find ~/Sync/Projects -name <arquivo> -not -path <este repo>` responde em
  um comando. Cópia vendorizada com cabeçalho "do not edit" diz onde não editar,
  não que o upstream não tenha resolvido. E comparar `wc -l` das duas: divergência
  de tamanho é o sinal mais barato de cópia velha.

- [2026-08-21] WK-20260821-gh-29-build-epics-and-issues-browser - A precautionary
  `git bundle` sent directly to the operator via chat UI (after `git push` failed
  403/404) was unrecoverable the next session: the operator had "no idea" where it
  went, and a filesystem search (Downloads, `/tmp`, scratchpad, the whole repo tree)
  found nothing. The 5 commits, 41 tests, and clean `analyze`/`test` run that
  session reported were real work, genuinely lost — not recoverable by searching
  harder, only by redoing the issue. Separately, that same session's leftover code
  (`lib/features/planning/`, untracked in the main checkout) carried a doc comment
  claiming CodexBridge #8 was "merged... confirmed 2026-08-20" — `gh issue view 8
  -R EDortta/CodexBridge` this session shows it **open, unimplemented**. The
  recovery task's own briefing repeated the same false claim secondhand.
- Action next time: A bundle or patch meant to survive session loss must land
  somewhere durable and *nameable in the handoff* — a path under the repo's own
  worktree, or a location the operator confirms receiving before the session ends
  — never "sent via chat" as the only copy. And when picking up any claim a prior
  session made about an *external* repo's state ("X is merged", "Y is closed"),
  re-verify it with `gh issue view`/`gh pr list` against that repo directly before
  writing it into a new doc or comment — a stale claim from one session is exactly
  the kind of thing that propagates silently into the next (see also the 2026-08-19
  Epic-numbering lesson above: verify from the source, not from memory of a prior
  session's summary).
- [2026-08-21] WK-20260821-gh-29-build-epics-and-issues-browser - This session's
  own git worktree started 201 files behind `origin/development` (a stale
  `worktree-agent-*` base branch, unrelated to the main checkout) — `ls
  lib/features` inside it showed only 5 directories where `development` actually
  has 10, including a `lib/features/issues/` this session would otherwise have
  missed: a small, already-wired `ProjectIssue{priority}` feature powering
  `_PriorityIssuesCard` on #24's dashboard, easy to mistake for something #29
  needed to create from scratch (the untracked `lib/features/planning/` leftover
  in the main checkout looked like exactly that self-contained new feature).
- Action next time: Before trusting a worktree's checked-out files as "current",
  compare against the real base: `git rev-parse <worktree-branch> <base-ref>` and,
  if they differ, `git ls-tree -r --name-only <base-ref> | grep '^lib/features/'`
  (or recreate the branch fresh off the base, as this session did) rather than
  reading `lib/` off disk. A directory name close to the issue's own vocabulary
  ("issues" for an issues browser) is the first place to look for something to
  extend, and extending it beats a second, competing concept two commits later.

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
- `[2026-08-14] WK-20260814-gh-21-server-configuration - Arvore suja de agente que morreu no meio nao e lixo por definicao. O autopilot recusou arrancar por 14 horas com a mensagem "almost always a parked unit's leftovers", e a leitura obvia era descartar e refazer. Mas o envelope dizia stop_reason tool_use com 77 turnos e US$ 6,86 gastos, e o reboot diario das 20:45 explicava a morte. Rodar analyze e a suite ANTES de decidir custou tres minutos e mostrou 55 testes verdes: o agente tinha terminado o trabalho e morrido na hora de commitar.`
- `Action next time: Diante de sobras de execucao interrompida, primeiro medir o estado (lint, testes, criterios de aceite) e so entao decidir entre terminar e refazer. E ler o envelope da run: stop_reason e num_turns dizem se a morte foi no comeco ou no fim, e isso muda a decisao.`

## 2026-08-14 — council on gh-22 (Implement authentication and session lifecycle)

Two rounds, lenses: the adversarial user, the claim auditor, the second caller, the sweep skeptic.

- raised: 15
- survived §2: 15
- became tests: 15
- questions left open: 27

Questions carried forward:

- [the sweep skeptic] session_screen.dart:1256 states `SessionLifecycle.expired` is "Unreachable while signed in — the controller never leaves an expired session on screen". `_restore` runs once per notifier build, so nothing renews while the app stays open; with `MockAuthGateway.accessLifetime = 1 hour`, leaving the app open past that and returning to the Session screen recomputes `lifecycleAt(now)` on rebuild and would render 'Expired.' under a `SignedIn` state. not reproduced: I did not build a widget test that advances the injected clock and forces the rebuild, and no code path currently presents the access token to a server, so I could not name an outcome worse than a label contradicting its own comment.
- [the sweep skeptic] `MockAuthGateway.renew` carries `refreshExpiresAt` over unchanged while setting `expiresAt: now + 1h`. When the refresh window has under an hour left, it mints a session whose access token outlives its refresh window; `Session.lifecycleAt` then reports `active` (not expired, `needsRenewalAt` true, `isRenewableAt` false falls through to `active`). not reproduced: I did not determine whether that combination is intended to be representable, and the real gateway contract is still unwritten (CodexBridge issue #4).
- [the sweep skeptic] The branch contains no `handoff.md`, `RESUME.md`, `docs/napkin-lessons.md` or issue-doc change — 28 files, all under `lib/` and `test/`. That is the claim auditor's and the process gate's territory rather than mine, and the delivery commit may still be pending; noted only so it is written down. not reproduced: I did not run `governancekit`.
- [the claim auditor] `lib/features/auth/domain/auth_gateway.dart:71` cites "`AGENTS.md` §3b" as the rule behind "Carries no input echo, so a pasted credential cannot reach a screen or a report through it". §3b's own opening sentence says it is "about the agent's own behaviour in the session — distinct from `.docs/agents/security-standards.md` §8, which governs the LLM-facing code the agent *writes*". The code this comment annotates is written code, so the citation points a reader at the section that explicitly disclaims it. Should it be `security-standards.md` instead? (No repro: nothing observable follows from the wrong pointer beyond misdirecting the next reader.)
- [the claim auditor] `lib/features/auth/data/secure_session_store.dart:43` claims "[writeSession] and [clearSession] deliberately keep throwing". `secure_session_store_test.dart` pins only half of that — 'a keystore that refuses a write does not report the session stored' asserts `throwsA` for `writeSession`; no test asserts that `clearSession` propagates. `_clearStoredSession` catching `on Exception` is what makes `sessionMayRemainOnDevice` work, so the claim is load-bearing and only half-pinned. (No repro: the current implementation does propagate; the gap is that nothing would fail if a future edit swallowed it.)
- [the claim auditor] `docs/issues/phase-1/RESUME.md` still reads `status: not_started (planning only)` and "**No branch, no code, no mirror file exists for #21 or #22.**", and `docs/issues/phase-1/README.md` lists both #21 and #22 as "not started", while #21 is merged into `development` and #22 is implemented on this branch. No mirror file for #22 exists under `docs/issues/phase-1/issues/`, and `handoff.md` has no gh-22 entry (`git status` is clean, so nothing is pending). The staleness predates this branch — should the delivery's record be closed before the branch is handed back, or is that deferred to session-close? (Verified by reading the two files and `git ls-tree`; no repro applicable.)
- [the claim auditor] The two commits carry no `work_id` (`WK-YYYYMMDD-<slug>`), which `CLAUDE.md` requires "in planning docs and related commits". The three preceding commits on `development` carry none either, so this is a standing project pattern rather than a regression introduced here — is the rule retired, or is every commit in this repo out of contract?
- [the second caller] `renew()` (auth_providers.dart:117-122) has the same shape as the finding above — it writes `SignedIn(session, renewing: true)` and then `state = await _renew(session)` with no guard against a `signOut()` that lands in between, which would delete the keystore entry and then be overwritten by the renewal's `SignedIn`. Not reproduced: not reachable from today's screen, because both buttons are disabled while `renewing`. Does the fix for finding 1 cover this entry point too, or does it only harden `signIn`?
- [the second caller] `_SessionDetails` reads the clock once per build (`session_screen.dart:177`) and nothing re-evaluates the lifecycle while the app is running: a session that expires with the screen open keeps reading `Status: Active.` and the controller stays `SignedIn` until the next launch or a manual `Renew`. Not reproduced: with no rebuild trigger there is nothing to pump, and no code consumes the access token yet — so the next unit to make an authenticated request is the one that would inherit an expired token from a `SignedIn` state. Is a foreground/resume re-evaluation in scope for #22 or deferred to the HTTP client?
- [the second caller] `signOut()` clears only the session key; the selected server (#21) stays in the keystore. Deliberate (server config is device setup, not identity), or should sign-out be the point where a second caller expects device state to be cleared?
- [the second caller] `docs/issues/phase-1/RESUME.md` still says `status: not_started (planning only)` and `No branch, no code, no mirror file exists for #21 or #22`, on a HEAD that delivers both. Outside my lens (and council §4 requires this round to be recorded there anyway), but the next reader inherits it.
- [the adversarial user] `renew()` (auth_providers.dart:109-114) guards on `SignedIn` but does not exclude `renewing: true`, so it is the same reentrancy hole `signIn` was hardened against in ea6146e, held shut today only by the screen disabling the button. `signIn`'s own doc says the guard is "what keeps that true of the next one" — why does `renew` not get the same treatment? Not reproduced: I found no reachable trigger from the current screen and did not want to manufacture one.
- [the adversarial user] Every lifecycle decision — `isExpiredAt`, `isRenewableAt`, `MockAuthGateway.renew`'s window check — reads the device clock via `sessionClockProvider` (`DateTime.timestamp`). Someone holding the device can set the clock back and an expired, no-longer-renewable session restores as `active`, so `_revoke` never wipes its tokens from the keystore. `session.dart:519` names "a stolen device would hold a session forever" as the threat the refresh window defends against, and that window is governed by a clock the same attacker controls. Not reproduced as a wrong outcome: with the server as the real authority this may be an accepted client-side limit, but it is not written down anywhere I found.
- [the adversarial user] `authGatewayProvider` (auth_providers.dart:64) returns `MockAuthGateway` unconditionally in `lib/`, and it grants a session for any non-blank string. `security-standards.md` §4 says "Mock/demo auth is gated to DEV and excluded from production bundles"; the interim itself is documented (mock_auth_gateway.dart, docs/issues/phase-1/README.md) but the *gate* is not — a `flutter build apk --release` today ships an app anyone signs into. Is a `kReleaseMode` refusal required before an APK leaves this machine, or does `docs/limits.md`'s "local delivery artifact" framing already cover it?
- [the sweep skeptic] The fixes are uncommitted working-tree changes, not commits: `git status --porcelain` shows six modified files and HEAD is still ea6146e, so `git diff development...HEAD` — the artifact this council was pointed at — does not contain any of them. Everything above was verified against the working tree. Which tree is the delivery? If a delivery commit is still to be made, the `governancekit council --record` digest binding in council.md §4 is against a diff that does not yet exist.
- [the sweep skeptic] `SecureServerConfigStore.writeSelectedServer` still throws through `ServerSettingsController.select()` (server_providers.dart:100), which is reached from a fire-and-forget tap handler — the same shape `SecureSessionStore`'s comment calls out as 'a spinner that never stops'. The session side survives it because `_grant` catches at the controller level (auth_providers.dart:250-262); the server side has no equivalent. This is pre-existing #21 code outside finding 3's stated location and I have no failing test for it, so it is a question, not a finding: is the write asymmetry deliberate now that the two features share one `SecureKeyValueStore`?
- [the sweep skeptic] `_signOutGeneration` is consulted only by `renew()`. The other caller of the same gateway-await→`_resolveRenewal` path, `_renew()` at auth_providers.dart:211, is the launch-time renewal reached from `build()` and has no check. I could not build a reachable trigger for it — during `build()` the screen is `AsyncStateView`'s loading state with no buttons — so I am not claiming it as a finding. Is the omission reasoned, or is it the fifth call site the helper did not reach?
- [the sweep skeptic] After finding 7's fix, a relaunch blocked by the pending-removal marker reports `SignedOutReason.neverSignedIn` ('Sign in to link this device to your Codex Bridge account') and no `sessionMayRemainOnDevice`. The `SignedOutReason` set still has no value for 'a session you asked to remove is still on this device', which is the fact the marker exists to record — so the one launch where the operator most needs to know the token is still there is the launch that says nothing about it.
- [the claim auditor] Finding 3's fix guarded readSelectedServer only. SecureServerConfigStore.writeSelectedServer (secure_server_config_store.dart:56) still throws on an unavailable keystore, and round 1 noted 'select() would throw out of a fire-and-forget handler too'. Is that deliberate symmetry with SecureSessionStore.writeSession's documented decision to keep throwing (secure_session_store.dart:66-69), or the same gap one call site further on? No test in the new characterization file covers the write path.
- [the claim auditor] The pending-removal marker (secure_session_store.dart:25) makes a session unreadable but leaves it on the device, and it is never surfaced to the operator: readSession() returns null, so SignedOut carries reason neverSignedIn and sessionMayRemainOnDevice false. Should a launch that finds the marker instead report sessionMayRemainOnDevice: true — which would both tell the truth about what is on the device and re-render the 'Remove from this device' retry that is the only in-app way to clear it?
- [the claim auditor] SignedOut.signingIn has no owner that can clear it if the sign-in never returns. Both the stranded-flag finding above and the pre-existing case of a gateway call that throws end in a spinner with no request behind it. Is signingIn intended to be derived from an in-flight token (a generation counter like _signOutGeneration, or a nullable Future) rather than a boolean any writer of SignedOut may set?
- [the second caller] `signOut()` from `SignedIn` now writes `renewing: true` (auth_providers.dart:178) for the duration of the keystore delete, which renders the same `CircularProgressIndicator` the renewal shows (session_screen.dart:244). Nothing on that screen names it 'renewing' in words, so I could not state an observable wrong outcome and am not filing it as a finding — but the flag is now overloaded to mean 'a renewal or a sign-out is in flight' while its name and its dartdoc still say renewal, and the next reader adding a third operation on a held session will have to rediscover that.
- [the second caller] `_signOutGeneration` protects `renew()` but not `_restore`'s launch-time `_renew()` (auth_providers.dart:206), which awaits the same gateway with no generation capture. A `signOut()` landing during the initial `build()` would be overwritten by the build's own result. I could not reach it from today's screen — `AsyncStateView` renders nothing tappable until the build resolves — and it predates these fixes, so it is a question, not a finding. It is the same 'the guard is what keeps that true of the next screen' standing the author accepted for the signIn guard.
- [the second caller] `readSession()` now makes two platform reads per launch instead of one, and `_hasPendingRemoval()` fails open (`on Exception → false`) while `_read()` fails closed (`on Exception → null`). On a keystore that throws on every read the two cancel out harmlessly today; is failing open the intended direction for the marker if a future caller reads it without a stored session in hand?
- [the adversarial user] Finding 3's fix guards the read path only. `SecureServerConfigStore.writeSelectedServer` still calls the platform store unguarded, and `ServerSettingsController.select()` (server_providers.dart:99) awaits it with no catch, from a fire-and-forget tap handler. Reproduction in the same /tmp/cbm-r2 copy: `select('https://gateway.example.test')` against `UnavailableSecureKeyValueStore` → `select() escaped with: Instance of 'KeystoreUnavailable'`. This is pre-existing (round 1 said so) and not a regression the fixes introduced, so it is not filed as a finding — but the auth side does not behave this way: `writeSession` also throws by design, and `_grant` catches it and renders `SignedOutReason.storageUnavailable` (auth_providers.dart:249-263). The server side has no equivalent, so the operator taps Save and gets silence plus an unhandled async error. Is `select()` meant to report a refused write, and if so, where?
- [the adversarial user] What is the intended lifetime of `codex_bridge.session.pending_removal`? The finding above reads it as an oversight, but if a durable marker is the design, the missing piece is a decision about who clears it: `writeSession` (the session on disk is now one nobody asked to remove), a successful `readSession`, or an explicit reconciliation on launch. Related: should `build()` distinguish 'nothing stored' from 'something stored that we are refusing to restore'? Today both become `neverSignedIn`, which is what suppresses the `sessionMayRemainOnDevice` warning and the removal button on exactly the launch where a token is known to still be present.
- [the adversarial user] `_signOutGeneration` guards `renew()` but not `_renew()` as reached from `build()` (auth_providers.dart:206, 211-216) and not `signIn()`. The `build()` path looks unreachable-by-construction today (state is `AsyncLoading`, so `signOut`'s own `state.valueOrNull` is null) and `signIn`'s case looks intentional — the operator asked to sign in first, and 'Remove from this device' targets the leftover session, not the pending request. Worth stating in the code which of those two it is, so the next caller does not have to re-derive it: the generation check reads as a general cancellation mechanism but is applied at exactly one call site.

- [2026-08-19] WK-20260819-phase-1-reconciliation - The claim auditor flagged this exact staleness twice during gh-22's own council (2026-08-14, "`docs/issues/phase-1/RESUME.md` still reads `status: not_started`... while #21 is merged"), and it was never fixed — gh-32 landed four days later with the same doc still stale, plus 6 commits that were never pushed to `origin` and 4 GitHub issues (#21, #22, #31, #32) that stayed open despite being done. A finding a council raises and closes as "true" is not the same as a finding that gets acted on; nothing forced the fix back into a commit.
- Action next time: When a council finding is about *documentation drift* rather than code, closing it means writing the doc fix in the same delivery, not filing it as accepted-and-understood. And run `.docs/workflows/session-close.md` (push + issue-close + RESUME/handoff update) as a gate on every commit that closes a GitHub issue, not only at the end of a phase — "the branch still has work coming" is not a reason to skip pushing what already landed.

## 2026-08-18 — WK-20260818-gh-32-session-detail-logs-and-controls

- A feature that needs another feature's session or server state cannot read it directly — `test/architecture/layer_boundaries_test.dart` fails the build on any `features/x` importing `features/y`, domain or presentation alike, no exception for "just reading a value". The seam has to be a `core/` provider that defaults to "not configured" (`core/` cannot import a feature either) with the real wiring supplied as a Riverpod override from `lib/app/`, the one layer allowed to import every feature's presentation layer. Added `core/gateway/gateway_context_provider.dart` + `app/gateway_context_binding.dart` as the reusable shape; the next feature that needs an authenticated gateway call should override the same provider rather than inventing its own storage read.
- That seam is not optional scaffolding — going around it (reading `secureKeyValueStoreProvider` directly, by hand-rolled key literals) is what let `live_session_providers.dart` silently bypass `SessionController`'s renewal logic in the first place. The architecture rule and the renewal bug were the same defect seen from two angles.
- `flutter_secure_storage_linux` can block indefinitely on Secret Service/D-Bus when no keyring daemon is running, rather than throwing — a real hang, not a slow call. This is a standing hazard for any caller of `SecureServerConfigStore`/`SecureSessionStore` that reaches a real host-VM `flutter test` without a storage override (both only catch `Exception`, no timeout). It is **not**, on its own, a reason to put a timeout around a *network* call: a first cut of `gateway_context_binding.dart` wrapped both the local storage read and `sessionProvider.future` (which can include a real session-renewal network round trip) in the same 100 ms `.timeout()`. That silently and permanently downgraded a signed-in operator to "not configured" on ordinary renewal latency slower than 100 ms — reproduced with a 150 ms fake renewal, pinned by `test/app/gateway_context_binding_test.dart` (council 2026-08-18, "the adversarial user"). The fix (`_guardStorageRead`) scopes the timeout to the local storage read only; the session read is unguarded, relying on `SessionController`'s own fail-closed behaviour instead. The underlying `SecureKeyValueStore` gap is unfixed at its own layer — the next caller of those two stores from a widget reachable without a storage override in an existing test will still need its own guard or its own test override.
- Fixing a synchronous unguarded lookup by making it `async` (with a network fallback for the case the synchronous version could not handle) can introduce a new race even when the fix itself is correct: `RemoteSessionsController.control()`'s `firstWhere` crash fix added a fallback fetch, which moved the point where `pending`/busy state gets set from "before any `await`" to "after a network round trip" — a gap two rapid taps could land inside, each firing its own duplicate `controlSession(...)` call. The council round that verified the crash fix (round 2) is what caught it, by testing the fix's *own* new code path under concurrency, not just its happy path. The general lesson: turning a sync call into an async one anywhere state-mutating side effects are ordered around it is worth an explicit re-entrancy check, not just a correctness check on the new async path alone.
- Two council rounds is not "run round 1's checklist twice" — round 2 verified round 1's 6 findings (closing 2 that were correct-but-untested, per `council.md` §2's "a test that fails without the fix, or it is a claim, not a closure") *and* found a new, live, reproducible bug in round 1's own fix, with no mutation needed to trigger it. Budget round 2 as real adversarial work against the delivered diff, not a formality.

## 2026-08-21 — WK-20260821-gh-29-pr51-blocked-indicator-fix (council round 2, closing a round-1 finding on PR #51)

- Round 1 flagged that the dashboard's "Priority issues" card (`_IssueListTile`, `lib/app/project_dashboard_screen.dart`) silently drops the blocked indicator #29 introduced project-wide: a `IssueStatus.blocked` issue with a real `blockedReason` (the seeded `fix-development-build`) rendered only an icon, the title and a priority label, while the same issue one tap away through `issues_screen.dart` shows a distinct blocked icon + "Blocked" text. `project_issue.dart`'s own doc comment requires blocked status be "labeled in text, never conveyed by color alone" — the dashboard tile conveyed it by *nothing*, which the round-1 review correctly called strictly worse than color-alone.
- The PR author's original scoping decision (comments in `mock_issue_repository.dart` / `project_issue.dart`: #29 only *adds* fields so the pre-existing dashboard card "needed no changes") was reasonable at the time #29 was scoped, but it left a real, observable convention violation once `IssueStatus.blocked` existed. "No changes needed to compile/pass existing tests" and "no changes needed to honor the project's own written convention" are different claims — round 1 caught that gap between them.
- Fixed rather than risk-accepted: the fix was exactly as small as it looked once in the code — reused `AppIcons.blocked` + a "Blocked" `Text` in `theme.colorScheme.error`, the same pairing `issues_screen.dart`'s `_IssueCard` already established, added above the existing icon/title/priority `Row` in `_IssueListTile`. Also surfaced `blockedReason` in `_IssueDialog`'s detail text for the same reason — the tile only has room to flag the state, the dialog is where the reason belongs. No design invention, no scope creep.
- Regression test (`test/app/project_dashboard_screen_test.dart`, "a blocked priority issue shows the blocked indicator...") pumps the `codex-bridge` project dashboard and asserts the blocked icon/label render for its priority issues, and that the dialog surfaces the reason text. Written expecting exactly one blocked issue in that project's top-5; the first run found two (`fix-development-build` and `issue-migration-collision`, both critical+blocked) — `flutter test` catching that immediately, before the assertion was loosened to `findsNWidgets(2)`, is the same "prove it against the real fixture, not the assumed one" lesson as the phase-1 council entries above.
- `flutter analyze` clean; `flutter test` 390/390 (389 pre-existing + 1 new).

## 2026-08-21 — WK-20260821-gh-45-mobile-threat-model-and-security-baseline

- Grounding a threat model in the actual codebase instead of a generic
  mobile-OWASP template surfaced a critical finding a template pass would
  have missed entirely: `android/app/build.gradle.kts`'s release build type
  signs with `signingConfigs.getByName("debug")` — this project's own debug
  keystore, whichever machine generated it. Anyone holding that specific
  file can sign a same-certificate "update" that Android accepts as a
  trusted in-place upgrade on any device that already installed a
  debug-signed build, which is exactly what CI's own
  `flutter build apk --release` produces today. No generic checklist item
  says "check what actually signs your release build" — it only came up by
  reading the Gradle file the issue's own acceptance criteria
  ("APK delivery") pointed at.
- A second finding was already sitting, unresolved, in
  `docs/napkin-lessons.md` itself from a 2026-08-14 council round:
  `authGatewayProvider` returns `MockAuthGateway` unconditionally, including
  in release builds, with no `kReleaseMode` gate — `security-standards.md`
  §4 requires exactly that gate and it does not exist. A threat model that
  only reads current code and not this file's own accumulated open
  questions would have re-discovered (or missed) something already on
  record. Read the full "Questions carried forward" backlog before writing
  a security document — some of the highest-value findings are already
  there, just never promoted to a document with an owner.
- Action next time: when a threat-model or security-baseline issue lands,
  grep `docs/napkin-lessons.md` for unresolved council questions touching
  the surface in scope *before* re-deriving findings from the code alone —
  several open questions there are already-found, never-acted-on security
  gaps, and the value of a fresh pass is connecting them to a prioritized
  owner, not re-discovering them from zero.
- Epic #14's own GitHub scope checklist (`gh issue view 14`) names three
  items — biometric gate for critical actions, local data minimization,
  remote wipe/revocation — with no issue filed against any of them, visible
  only by cross-referencing the epic's checklist against `gh issue list`'s
  actual issue titles. A docs-only threat-model issue can name that gap
  (`docs/architecture/security-threat-model.md` R11) but should not decide
  the epic's issue list unilaterally — recommend filing, do not file, unless
  explicitly asked to create issues.

## 2026-08-21 — WK-20260821-gh-45-council-round-2

- Council round 1 on PR #50 (this issue's threat model) left two findings
  open going into round 2. **Finding 1 (mechanism claim overstated):** R1's
  prose said the Android debug keystore "is public and identical across
  every developer machine that ever ran flutter/gradle defaults" — factually
  wrong. Only the alias (`androiddebugkey`), password (`android`/`android`),
  and certificate DN (`CN=Android Debug,O=Android,C=US`) are fixed by
  convention; the RSA key pair is generated locally per machine the first
  time it builds a debug variant, so different machines normally hold
  different key material. No `debug.keystore` is checked into this repo.
  Fixed by narrowing the claim to the real risk: *this project's own*
  `debug.keystore` — whichever machine produced the one CI/release builds
  actually sign with — must never leak, because whoever holds that specific
  file can sign a same-certificate update. Severity stayed Critical; only
  the mechanism description was wrong, not the risk. The same overstated
  phrasing had also leaked into `docs/issues/epic-14/README.md`'s R1
  one-liner and this file's own gh-45 entry above — all three needed the
  same correction, not just the primary doc. **Lesson:** when a claim about
  *why* something is dangerous gets corrected, grep the whole diff (and
  adjacent docs/lessons files) for the same phrasing before calling it
  closed — a wrong mechanism claim tends to get restated in a summary doc
  and a lessons entry, not just written once.
- **Finding 2 (unrelated commit in the PR):** PR #50's branch carried
  `29b2421` ("docs(phase-4): record #28 merged/pushed/closed...") ahead of
  the actual #45 work (`4b5d318`), pulling two files unrelated to #45
  (`docs/issues/phase-4/README.md`, `docs/issues/phase-4/RESUME.md`) into
  the diff. Confirmed `29b2421` was not yet an ancestor of `origin/development`
  by any other path (`origin/development` was still at `b0ac4a1`, `29b2421`'s
  own parent) and not an ancestor of PR #51's branch either. Fixed by
  resetting the branch to `origin/development`, cherry-picking only `4b5d318`
  (with the finding-1 wording fix folded in), and force-pushing — the PR
  diff is now #45's threat-model work only. `29b2421` was still a
  fast-forward child of `origin/development`'s then-current tip (`b0ac4a1`)
  at the moment the branch was reset, and this repo's own history shows
  plain `docs: ...` commits landing directly on `development` without a PR
  as an established convention (e.g. `57d77e0`, `4ad9873`, `8376ea1`) — so
  `29b2421` was pushed straight to `origin/development` as a fast-forward
  (`b0ac4a1..29b2421`), not force, no rewrite. Its content is preserved on
  `development`; only its position in PR #50's own branch changed.
- Action next time: a docs-only PR can still carry an accidental extra
  commit from whatever the branch was cut atop at the time — before
  requesting or closing a council round, run
  `git log <base>..<branch> --oneline` and diff each commit's file list
  against the issue's own acceptance criteria, not just the PR's aggregate
  diff, to catch a stray commit that the aggregate diff would only show as
  "extra files changed."

## 2026-08-21 — WK-20260821-http-auth-gateway

- `authGatewayProvider` returning `MockAuthGateway` unconditionally, even in
  release builds, was `security-threat-model.md` finding R2. Closing it
  needed more than swapping the class: the interface itself
  (`AuthGateway.signIn(String accessCode)`) was shaped around a wrong guess.
  `EDortta/CodexBridge` issue #4 landed `POST /api/v1/auth/sign-in` needing
  a **username and a password**, not one opaque code — confirmed by reading
  `gateway/app/api/routes/auth.py` and `docs/api/codex-bridge.openapi.yaml`
  in the sibling repo before writing any client code. The mobile sign-in
  screen had exactly one obscured "Access code" field to match the old
  guess. **Lesson:** when a domain interface predates the real contract it
  was drafted against, read the real contract before implementing the HTTP
  client — a client that faithfully implements a wrong-shaped interface
  cannot sign anyone in, no matter how correct its error handling is.
  Fixed by correcting the seam (`signIn({required username, required
  password})`), propagating through `MockAuthGateway`, `SessionController`,
  and `session_screen.dart` (username field added, password field replaces
  the old access-code field) — contained to the `auth` feature, no other
  feature touched.
- Neither `POST /auth/sign-in` nor `POST /auth/refresh` returns the actor's
  identity — only `GET /auth/me` resolves a token to `{id, email}`.
  `Session.operatorId`/`operatorName` therefore cannot be filled from the
  sign-in response alone; `HttpAuthGateway.signIn` calls `/auth/me` once,
  right after a successful sign-in, and fails closed (`AuthDenied.
  unreachable`) if that second call does not resolve — inventing an
  identity from the username the operator typed would violate
  `session.dart`'s own documented invariant ("never taken from anything the
  client supplied"). `renew` does not repeat this call: a rotation is the
  same actor renewing the same grant, so the identity is carried forward
  from the session being renewed instead of paying a second round trip on
  every renewal.
- No "use mock data" toggle existed anywhere in this codebase to reuse
  (`liveSessionRepositoryProvider` wires `HttpLiveSessionRepository`
  unconditionally, in every build) — confirmed by grep before inventing one.
  Gated `authGatewayProvider` on `kReleaseMode` instead, composed in
  `lib/app/auth_gateway_binding.dart` exactly like `gateway_context_binding.
  dart` composes auth + server: a feature must not import another feature's
  `presentation/` layer (`test/architecture/layer_boundaries_test.dart`
  enforces this at test time), so the binding that needs both `auth` and
  `server` has to live in `lib/app/`, not in either feature. The
  release/debug branch itself is pulled into a plain function
  (`resolveAuthGateway`) so both branches run under a normal unit test
  instead of only ever exercising whichever one `kReleaseMode` happens to
  compile to in a given test process.
- `HttpServerProbe`'s own test stops at the pure `reportForTransportFailure`
  function because a real TLS round trip would need a self-signed
  certificate committed to the repo (`security-standards.md` §1 forbids
  that even for a test). `HttpAuthGateway`'s tests do not have that
  obstacle — they bind a real local `HttpServer` over plain HTTP
  (`InternetAddress.loopbackIPv4`, port 0) and exercise the actual
  `dart:io` request/response round trip, including the two-call sign-in
  sequence (`/auth/sign-in` then `/auth/me`) and the "grant issued but
  never identified" failure path. `HttpLiveSessionRepository` — this
  codebase's other real HTTP-calling repository — turned out to have zero
  test coverage at all (`grep -rln HttpServer.bind test/` was empty before
  this change); its existence was not itself evidence of a testing pattern
  to copy, only of a gap worth naming, not silently repeating.
- Left open, named rather than silently skipped: `SessionController.
  signOut` still only clears the local keystore. `HttpAuthGateway.revoke()`
  (calls `POST /api/v1/auth/revoke`) exists and is tested, but is not wired
  into `signOut` — that method is the most race-hardened part of this
  feature (three separate `_signOutGeneration` checks exist solely to stop
  a renewal from resurrecting a session the operator just removed), and
  giving it a network call needs its own pass over that exact kind of
  interleaving. Until a follow-up does that pass, a signed-out device's
  server-side grant lives out its own TTL (short access token, up to 7-day
  refresh token) instead of being revoked immediately.
- [2026-08-21] WK-20260821-gh-22-council-round-2-doc-drift — council round 2
  on PR #52 flagged that `_SignInForm`'s doc comment claimed "both [username
  and password] are cleared as soon as the credential has been handed to the
  gateway", but `_signIn()` only ever called `_password.clear()`. Code and
  comment had silently drifted at some point after the comment was written.
  Judgment call: kept the code as-is (not clearing the username is better
  UX — an operator who mistypes a password can retry without retyping who
  they are, and a username is not itself a secret) and corrected the comment
  to say so explicitly, rather than making the code match the stale comment.
  Added assertions to the existing "device cannot store" widget test
  confirming the password field is empty and the username field is not,
  after a failed sign-in. Action next time: when a doc comment makes a
  blanket claim about symmetric handling of two things ("neither... both...
  every..."), grep the implementation for that exact behavior on both
  before trusting the comment — this is cheap and catches drift a normal
  read-through skims past.

## 2026-08-21 — WK-20260821-gh-29-http-issue-repository

- `IssueRepository` (issue #29) is load-only and unscoped: `loadIssues()`,
  `loadEpics()`, `loadIssue(id)`, `loadEpic(id)` take no project id, because
  the browser it backs was built to filter client-side over "every epic /
  every issue". The real gateway (`EDortta/CodexBridge` issue #8,
  `gateway/app/api/routes/epics.py`, `.../issues.py`) has no such endpoint —
  `GET /api/v1/projects/{projectId}/epics` and `.../issues` are both
  project-scoped, and there is no `GET /api/v1/epics/{epicId}` at all.
  Reshaping the interface to carry a project id would have meant threading
  it through routing and #29's already-shipped, already-tested screens for
  a change nothing asked for. Instead `HttpIssueRepository` closes the gap
  itself: it fans out across every project the operator can see
  (`GET /api/v1/projects`) and concatenates/searches across the pages. More
  requests than a project-scoped call would need, accepted and named in the
  class doc rather than paid silently on every screen visit.
- The mock's fields were shaped off CodexBridge issue #8's *proposed* scope
  while #8 was still open (its own doc comment said so, dated 2026-08-21).
  Now that #8 shipped, two concrete drifts turned up against the real
  contract: (1) `EpicModel` carries no `priority` column — only issues do —
  so `Epic.priority` became nullable (`IssuePriority?`) instead of dropped,
  and the two screens that rendered it unconditionally
  (`epics_screen.dart`, `epic_detail_screen.dart`) were changed to a
  conditional badge; the mock still sets a value, so both paths stay
  covered. (2) The real gateway's issue/epic status and priority vocabularies
  are wider than #29's four-value `IssueStatus`/`IssuePriority` enums
  (`issue_types.py`: six issue statuses vs. four, `medium`/`urgent` vs.
  `normal`/`critical`). Rather than widen every enum, chip and filter #29
  already shipped, `HttpIssueRepository` folds the wire vocabulary down at
  the boundary (`_issueStatusFromWire` et al.) and documents each lossy
  collision (`in_review` → in progress, `cancelled` → done) at the mapping
  site instead of leaving it implicit.
- The task brief assumed a "stale-revision 409" convention for the
  optimistic-concurrency `PATCH`. Reading the actual shared helper
  (`gateway/app/api/concurrency.py`'s `require_if_match`) showed it raises
  **412 Precondition Failed**, not 409 — `decisions.py` has its own,
  unrelated 409 for a *state* conflict (a decision already resolved), not a
  *revision* conflict; `epics.py`/`issues.py` only ever call the shared
  412-raising helper. Implemented and tested `StaleIssueRevisionException`
  against 412, with the test name saying so explicitly, so the next reader
  does not have to re-derive it from `concurrency.py`. Action next time: a
  task brief's assumption about a wire-level status code is a guess, not a
  spec — grep the shared helper the routes actually call before writing the
  client's branch on it.
- Following `HttpAuthGateway`'s constructor-injection idiom (a
  `Future<GatewayContext?> Function()` closure passed in, composed only in
  `lib/app/issue_repository_binding.dart`) rather than
  `HttpLiveSessionRepository`'s per-call `server`/`accessToken` params kept
  every existing `issue_providers_test.dart` test green: those tests build
  a `ProviderContainer` overriding only `issueRepositoryProvider`, never
  `gatewayContextProvider`, so a repository that needed context as a
  provider dependency would have broken all of them. Same `kReleaseMode`
  gate as `authGatewayBinding`, same pulled-out pure function
  (`resolveIssueRepository`) so both branches run under a plain unit test.
  Full suite after wiring: 424 tests, 0 regressions (18 new: 16 in
  `http_issue_repository_test.dart`, 2 in `issue_repository_binding_test.
  dart`), `flutter analyze` clean.
- [2026-08-21] WK-20260821-gh-53-signout-revoke — closed the gap the entry
  above left open: `SessionController.signOut` now calls
  `AuthGateway.revoke` alongside the local keystore clear. Two design
  decisions worth naming for whoever touches this next. First, fail-open
  is on the network call *only*, never on failure handling: `revoke` is
  awaited synchronously ahead of the local clear (not raced against it,
  not fired-and-forgotten in the background) because `AuthGateway.revoke`
  is documented to never throw and to resolve inside its own bounded
  timeout — the same trust the controller already extends to `signIn` and
  `renew`, both called the same way with no `try/catch` around them. A
  failure is folded into a new `SignedOut.serverSessionMayRemainActive`
  flag and rendered as a plain warning (`session_screen.dart`), reusing
  the existing `sessionMayRemainOnDevice` banner pattern rather than the
  SnackBar-on-catch pattern used elsewhere in the app (`mission_detail_
  screen.dart`, `decision_detail_screen.dart`) — that pattern needs a
  thrown exception at a widget call site, and this controller's whole
  design is fire-and-forget through provider state, never a future the
  screen awaits. Second, two `signOut` calls landing before either's
  network leg resolves (the "Remove from this device" retry, called while
  the first attempt is still in flight) are collapsed onto one `revoke`
  request via a memoized in-flight `Future<bool>`
  (`SessionController._pendingRevoke`) — not because it is reachable from
  today's screen (the button disables itself the instant `renewing` flips
  true), but because the issue named the race explicitly and the fix is a
  few lines.
- The bug this session's own test coverage caught, not review: `signIn`'s
  guard rebuilds `SignedOut` with `signingIn: true` *before* awaiting the
  gateway, and that rebuild only carried `sessionMayRemainOnDevice`
  forward — not the new `serverSessionMayRemainActive`. A sign-out with a
  failed revoke, followed by any sign-in attempt (even one later refused),
  silently dropped the warning the instant the sign-in started, because
  the flag never survived that first rebuild to be read back later. Caught
  by a test written specifically because the file already carries a
  named prior finding of the exact same shape for
  `sessionMayRemainOnDevice` (the council round-2 finding in the #22
  entries above) — pattern-matching "this file has been bitten by this
  exact class of bug before" onto the new field was what prompted writing
  that test at all, not a generic instinct to test everything. Action next
  time: when a state class gains a field that must survive an
  intermediate rebuild the same way an existing sibling field does (grep
  the class for other fields threaded through the same guard), write the
  carry-forward test for the new field *before* trusting the implementation
  — the existing field's own test coverage will not catch a sibling field
  the rebuild forgot.
- [2026-08-21] WK-20260821-gh-10-http-conversation-repository — Wired
  `conversations` to the real `CodexBridge` gateway (issue #10, PR #22 on
  that repo). `lib/features/conversations/domain/conversation.dart` used to
  be a two-field stub (`title`, `lastMessage`) with a one-method repository
  interface (`loadConversations()` only) — nowhere near the real contract's
  five endpoints, so wiring this "for real" meant expanding the domain
  model (`Conversation`, `ConversationMessage`, `ContextReference`,
  `ConversationsPage<T>`) before there was anything to point an HTTP
  repository at, not just swapping an implementation behind an unchanged
  interface the way `HttpAuthGateway` could. Three contract details from
  the server's own hard-won delivery notes (`gateway/app/api/routes/
  conversations.py`'s module docstring) had to survive that expansion
  unflattened: `unread` only ever advances through `GET .../messages` (to
  the newest message *actually fetched*, never to "now") and
  `POST .../messages` (the sender's own cursor) — never a client-side
  "mark as read"; the conversations list orders by `createdAt`/`id`, never
  `lastActivityAt` — `HttpConversationRepository` does not resort what the
  server returns, and `conversations_screen.dart`'s subtitle reads
  `lastActivityAt` for display only; and `artifact` is simply absent from
  `ConversationContextType` — not a case the client special-cases and
  rejects, an enum member that does not exist, so there is nothing to get
  wrong later by adding a fifth branch that shouldn't be there.
  Judgment calls: (1) no `uuid` package and no existing client-generated-id
  pattern anywhere in `lib/` (checked with `grep -rn "uuid\|Uuid" lib`
  before writing one) — added a from-scratch UUID v4 on `Random.secure()`
  (`lib/core/identifiers/idempotency_key.dart`) rather than a new
  dependency for one 16-byte value. (2) `postMessage`/`createConversation`
  take `idempotencyKey` as *optional*: a caller that owns retry semantics
  (none exists yet — this app's compose UI is out of this change's scope)
  passes the same key across attempts of one logical send; when omitted,
  `HttpConversationRepository` generates a fresh one per call, tested
  explicitly (`two calls with no explicit key generate two different
  keys`) so a future caller cannot assume the repository itself dedupes
  retries — only the caller-supplied-key path does. (3) `ConversationRepositoryException.notFound`
  is a dedicated bool, not inferred from `code == 'not_found'` — 404 and
  403 are both real, distinct outcomes the server deliberately keeps apart
  (404 for "does not exist or you cannot see it", 403 nowhere in this
  feature's actual responses today but kept distinguishable in the
  exception shape for the day a caller does need to tell "hidden" from
  "forbidden" apart), and collapsing them into one string comparison at
  every call site is exactly the kind of drift the server route module's
  own docstring calls out for the identical reason (`404`, never `403`,
  for a hidden entity — see `_context_not_found`/`_conversation_not_found`
  in `routes/conversations.py`). Tests:
  `test/features/conversations/data/http_conversation_repository_test.dart`,
  against a real locally-bound `HttpServer` (no TLS, same reasoning
  `http_auth_gateway_test.dart` gives for stopping there) — list/get/list
  messages/post message (including the duplicate-`Idempotency-Key` retry
  returning the original message instead of creating a second one) and
  create conversation (including the `mixed_project` 400, asserted via
  `ConversationRepositoryException.code`, not a string-matched message),
  plus auth failure, a connection that accepts and never answers (bounded
  timeout), a non-JSON body, and 404 vs. 403 asserted as genuinely
  different outcomes rather than both just "an error was thrown".

## 2026-08-21 — WK-20260821-http-mission-repository

- The real gateway's `Mission` is much thinner than this app's `Mission`
  domain model, and the two describe genuinely different things.
  `gateway/app/api/routes/missions.py`'s own module docstring says it
  outright: a mission is the same `TaskModel` row `/api/v1/sessions`
  serves, reframed — "no dependency graph, no 'related entities' table, no
  execution-progress percentage". `mission_control_action.dart`'s doc
  comment on this mobile repo independently says the same thing from the
  other side: "a `Mission` is a local, mock-backed planning record (no
  gateway round trip, no `If-Match` revision)". Both were right, and
  wiring missions for real means reconciling them, not just swapping the
  repository implementation the way `HttpAuthGateway` could. Confirmed by
  reading the real DTO (`_mission_dto` in `missions.py`) and the OpenAPI
  `Mission` schema before writing any client code — the same rule the
  `http-auth-gateway` entry above already names, and it paid off the same
  way: the mismatch would have been a runtime surprise instead of a
  design decision if skipped.
- Judgment call, the biggest one in this change: rather than reshape
  `Mission` and every screen that renders it (`mission_detail_screen.dart`,
  `work_screen.dart`, the four filter providers) to match the gateway's
  thinner shape — out of scope for "wire missions for real" and a much
  bigger blast radius — `HttpMissionRepository._missionFromDto` maps the
  gateway's fields onto the existing model with clearly-documented, lossy
  approximations: the gateway's coarse 3-value `stage`
  (`pending`/`active`/`done`, a grouping over execution state) is mapped
  by ordinal position onto the mobile app's 5-value `MissionStage`
  (`planning`..`documentation`, a software-development phase) —
  `pending`→`planning`, `active`→`implementation`, `done`→`documentation`;
  `testing`/`validation` are simply unreachable from a real mission. The
  gateway's `risk` (a policy level: `read`/`controlled_write`/`sensitive`)
  maps onto `MissionRisk` (`low`/`medium`/`high`) the same way. `owner`
  becomes the executor id (`assignedAgent`) rather than a human name;
  `progress` collapses to a coarse 0.0/1.0 done-or-not signal (the gateway
  reports no percentage); `dependencies`/`tests`/`files`/`artifacts`/
  `relatedDecisionIds` are always empty (the gateway's own contract
  explains why it does not fabricate these either: "shipping an
  always-empty array would be a field a mobile client can build UI around
  and never see populated" — the same reasoning applies to this client
  consuming it). Action next time: a follow-up issue should reconcile
  `Mission` with what the gateway actually reports — either thin the
  domain model down or give the gateway a richer mission concept — rather
  than let this mapping function be the only place that knows how lossy
  the current model is.
- The gateway's `POST /missions/{id}/cancel` has no request body at all —
  confirmed by reading both the route handler and the OpenAPI operation,
  which lists only `If-Match`/`Idempotency-Key` headers. The mobile
  `MissionRepository.cancel(missionId, {required reason})` contract
  predates this and still requires a non-empty `reason` (kept, so
  `MockMissionRepository` and `HttpMissionRepository` validate the same
  precondition) — but `HttpMissionRepository` has nowhere to send it. The
  real mission's timeline will read "Cancelled by an operator.", never the
  operator's typed reason, until the contract grows a field for one. Judgment
  call: validate and discard rather than silently drop the requirement or
  invent a place to stash it (a query param, a `X-Cancel-Reason` header no
  server reads) — discarding a value nobody asked for is more honest than
  smuggling it somewhere unspecified. Flagged in the PR description as a
  product gap for `EDortta/CodexBridge`, not treated as this change's bug
  to route around.
- `MissionRepository.cancel` needed a revision for `If-Match`, but the
  interface has exactly one call site (`MissionDetailScreen`'s
  `_ActionsCard`, itself holding the freshly-loaded `Mission` already) —
  unlike `LiveSessionRepository.controlSession`, which can fire from either
  the sessions list (cached revision) or the detail screen, and so needs
  `_revisionFor`'s two-path lookup. Rather than add a `revision` field to
  `Mission` and thread it through every call site and every existing
  `MockMissionRepository` test just to satisfy one caller,
  `HttpMissionRepository.cancel` fetches the mission fresh internally,
  immediately before the write, and reads `revision` off that response —
  zero interface signature change, zero blast radius on the ~20 existing
  mock-repository tests. `live_session_providers.dart`'s own comment on
  fetching fresh ("the revision sent is never a stale copy of one the
  detail screen's own, independently loaded session has already moved
  past") is the same reasoning, just with nothing else to check first.
- No shared HTTP-client infrastructure existed to reuse — confirmed by
  `find lib -path '*core/http*'` (empty) before writing anything, the same
  check the `http-auth-gateway` entry above describes for its own
  "no mock toggle" finding. `HttpLiveSessionRepository` and
  `HttpAuthGateway` each construct their own `dart:io HttpClient` per
  call with their own private `_jsonObject`/`_messageOf` helpers;
  `HttpMissionRepository` duplicates that same shape rather than
  extracting a shared base now — a three-way near-identical duplication is
  a legitimate signal to extract a `core/http/` client, but doing that
  extraction as a side effect of this change would have put an untested
  refactor of two already-shipped, already-tested classes in the same PR
  as new functionality. Named here as a concrete follow-up instead of
  quietly repeating the duplication a fourth time in the future.
- `resolveContext` (a `Future<(Uri, String)?> Function()`, not a
  `GatewayContext` import) is `HttpMissionRepository`'s constructor seam,
  deliberately mirroring `HttpAuthGateway`'s `resolveServer` rather than
  `HttpLiveSessionRepository`'s per-call `{required server, required
  accessToken}` parameters. The per-call-params shape was the closer
  structural analog (an authenticated repository fetching entities, the
  same "class" of problem) and was tried first, but it would have forced
  `required Uri server, required String accessToken` onto every
  `MissionRepository` method including `MockMissionRepository`'s, which
  needs neither — breaking every one of the ~20 existing
  `mock_mission_repository_test.dart`/`mission_detail_screen_test.dart`/
  `work_screen_test.dart` call sites for a parameter the mock would only
  ever ignore. The constructor-seam shape keeps the interface identical to
  what it was before this change (`explain` is the only addition) and
  composes in `lib/app/mission_repository_binding.dart` exactly like
  `authGatewayBinding` does.
- `explain` is wired at the repository layer only — `HttpMissionRepository.
  explain` calls the real `POST /missions/{id}/explain` and is tested
  against a real `HttpServer` — but `MissionDetailScreen`'s "Explain"
  button still calls the local `Mission.explanation` getter, unchanged.
  The two are genuinely different accounts (the getter is computed from
  fields already on the client; the endpoint returns server-side evidence
  including `recentStderr` this client cannot see on its own — see
  `mission_explanation.dart`'s doc comment), and wiring the button to the
  richer one is real UI work (a loading state, an error state, mirroring
  `work_session_detail_screen.dart`'s `_ExplanationDialog` for live
  sessions) that was left out to keep this change scoped to the
  repository/data layer, matching how the task that requested this change
  itself framed "list/detail/timeline/cancel/explain" as repository
  capabilities. Action next time: the follow-up that wires the button is
  small and has a template to copy (`_ExplanationDialog`) — worth doing
  before this reads as intentionally abandoned rather than intentionally
  deferred.
## 2026-08-21 — WK-20260821-http-project-repository

- CodexBridge issue #5 shipped its own `ProjectHealth` enum — `ok`/
  `degraded`/`unknown`/`disabled` — which does not line up with this app's
  domain `ProjectHealth` (`active`/`unhealthy`/`pendingDecision`/`offline`,
  drafted by #23 before the backend contract existed). They are four
  different meanings, not four spellings of the same thing: `disabled` is
  an operator decision, not an incident; `unknown` means no executor is
  even assigned; `degraded` means executors are assigned but none live;
  `ok` says nothing about a pending decision, which arrives as a separate
  `pendingDecisions` integer alongside it. Rather than widen the mobile
  enum (#23/#24 presentation-layer territory this change does not touch),
  `HttpProjectRepository.projectHealthFromBackend` maps the pair onto it:
  `disabled` -> `offline` ("Disabled in the registry"), `unknown` ->
  `offline` ("No executor assigned"), `degraded` -> `unhealthy` ("No live
  executor connected"), `ok` with `pendingDecisions > 0` -> `pendingDecision`
  (count in the attention text), `ok` otherwise -> `active`. This is a
  judgment call, not something the contract dictates, flagged here the same
  way the auth work's access-code-vs-username/password gap was flagged
  earlier the same day — an operator who disagrees with the priority order
  (pending-decision only shown when otherwise `ok`) should treat this as a
  one-file change (`http_project_repository.dart`'s
  `projectHealthFromBackend`), not an architecture change.
- The 404-not-403 pattern (`getProject`: "confirming that an identifier
  exists is what probing is for") only bites at `GET /projects/{id}`, not
  at the list endpoint — `GET /projects` already filters to the caller's
  visible scope in the query, so an out-of-scope project simply never
  appears in `items`. `ProjectRepository.loadProject` therefore returns
  `ProjectSummary?` (`null` = not found, mapped straight from a 404) while
  every other non-2xx status throws `ProjectRepositoryException` — and
  `projectByIdProvider` (`lib/app/project_dashboard_screen.dart`'s only
  caller) already treated a `null` value distinctly from an `AsyncError`
  before this change, so wiring the real endpoint in needed no widget-level
  change to preserve that separation.
- Followed `HttpLiveSessionRepository`/`live_session_providers.dart`'s
  established shape rather than `HttpAuthGateway`'s: `ProjectRepository`
  methods take `{required Uri server, required String accessToken}` as
  per-call parameters (not constructor state), and the presentation layer
  (`project_providers.dart`) resolves them from `gatewayContextProvider`
  before calling — the same seam missions already use, rather than the
  injected-resolver-callable shape `HttpAuthGateway` needs for its own
  chicken-and-egg problem (no session exists yet at sign-in time to carry a
  `GatewayContext`). This ripples `gatewayContextProvider` into every
  test that renders `ProjectsScreen` or navigates through it —
  `test/features/projects/presentation/projects_screen_test.dart` and
  `test/app/app_router_test.dart` both needed a fixed override added, the
  same one `test/app/project_dashboard_screen_test.dart` already carried.
- `HttpLiveSessionRepository`'s own gap — none of its calls bounded by a
  timeout — is exactly what this change avoids repeating:
  `HttpProjectRepository` bounds `connectionTimeout`, the request-close
  await, and the body-read await, all with the same `.timeout(timeout)`
  discipline `HttpAuthGateway` already established, and
  `http_project_repository_test.dart` has a dedicated test (a server that
  accepts the connection and never answers) proving it actually fires
  rather than just being present in the code.
- Wired the real/mock switch exactly like `auth_gateway_binding.dart`:
  `projectRepositoryProvider` still defaults to `MockProjectRepository`
  (every widget test, every debug build until `main.dart`'s overrides
  apply), and `lib/app/project_repository_binding.dart` overrides it with
  `HttpProjectRepository` under `kReleaseMode` — the branch itself pulled
  into `resolveProjectRepository`, tested directly the same way
  `resolveAuthGateway` is, since `kReleaseMode` never flips inside one test
  process.
- Not done: real pagination. `loadProjects` reads one page at whatever the
  server's default `limit` is and ignores `page.hasMore`/`nextCursor` —
  the same simplification `HttpLiveSessionRepository` already made for
  `/api/v1/sessions`. The backend module's own docstring calls its
  registry "operator-curated and expected to hold at most a few hundred
  rows," so this is unlikely to hide a project today, but it is a real gap
  for a follow-up issue once the registry grows past one page.
- `flutter analyze` clean; `flutter test` 423/423 (16 new in
  `http_project_repository_test.dart`, 2 new in
  `project_repository_binding_test.dart`, plus updates to
  `projects_screen_test.dart` and `app_router_test.dart` to carry the new
  `gatewayContextProvider` dependency — no regressions).

## 2026-08-21 — WK-20260821-http-decision-repository

- The briefing said "get the client's handling of a 409 (stale revision)
  conflict right" — reading `gateway/app/api/routes/decisions.py` and
  `concurrency.py` in the CodexBridge repo (not the docs) showed the real
  split is finer: `concurrency.require_if_match` answers a stale `If-Match`
  with **412** (RFC 9110 §13.1.1 — the correct code for a failed
  precondition), and `_resolve`'s own `DECIDABLE` check answers a decision
  that already left `pending` with **409**. Both mean the same thing to an
  operator — "this changed since you looked; re-read it and decide again" —
  so `HttpDecisionRepository` maps both to one `DecisionConflictException`
  rather than mirroring the two status codes as two client types. Lesson:
  when a task names a status code from memory or a summary, verify it
  against the route handler that raises it before writing a test around
  that number — the real contract had two codes doing what the brief
  described as one.
- `DecisionRepository.approve`/`reject`/`requestRevision` carry no revision
  parameter — unlike `LiveSessionRepository.controlSession`, `Decision` has
  no `revision` field to cache. Adding one would have reached
  `decision_providers.dart`, `decision_detail_screen.dart`, and every
  existing decisions test for a value only the HTTP repository needs. Kept
  the domain contract untouched instead: each resolve call fetches the
  current revision first (`GET /api/v1/decisions/{id}`), then sends it back
  as `If-Match` on the write — the same two-network-call shape
  `HttpAuthGateway.signIn` already uses (post the grant, then resolve
  `/auth/me`) for the same reason: a value the caller never had a chance to
  read is not one it can be asked to pass in.
- The server's `Decision` DTO (`_decision_dto` in `decisions.py`) is a much
  flatter shape than the domain `Decision` this app already had a full UI
  built against (`decision_detail_screen.dart`, from the mock-only #26):
  no `impactSummary`, `recommendationSummary`, `context`, `riskDetails`,
  `evidence`, `affectedEntities`, or `discussion` — the contract's own
  `Decision` schema comment says as much ("no submission path in this build
  populates them"). Rather than fabricate content for fields the backend
  itself documents as unpopulated, `HttpDecisionRepository` defaults them
  empty and leaves the gap visible in the UI (`_ContextCard`/`_DiscussionCard`
  already render nothing for empty sections). The one exception:
  `auditTrail` gets one synthesized entry from `rationale`/`decidedAt` when
  a decision is resolved, so "Resolution history" does not say "No
  resolution actions yet." next to a state badge that says otherwise — but
  the resolving actor's identity is not in this response (only who
  *requested* the decision is), so the entry is honestly labeled `'Unknown
  actor'` rather than misattributed to the requester. `discuss()` throws:
  `decisions.py` has no comment/discussion endpoint at all.
- Every decision this backend serves today is `sensitive`
  (`decisions.py`'s own module docstring), and the gateway refuses to
  approve a sensitive decision without an explicit `confirm: true` in the
  body. `HttpDecisionRepository.approve` sends `confirm: true`
  unconditionally rather than adding a parameter `DecisionRepository.approve`
  has no other use for — tapping "Approve" in `DecisionDetailScreen` is
  already the deliberate act the flag proves happened (a critical decision
  additionally makes the operator check an acknowledgement box first).
- Action next time: before implementing a client against "the docs say
  status X", grep the actual route handler for every `ApiError`/`raise` it
  can produce and cross-check against the OpenAPI response list — the two
  can and did disagree in ways that change which exception type a client
  needs, not just which number a test asserts on.
