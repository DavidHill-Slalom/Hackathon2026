# Code Review: Orion Recruiting Backend

- Reviewed change set: `main...feature/orion-recruiting-backend` plus untracked feature files; unrelated README modification and `MyClass.cls` deletion excluded from PR scope
- Story and design: [design.md](design.md); requirements source is the Orion brief in `README.md`
- Rubric: bundled code-review skill rubric (`skills/code-review/references/severity-rubric.md`)
- Test and deployment evidence: [implementation.md](implementation.md); latest dev deployment `0Afbm00000o5YHBCA2`, 55 components, 8 tests completed, no failures
- Lens status: behavior complete after reconciliation; security complete after reconciliation; architecture complete; tests complete after rubric reconciliation
- Review status: complete

## Ranked Suggested Fixes

No actionable code findings were confirmed after reconciling all four lenses against the source, successful deployment, and bundled severity rubric.

## Disagreements or Evidence Gaps

- The repeated claim that `Title__c` is inaccessible to guests was not confirmed. Salesforce rejected explicit FLS entries for schema-required fields, and the recruiter user-mode test verifies required title access; actual guest-site behavior remains unverified because `Portal` is Under Construction. Do not treat this evidence gap as a confirmed exposure.
- The manager-compensation claim was refuted: the test setup assigns `Recruiting_Confidential_Compensation` to both recruiter and hiring manager ([RecruitingSharingServiceTest.cls](../../force-app/main/default/classes/RecruitingSharingServiceTest.cls#L50-L51)); the latest user-mode test asserts salary FLS for both roles.
- The claim that `InterviewTrigger` re-queries only the new application was refuted: it collects both old and new application IDs and passes them directly to `refresh()` ([InterviewTrigger.trigger](../../force-app/main/default/triggers/InterviewTrigger.trigger#L12-L23)).
- The suite includes user-mode CRUD, manager read-only denial, outside-user denial, application-scoped interviewer checks, and 200-record bulk behavior. The bundled HIGH-3 and HIGH-4 criteria are not met; absence of guest/file runtime tests is an evidence gap, not a high finding under the rubric.
- Including `RecruitingSharingServiceTest` in the manifest is valid Salesforce Apex metadata and was accepted by successful deployment.
- `syncShares()` uses standard DML and allows exceptions to propagate; Salesforce transaction rollback prevents the reported partial-share state. The static `SHARE_REASON` concatenation is not caller-controlled and creates no actionable injection finding.
- Application-linked Salesforce Files were not exercised. Candidate-facing upload UI is deferred; validate file visibility with a restricted user before introducing upload or production release.

## PR Decision

 The user approved the user-mode role-access and manager salary FLS test additions; both are implemented and pass in deployment `0Afbm00000o5YHBCA2`. PR [#1](https://github.com/DavidHill-Slalom/Hackathon2026/pull/1) is open from `feature/orion-recruiting-backend` to `main`; no merge has occurred.