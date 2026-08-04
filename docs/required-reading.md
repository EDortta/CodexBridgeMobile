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
| `.docs/software-overview.md` | kit semeia, **projeto preenche** | produto, stack, módulos, comportamento |
| `.docs/limits.md` | kit semeia, **projeto preenche** | fronteiras duras do agente |
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

## Deste projeto

Documentos específicos deste repositório. Esta seção é 100% do projeto: nenhum upgrade
a toca. Use `- (none)` se genuinamente não houver nenhum.

- `docs/project-rules.md` — regras específicas deste projeto (também na tabela acima)
- `docs/product-foundation.md` — escopo e premissas canônicas do produto
- `docs/issues/phase-0/README.md` — épico público ativo e ordem de execução
- `docs/napkin-lessons.md` — lições curtas; leia ao retomar trabalho relacionado

## Por área

Leitura escopada: só quem for mexer na área precisa.

<!-- Exemplo:
- `docs/architecture.md` — ao tocar na camada de orquestração
- `clara-definitions/00-index.md` — ao trabalhar em Clara / WhatsApp / comprovantes
-->

- `docs/architecture/state-architecture.md` — ao tocar em feature, provider ou repositório
- `docs/architecture/navigation.md` — ao tocar em rota, shell ou destino primário
