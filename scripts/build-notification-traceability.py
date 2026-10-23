#!/usr/bin/env python3
"""Extract every numbered Rulebook requirement without asserting untested coverage."""
import argparse
import re
from pathlib import Path

RULE = re.compile(r'^\*\*(BR|AT)-(\d{3})\.\*\*\s*(.*?)(?:  )?$', re.M)


def cell(value):
    return re.sub(r'\s+', ' ', value).replace('|', r'\|').strip()


def module(text):
    t = text.lower()
    for terms, name in [
        (('salary', 'payroll', 'বেতন'), 'Salary Note / payroll'),
        (('transfer', 'joining', 'বদলি', 'যোগদান'), 'Transfer / joining'),
        (('leave', 'ছুটি'), 'Leave'),
        (('disciplin', 'শৃঙ্খলা'), 'Disciplinary'),
        (('recruit', 'candidate', 'cv', 'নিয়োগ'), 'Recruitment'),
        (('uniform', 'supply', 'পোশাক'), 'Uniform'),
        (('manager', 'ম্যানেজার'), 'Inform to Manager'),
        (('todo', 'to-do', 'work item', 'task', 'কাজ'), 'To-Do / Follow-Up'),
    ]:
        if any(term in t for term in terms):
            return name
    return 'Notification Center / cross-module'


def kind(text):
    t = text.lower()
    tags = []
    for terms, label in [
        (('notification', 'push', 'reminder', 'digest', 'alert', 'নোটিফিকেশন', 'সতর্কতা'), 'notification'),
        (('source', 'status', 'deadline', 'decision', 'approval', 'work item', 'সিদ্ধান্ত', 'সময়সীমা'), 'source data'),
        (('ui', 'screen', 'view', 'badge', 'inbox', 'ড্যাশবোর্ড'), 'UI'),
        (('security', 'auth', 'rls', 'privacy', 'গোপনীয়তা'), 'security'),
        (('cron', 'test', 'audit', 'policy', 'migration', 'health', 'পলিসি'), 'operational'),
    ]:
        if any(word in t for word in terms):
            tags.append(label)
    return ', '.join(tags) or 'source data / operational (review)'


def policy(text):
    t = text.lower()
    if any(x in t for x in ('প্রস্তাবিত', 'প্রস্তাব', 'proposed', 'pilot', 'অনুমোদন', 'opt-in', 'cutoff', 'holiday', 'সাপ্তাহিক ছুটি')):
        return 'Proposed / owner review (verify exact wording)'
    return 'Rulebook requirement (source policy verification pending)'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rulebook', type=Path)
    ap.add_argument('output', type=Path)
    args = ap.parse_args()
    src = args.rulebook.read_text(encoding='utf-8')
    rules = {k: {} for k in ('BR', 'AT')}
    for match in RULE.finditer(src):
        prefix, number, body = match.groups()
        number = int(number)
        if number in rules[prefix]:
            raise ValueError(f'duplicate {prefix}-{number:03}')
        rules[prefix][number] = cell(body)
    for prefix, count in (('BR', 385), ('AT', 69)):
        if set(rules[prefix]) != set(range(1, count + 1)):
            raise ValueError(f'{prefix} inventory incomplete: {len(rules[prefix])}/{count}')

    lines = [
        '# Notification-centric Rulebook v1.1 traceability — baseline inventory',
        '',
        'Generated from the actual Rulebook; every numbered behavior is reproduced below. '
        'This is an **honest unverified baseline**, not a completion claim. '
        'Module and type labels are search aids inferred from wording; a human must verify them. '
        'A blank evidence cell means no passing evidence has been collected.',
        '',
        'The product owner’s latest direction maps work-management behaviors into existing To-Do, '
        'Follow-Up, Notification Center and source modules. It does not authorize a new Smart Work screen.',
        '',
        '## Business rules (385)', '',
        '| ID | Exact Rulebook behavior | Existing module (candidate) | Type (candidate) | Policy classification | Status | Required change / gap | Location | Automated tests | Evidence | Production activation | Blocked decision |',
        '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |',
    ]
    preview_rules = {3, 31, 32, 100, 115, 116, 117, 118, 119, 120, 122, 124, 125, 126, 132, 366, 368, 371}
    privacy_rules = {44, 174, 273}
    for n, body in sorted(rules['BR'].items()):
        preview = n in preview_rules
        privacy = n in privacy_rules
        lines.append('| ' + ' | '.join([
            f'BR-{n:03}', body, module(body), kind(body), policy(body),
            'Partially Implemented' if preview or privacy else 'Not Implemented',
            'Complete pipeline compatibility and test exact behavior' if preview or privacy else 'Determine exact source semantics; implement or document scoped mapping',
            ('`20261023021912_notification_governance_v2_preview.sql` (inactive); '
             '`20261023043016_governance_todo_repeat_gate.sql` (unapplied)') if preview else
            ('`20261023031049_salary_todo_push_privacy.sql` (unapplied)' if privacy else 'TBD in existing modules'),
            'tests/governance-repeat-gate.test.mjs' if n in (32, 115, 116) else
            ('tests/salary-push-privacy.test.mjs' if privacy else 'TBD'),
            'Isolated synthetic test passed; full rule remains unverified' if n in (32, 115, 116) or privacy else
            ('Preview function exists; no passing rule-specific AT' if preview else '—'),
            'Preview flag off / migration unapplied' if preview else
            ('Migration unapplied' if privacy else 'No verified V2 activation'),
            'Review proposed defaults / source semantics as applicable',
        ]) + ' |')
    lines += [
        '', '## Acceptance tests (69)', '',
        '| ID | Exact expected result from Rulebook | Environment | Setup / synthetic data | Actual result | Automation source | Status | Evidence | Release impact |',
        '| --- | --- | --- | --- | --- | --- | --- | --- | --- |',
    ]
    for n, body in sorted(rules['AT'].items()):
        lines.append('| ' + ' | '.join([
            f'AT-{n:03}', body, 'Isolated PostgreSQL + browser/device as needed',
            'TBD; synthetic only', 'Not run', 'TBD', 'Blocked', '—',
            'Cannot claim complete release until exercised',
        ]) + ' |')
    lines += ['', '## Verification rules', '',
              '- Change one row only after naming implementation location and executable test evidence.',
              '- “Implemented but Inactive” requires an executable test and the precise disabled flag.',
              '- Proposed defaults cannot become official policy through this inventory.',
              '- Record test date, environment, synthetic fixture and actual result before Pass.', '']
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text('\n'.join(lines), encoding='utf-8')
    print(f'Wrote {len(rules["BR"])} BR + {len(rules["AT"])} AT to {args.output}')


if __name__ == '__main__':
    main()
