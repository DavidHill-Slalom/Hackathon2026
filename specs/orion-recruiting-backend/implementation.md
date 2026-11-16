# Implementation Evidence: Orion Recruiting Backend

## Approved Scope

- Feature branch: `feature/orion-recruiting-backend`
- Build/test org: `hackathon2026` (Slalom Developer Edition, org ID `00Dbm000016scltEAA`)
- Production deployment: not authorized; planned as a separate later release
- Permission-set assignments: intentionally left unassigned per user direction
- Existing user changes preserved: modified `README.md` and deleted `MyClass.cls`

## Increments and Evidence

| Increment | Deliverables | Verification | Result |
|---|---|---|---|
| 1. Lifecycle data model | Five private custom objects, fields, picklists, and `Interviewer_Required` validation rule | Salesforce dry-run, deploy ID `0Afbm00000o4r7NCAQ` | Passed, 37/37 components; no tests applicable |
| 2. Access metadata | Four permission sets, `Portal Profile` public-field access, Published-only guest sharing rule | Salesforce dry-run, deploy ID `0Afbm00000o4sOQCAY` | Passed, 44/44 components; no tests applicable |
| 3. Sharing service and triggers | Bulkified Apex share reconciliation and four triggers, including interview/application reassignment handling | Salesforce dry-run, deploy ID `0Afbm00000o4oJCCAY` | Passed; Apex compiled |
| 4. Security and behavior tests | Eight rigorous Apex scenarios for record access in user mode, recruiter and hiring-manager salary FLS, feedback persistence, reassignment/revocation, application delete/undelete, and 200-record bulk behavior | Specified-test dry-run, deploy ID `0Afbm00000o5DHaCAM` | Passed; 8 tests executed, no test failures, component failures, or coverage warnings |
| 5. Feature manifest | `manifest/orion-recruiting-backend-package.xml` | Latest manifest deployment, deploy ID `0Afbm00000o5YHBCA2` | Succeeded; 55 components deployed, 8 tests completed, no component or test failures |
| 6. Pull request | Feature branch pushed and PR opened against `main` | Commit `2c897b5`; [PR #1](https://github.com/DavidHill-Slalom/Hackathon2026/pull/1) | Open |

## Current Source

- `force-app/main/default/objects/`: five recruiting objects, fields, sharing reasons, and interviewer validation
- `force-app/main/default/permissionsets/`: recruiter, hiring-manager, interviewer, and confidential-compensation access
- `force-app/main/default/profiles/Portal Profile.profile-meta.xml`: read-only access to public posting fields
- `force-app/main/default/sharingRules/Job_Posting__c.sharingRules-meta.xml`: Portal guest access for Published postings only
- `force-app/main/default/classes/`: sharing service and eight-scenario test suite
- `force-app/main/default/triggers/`: posting, application, interview, and interviewer-assignment triggers
- `manifest/orion-recruiting-backend-package.xml`: feature-scoped deployment manifest

## Pending Checks and Held Actions

- The final manifest deployment changed only the `hackathon2026` Developer Edition org. Production remains a later release target and was not touched.
- PR #1 is open from `feature/orion-recruiting-backend` to `main`; no merge has occurred.
- Permission sets are not assigned to users. Confirm the recruiter and hiring-manager roster before assignment; interviewers receive their set only when authorized.
- The `Portal` site is Under Construction. Runtime guest access to Published postings and denial of confidential fields remain to be verified in the experience site.
- Validate Salesforce Files visibility for application-linked resumes/cover letters with a restricted user; no public file access is configured.
- Verify production currency settings, site/guest profile, and existing metadata before any future production package is prepared.
- Candidate-facing pages, application submission/upload UI, automated email notifications, scheduled posting expiry, and production deployment remain out of scope for this increment.