# Required Reading

**O índice único da leitura obrigatória deste projeto.** O agente abre este arquivo e
sabe tudo o que precisa ler — não precisa saber que parte da documentação mora em
`.docs/` (território do kit, substituído no `--upgrade`) e parte em `docs/` (território
do projeto, nunca sobrescrito). A coluna "Dono" diz de quem é cada arquivo, e isso só
importa na hora de **escrever**, não de ler.

<!-- AI-AGENTS:BEGIN kit reading list — gerado por install-agents-kit.sh; edições aqui dentro são substituídas no --upgrade. Escreva fora do bloco. -->
## Sempre, antes de qualquer issue

| Documento | Dono | O que é |
|---|---|---|
| `AGENTS.md` | kit | contrato universal de operação |
| `docs/software-overview.md` | kit semeia, **projeto preenche** | produto, stack, módulos, comportamento |
| `docs/limits.md` | kit semeia, **projeto preenche** | fronteiras duras do agente |
| `docs/project-rules.md` | **projeto** | regras que valem só aqui |

## Conforme o papel do trabalho

| Vai fazer | Leia também | Dono |
|---|---|---|
| codar / resolver issue | `.docs/agents/programmer.md` + `.docs/agents/design-standards.md` | kit |
| revisar código ou PR | `.docs/agents/reviewer.md` + `.docs/agents/design-standards.md` | kit |
| automatizar issue/PR | `.docs/agents/issue-automation.md` | kit |
| revisão adversarial de trabalho já aprovado | `.docs/agents/council.md` | kit |
| mudança com impacto em runtime | `.docs/agents/security.md` + `.docs/agents/security-standards.md` | kit |
| tratar dado pessoal | `.docs/agents/privacy-compliance.md` | kit |
| retomar / fechar sessão | `.docs/workflows/session-restore.md`, `.docs/workflows/session-close.md` | kit |
| implementar seleção/orçamento de contexto | `.docs/context-optimization.md` | kit |
<!-- AI-AGENTS:END -->

> **Onde a documentação deste projeto mora:** em `docs/`, e só lá. Decisão do
> operador em 2026-08-06: `software-overview.md` e `limits.md` são arquivos reais
> em `docs/`, sem cópia nem symlink em `.docs/`. Todas as referências que o kit
> semeou apontando para `.docs/…` foram repontadas.
>
> **Isto acompanha o kit, não o contraria.** O `install-agents-kit.sh` da fonte
> (`~/Sync/Projects/AI/Agents`, `EDortta/AI-Agents`) já lê `docs/software-overview.md`
> e `docs/limits.md`, e traz `migrate_readiness_files_to_docs()` justamente para
> tirar esses dois arquivos de `.docs/`. O layout do kit é: arquivos do kit em
> `.docs/`, os dois que o projeto preenche em `docs/`.
>
> **Pendência operacional:** a cópia de `scripts/install-agents-kit.sh` vendorizada
> neste repositório está 90 linhas atrasada e ainda procura o readiness gate em
> `.docs/` (linha ~1980), então ela sai `exit 30`. Não é limite do kit — é cópia
> velha. Rodar o upgrade a partir da fonte resolve, e nenhuma referência precisa
> ser repontada de novo depois disso.

## Deste projeto

Documentos específicos deste repositório. Esta seção é 100% do projeto: nenhum upgrade
a toca. Use `- (none)` se genuinamente não houver nenhum.

- `docs/project-rules.md` — regras específicas deste projeto (também na tabela acima)
- `docs/product-foundation.md` — escopo e premissas canônicas do produto
- `docs/issues/phase-4/README.md` — épico público **ativo** (Epic #5) e ordem de execução
- `docs/issues/phase-3/README.md` — épico encerrado (Epic #4: #25/#26); mantido para consulta
- `docs/issues/phase-2/README.md` — épico encerrado (Epic #3: #23/#24 eram suas únicas issues); mantido para consulta
- `docs/issues/phase-1/README.md` — épico encerrado (Epic #2, e Epic #7 fora de ordem); mantido para consulta
- `docs/issues/phase-0/README.md` — épico encerrado; mantido para consulta
- `docs/napkin-lessons.md` — lições curtas; leia ao retomar trabalho relacionado

## Por área

Leitura escopada: só quem for mexer na área precisa.

<!-- Exemplo:
- `docs/architecture.md` — ao tocar na camada de orquestração
- `clara-definitions/00-index.md` — ao trabalhar em Clara / WhatsApp / comprovantes
-->

- `docs/architecture/state-architecture.md` — ao tocar em feature, provider ou repositório
- `docs/architecture/navigation.md` — ao tocar em rota, shell ou destino primário
