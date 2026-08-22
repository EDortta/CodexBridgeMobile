import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/navigation/app_destinations.dart';
import '../domain/epic.dart';
import '../domain/issue_change_summary.dart';
import '../domain/issue_form_validation.dart';
import '../domain/issue_history_event.dart';
import '../domain/issue_repository.dart';
import '../domain/issue_status.dart';
import '../domain/project_issue.dart';
import 'issue_providers.dart';

/// #30: progressive create/edit form — details, then planning
/// (status/priority/assignee/epic/labels/dependencies), then a review step
/// that states every value and, when editing, every field that changed
/// before the operator confirms. [issueId] is `null` to create a new issue
/// scoped to [projectId]; non-null to edit that issue (whose own
/// [ProjectIssue.projectId] is then authoritative).
///
/// Each step blocks "Continue" until [IssueFormValidation] reports no error
/// for the fields it owns — #30's "validation is explicit". The review
/// step's "Confirm and save" *is* this form's confirmation gate: it is the
/// last screen the operator sees before anything is written, the same
/// "one deliberate screen before a state change lands" shape
/// `DecisionDetailScreen`'s resolution dialog uses for its own actions.
class IssueFormScreen extends ConsumerWidget {
  const IssueFormScreen({required this.projectId, this.issueId, super.key});

  final String projectId;
  final String? issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? editId = issueId;
    if (editId == null) {
      return _IssueFormBody(projectId: projectId, initial: null);
    }

    final AsyncValue<ProjectIssue> detail = ref.watch(issueDetailProvider(editId));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit issue')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              error is IssueNotFoundException
                  ? 'This issue could not be found.'
                  : 'Unable to load this issue.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (ProjectIssue issue) =>
            _IssueFormBody(projectId: issue.projectId, initial: issue),
      ),
    );
  }
}

class _IssueFormBody extends ConsumerStatefulWidget {
  const _IssueFormBody({required this.projectId, required this.initial});

  final String projectId;

  /// `null` in create mode.
  final ProjectIssue? initial;

  bool get isEditing => initial != null;

  @override
  ConsumerState<_IssueFormBody> createState() => _IssueFormBodyState();
}

class _IssueFormBodyState extends ConsumerState<_IssueFormBody> {
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _assigneeController;
  late final TextEditingController _blockedReasonController;
  final TextEditingController _labelInputController = TextEditingController();
  final TextEditingController _dependencyInputController = TextEditingController();

  int _currentStep = 0;
  bool _submitting = false;

  late IssueStatus _status;
  late IssuePriority _priority;
  String? _epicId;
  late List<String> _labels;
  late List<String> _dependencies;

  @override
  void initState() {
    super.initState();
    final ProjectIssue? initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _summaryController = TextEditingController(text: initial?.summary ?? '');
    _assigneeController = TextEditingController(
      text: initial == null || initial.assignee == 'Unassigned' ? '' : initial.assignee,
    );
    _blockedReasonController = TextEditingController(text: initial?.blockedReason ?? '');
    _status = initial?.status ?? IssueStatus.todo;
    _priority = initial?.priority ?? IssuePriority.normal;
    _epicId = initial?.epicId;
    _labels = List<String>.of(initial?.labels ?? const <String>[]);
    _dependencies = List<String>.of(initial?.dependencies ?? const <String>[]);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _assigneeController.dispose();
    _blockedReasonController.dispose();
    _labelInputController.dispose();
    _dependencyInputController.dispose();
    super.dispose();
  }

  /// The issue this form currently describes — used to drive the review
  /// step and, when editing, to diff against `widget.initial` via
  /// [describeIssueChanges]. Never sent as-is: create/update calls send only
  /// the fields the repository interface takes, but building this keeps one
  /// source of truth for "what does the draft look like right now" instead
  /// of the review step re-deriving it field by field.
  ProjectIssue _draft(List<Epic> epicsInProject) {
    final ProjectIssue? initial = widget.initial;
    final String assignee = _assigneeController.text.trim();
    return ProjectIssue(
      id: initial?.id ?? '',
      projectId: widget.projectId,
      title: _titleController.text.trim(),
      priority: _priority,
      status: _status,
      createdAt: initial?.createdAt ?? DateTime.now(),
      assignee: assignee.isEmpty ? 'Unassigned' : assignee,
      epicId: _epicId,
      summary: _summaryController.text.trim(),
      blockedReason: _status == IssueStatus.blocked
          ? (_blockedReasonController.text.trim().isEmpty
                ? null
                : _blockedReasonController.text.trim())
          : null,
      labels: _labels,
      dependencies: _dependencies,
      revision: initial?.revision ?? 1,
      history: initial?.history ?? const <IssueHistoryEvent>[],
    );
  }

  Map<String, String> _errors(List<Epic> epicsInProject) {
    return IssueFormValidation.validate(
      title: _titleController.text,
      status: _status,
      blockedReason: _blockedReasonController.text,
      projectId: widget.projectId,
      epicId: _epicId,
      epicsInProject: epicsInProject,
    );
  }

  bool _canLeaveStep(int step, Map<String, String> errors) {
    return switch (step) {
      0 => !errors.containsKey('title'),
      1 => !errors.containsKey('blockedReason') && !errors.containsKey('epicId'),
      _ => errors.isEmpty,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Epic>> allEpics = ref.watch(epicsProvider);
    final List<Epic> epicsInProject = allEpics.maybeWhen(
      data: (List<Epic> epics) =>
          epics.where((Epic e) => e.projectId == widget.projectId).toList(growable: false),
      orElse: () => const <Epic>[],
    );
    final Map<String, String> errors = _errors(epicsInProject);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit issue' : 'New issue'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepTapped: (int step) => setState(() => _currentStep = step),
        controlsBuilder: (BuildContext context, ControlsDetails details) {
          final bool isLastStep = details.stepIndex == 2;
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Row(
              children: <Widget>[
                if (isLastStep)
                  FilledButton(
                    key: const Key('issueFormSubmitButton'),
                    onPressed: _submitting || errors.isNotEmpty
                        ? null
                        : () => _submit(epicsInProject),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirm and save'),
                  )
                else
                  FilledButton(
                    key: Key('issueFormContinueStep${details.stepIndex}'),
                    onPressed: _canLeaveStep(details.stepIndex, errors)
                        ? details.onStepContinue
                        : null,
                    child: const Text('Continue'),
                  ),
                const SizedBox(width: AppSpacing.sm),
                if (details.stepIndex > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            ),
          );
        },
        onStepContinue: () {
          if (_canLeaveStep(_currentStep, errors) && _currentStep < 2) {
            setState(() => _currentStep += 1);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: <Step>[
          Step(
            title: const Text('Details'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _DetailsStep(
              titleController: _titleController,
              summaryController: _summaryController,
              titleError: errors['title'],
              onChanged: () => setState(() {}),
            ),
          ),
          Step(
            title: const Text('Planning'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _PlanningStep(
              status: _status,
              priority: _priority,
              epicId: _epicId,
              epicsInProject: epicsInProject,
              // The gateway keeps exactly one path that moves an issue
              // between epics (`linkIssueToEpic`) and none that clears it —
              // `HttpIssueRepository`'s own doc comment on `updateIssue`
              // names this. Offering "No epic" once one is already set
              // would let the operator pick a value this form cannot
              // actually save; the epic field only lets that draft depart
              // from "unset" in the direction the API supports.
              canClearEpic: widget.initial?.epicId == null,
              assigneeController: _assigneeController,
              blockedReasonController: _blockedReasonController,
              blockedReasonError: errors['blockedReason'],
              epicError: errors['epicId'],
              labels: _labels,
              dependencies: _dependencies,
              labelInputController: _labelInputController,
              dependencyInputController: _dependencyInputController,
              onStatusChanged: (IssueStatus value) => setState(() => _status = value),
              onPriorityChanged: (IssuePriority value) => setState(() => _priority = value),
              onEpicChanged: (String? value) => setState(() => _epicId = value),
              onLabelsChanged: (List<String> value) => setState(() => _labels = value),
              onDependenciesChanged: (List<String> value) =>
                  setState(() => _dependencies = value),
              onChanged: () => setState(() {}),
            ),
          ),
          Step(
            title: const Text('Review'),
            isActive: _currentStep >= 2,
            state: StepState.indexed,
            content: _ReviewStep(
              draft: _draft(epicsInProject),
              initial: widget.initial,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(List<Epic> epicsInProject) async {
    setState(() => _submitting = true);
    final IssueRepository repository = ref.read(issueRepositoryProvider);
    final ProjectIssue draft = _draft(epicsInProject);
    try {
      final ProjectIssue saved;
      final ProjectIssue? initial = widget.initial;
      if (initial == null) {
        saved = await repository.createIssue(
          projectId: widget.projectId,
          title: draft.title,
          epicId: draft.epicId,
          description: draft.summary.isEmpty ? null : draft.summary,
          status: draft.status,
          priority: draft.priority,
          labels: draft.labels,
          assigneeEmail: draft.assignee == 'Unassigned' ? null : draft.assignee,
          dependencies: draft.dependencies,
          blockedReason: draft.blockedReason,
        );
      } else {
        saved = await repository.updateIssue(
          issueId: initial.id,
          revision: initial.revision,
          title: draft.title,
          description: draft.summary,
          status: draft.status,
          priority: draft.priority,
          labels: draft.labels,
          assigneeEmail: draft.assignee == 'Unassigned' ? null : draft.assignee,
          dependencies: draft.dependencies,
          // Sent as `''` (not omitted) when the draft is no longer blocked,
          // so moving *out* of blocked explicitly clears a reason the
          // server would otherwise keep stranded from the earlier state —
          // `draft.blockedReason` is only non-null while blocked, and
          // `IssueFormValidation` already guarantees it is non-empty then.
          blockedReason: draft.blockedReason ?? '',
        );
        // Two separate write calls, not one transaction: if `updateIssue`
        // above already landed and this one then fails (stale write or a
        // transport error), the field edits are saved but the epic move is
        // not — the operator sees an error naming that failure and can
        // retry from the reloaded state, but this screen does not attempt
        // to roll the first write back. `not validated: partial-failure
        // recovery UX` — no test drives this specific interleaving; the two
        // calls are exercised independently.
        if (initial.epicId != draft.epicId && draft.epicId != null) {
          await repository.linkIssueToEpic(
            epicId: draft.epicId!,
            issueId: initial.id,
            issueRevision: saved.revision,
          );
        }
      }
      ref.invalidate(issuesProvider);
      ref.invalidate(epicsProvider);
      if (initial != null) {
        ref.invalidate(issueDetailProvider(initial.id));
      }
      if (!mounted) {
        return;
      }
      context.go(
        Uri(
          path: AppDestination.projects.detailPath,
          queryParameters: <String, String>{'issue': saved.id},
        ).toString(),
      );
    } on StaleIssueRevisionException {
      if (!mounted) {
        return;
      }
      // Cleared before the blocking dialog opens, not after: the button's
      // spinner is a busy indicator for the write in flight, not for a
      // modal barrier the operator cannot interact through anyway — leaving
      // it spinning behind the dialog is a stray "still working" signal for
      // something that already finished (if only by failing).
      setState(() => _submitting = false);
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('This issue changed'),
          content: const Text(
            'Someone else updated this issue since you opened it. Your '
            'edits were not saved — reload the latest version and try again.',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      final String? id = widget.initial?.id;
      if (id != null) {
        ref.invalidate(issueDetailProvider(id));
        context.go(
          Uri(
            path: AppDestination.projects.detailPath,
            queryParameters: <String, String>{'issue': id},
          ).toString(),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.titleController,
    required this.summaryController,
    required this.titleError,
    required this.onChanged,
  });

  final TextEditingController titleController;
  final TextEditingController summaryController;
  final String? titleError;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          key: const Key('issueFormTitleField'),
          controller: titleController,
          decoration: InputDecoration(labelText: 'Title', errorText: titleError),
          onChanged: (String _) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('issueFormSummaryField'),
          controller: summaryController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Description (optional)'),
          onChanged: (String _) => onChanged(),
        ),
      ],
    );
  }
}

class _PlanningStep extends StatelessWidget {
  const _PlanningStep({
    required this.status,
    required this.priority,
    required this.epicId,
    required this.epicsInProject,
    required this.assigneeController,
    required this.blockedReasonController,
    required this.blockedReasonError,
    required this.epicError,
    required this.canClearEpic,
    required this.labels,
    required this.dependencies,
    required this.labelInputController,
    required this.dependencyInputController,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onEpicChanged,
    required this.onLabelsChanged,
    required this.onDependenciesChanged,
    required this.onChanged,
  });

  final IssueStatus status;
  final IssuePriority priority;
  final String? epicId;
  final List<Epic> epicsInProject;
  final TextEditingController assigneeController;
  final TextEditingController blockedReasonController;
  final String? blockedReasonError;
  final String? epicError;

  /// `false` once an epic is already set: the gateway has no "unlink" path
  /// (see this screen's own doc comment on `canClearEpic` at the call
  /// site), so "No epic" must not be offered as something this form can
  /// actually save.
  final bool canClearEpic;
  final List<String> labels;
  final List<String> dependencies;
  final TextEditingController labelInputController;
  final TextEditingController dependencyInputController;
  final ValueChanged<IssueStatus> onStatusChanged;
  final ValueChanged<IssuePriority> onPriorityChanged;
  final ValueChanged<String?> onEpicChanged;
  final ValueChanged<List<String>> onLabelsChanged;
  final ValueChanged<List<String>> onDependenciesChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropdownButtonFormField<IssueStatus>(
          key: const Key('issueFormStatusField'),
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: <DropdownMenuItem<IssueStatus>>[
            for (final IssueStatus value in IssueStatus.values)
              DropdownMenuItem<IssueStatus>(value: value, child: Text(value.label)),
          ],
          onChanged: (IssueStatus? value) {
            if (value != null) {
              onStatusChanged(value);
              onChanged();
            }
          },
        ),
        if (status == IssueStatus.blocked) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('issueFormBlockedReasonField'),
            controller: blockedReasonController,
            decoration: InputDecoration(
              labelText: 'Blocked reason',
              errorText: blockedReasonError,
            ),
            onChanged: (String _) => onChanged(),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<IssuePriority>(
          key: const Key('issueFormPriorityField'),
          initialValue: priority,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: <DropdownMenuItem<IssuePriority>>[
            for (final IssuePriority value in IssuePriority.values)
              DropdownMenuItem<IssuePriority>(value: value, child: Text(value.label)),
          ],
          onChanged: (IssuePriority? value) {
            if (value != null) {
              onPriorityChanged(value);
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        // Sent to the repository as `assigneeEmail` regardless of whether
        // this looks like an email — `ProjectIssue.assignee` is already
        // documented as a single opaque display string (its own doc
        // comment: "say it in text"), not a validated address, the same
        // simplification the read side (`HttpIssueRepository._issueFromJson`)
        // already makes.
        TextField(
          key: const Key('issueFormAssigneeField'),
          controller: assigneeController,
          decoration: const InputDecoration(labelText: 'Assignee (optional)'),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String?>(
          key: const Key('issueFormEpicField'),
          initialValue: epicId,
          decoration: InputDecoration(
            labelText: 'Epic (optional)',
            errorText: epicError,
            helperText: canClearEpic
                ? null
                : 'Once an epic is set it can only be swapped for another, not removed.',
            helperMaxLines: 2,
          ),
          items: <DropdownMenuItem<String?>>[
            if (canClearEpic)
              const DropdownMenuItem<String?>(value: null, child: Text('No epic')),
            for (final Epic epic in epicsInProject)
              DropdownMenuItem<String?>(value: epic.id, child: Text(epic.title)),
          ],
          onChanged: onEpicChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        _ChipEditor(
          key: const Key('issueFormLabelsEditor'),
          label: 'Labels',
          values: labels,
          inputController: labelInputController,
          onChanged: onLabelsChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        _ChipEditor(
          key: const Key('issueFormDependenciesEditor'),
          label: 'Dependencies',
          values: dependencies,
          inputController: dependencyInputController,
          onChanged: onDependenciesChanged,
        ),
      ],
    );
  }
}

/// A labelled add/remove list — labels and dependencies both use this, the
/// same widget rather than two near-identical ones (`design-standards.md`
/// §5: one reason to change).
class _ChipEditor extends StatelessWidget {
  const _ChipEditor({
    required this.label,
    required this.values,
    required this.inputController,
    required this.onChanged,
    super.key,
  });

  final String label;
  final List<String> values;
  final TextEditingController inputController;
  final ValueChanged<List<String>> onChanged;

  void _add() {
    final String value = inputController.text.trim();
    if (value.isEmpty || values.contains(value)) {
      return;
    }
    inputController.clear();
    onChanged(<String>[...values, value]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: inputController,
                decoration: InputDecoration(labelText: label),
                onSubmitted: (String _) => _add(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add',
              onPressed: _add,
            ),
          ],
        ),
        if (values.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: <Widget>[
              for (final String value in values)
                InputChip(
                  label: Text(value),
                  onDeleted: () =>
                      onChanged(values.where((String v) => v != value).toList(growable: false)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.draft, required this.initial});

  final ProjectIssue draft;
  final ProjectIssue? initial;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> changes = initial == null
        ? const <String>[]
        : describeIssueChanges(before: initial!, after: draft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(draft.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xxs,
          children: <Widget>[
            Chip(label: Text(draft.status.label)),
            Chip(label: Text(draft.priority.label)),
            Chip(label: Text(draft.assignee)),
          ],
        ),
        if (draft.summary.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(draft.summary, style: theme.textTheme.bodyMedium),
        ],
        if (draft.blockedReason case final String reason?) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text('Blocked: $reason', style: theme.textTheme.bodyMedium),
        ],
        if (draft.labels.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text('Labels: ${draft.labels.join(', ')}', style: theme.textTheme.bodyMedium),
        ],
        if (draft.dependencies.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Dependencies: ${draft.dependencies.join(', ')}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (initial != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text('Changes', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          if (changes.isEmpty)
            Text('No changes yet.', style: theme.textTheme.bodyMedium)
          else
            for (final String change in changes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text('• $change', style: theme.textTheme.bodyMedium),
              ),
        ],
      ],
    );
  }
}
