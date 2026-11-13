# Design for Orion Recruiting Backend

## Features to Implement

Create a secure Salesforce backend foundation for Orion Technologies' recruiting lifecycle. Recruiters manage job postings; candidates can be represented across multiple applications; recruiters schedule interviews with one or more employees; and candidate documents and interview feedback are associated with the relevant application.

The MVP includes the lifecycle data model, least-privilege permission metadata, public read access to published job postings, and record sharing for assigned recruiters, hiring managers, and interviewers. Candidate-facing pages, application submission/upload UI, automated email notifications, and interview scheduling UI are deferred.

### Acceptance Criteria

- Recruiters can manage the recruiting records in scope; records are not generally visible to other employees.
- Public/guest users can read published job postings and cannot read target salary, recruiter, or hiring-manager fields.
- A candidate can be related to multiple job applications, while each application relates to one candidate and one posting.
- Recruiters and the hiring manager assigned to a posting can access its applications and candidate records.
- An employee invited to an interview can read only the related application, candidate details, application files, interview records, and feedback for that application. They cannot read confidential compensation or hiring-manager fields.
- An invited interviewer can create or update their own interview feedback; access to another application's recruiting data is not granted.
- Target salary minimum and maximum are stored as currency fields and are readable only by recruiters and assigned hiring managers.
- Resume and cover-letter files are linked to the application, not directly to the candidate, to avoid exposing files across that candidate's applications.

## Findings

| Fact | Evidence | Checked |
|---|---|---|
| The README contains the Orion recruiting brief, including public postings, applications, interviews, candidate documents, confidential salary/hiring-manager data, and invite-only employee access. | `README.md` | 2026-11-13 |
| The local source has no recruiting objects/classes/flows/permission sets; the only Apex trigger validates Account Name. | `force-app/main/default/objects`, `classes`, `flows`, `permissionsets`, `triggers/AccountTrigger.trigger` | 2026-11-13 |
| No usable architecture map is present. | `architecture/.analysis/review-snapshot/` is empty; `review-state.json` is draft-review state only. | 2026-11-13 |
| The scratch definition is Developer Edition and enables Communities. | `config/project-scratch-def.json` | 2026-11-13 |
| The configured default org alias `hackathon2026` identifies as `Slalom`, Developer Edition (org ID `00Dbm000016scltEAA`), not Orion production. No Orion production org has been verified. | Read-only `Organization` query against alias `hackathon2026` | 2026-11-13 |
| The user designated `hackathon2026` Developer Edition as the build/test org and production as a later release target. A bounded `EntityDefinition` search found no recruiting-specific object names; this is not a complete metadata inventory. | User direction and read-only `EntityDefinition` query against `hackathon2026` | 2026-11-13 |
| The developer org has USD as its only active corporate currency. Its multi-currency setting and the future production org's currency behavior are not verified. | Read-only `CurrencyType` query against `hackathon2026`; queried Organization fields do not expose a currency flag. | 2026-11-13 |
| Salesforce requires a validation rule to enforce a populated User lookup; a required User lookup with `Restrict` or `Cascade` delete behavior is rejected. | Dry-run validation of `Interviewer_Assignment__c.Interviewer__c` in `hackathon2026`. | 2026-11-13 |
| The dev org has an active guest user for the `Portal` network, currently Under Construction. Its `Portal Profile` contains only its guest license declaration, and no recruiting permission sets exist. | Read-only `Network`, `User`, `PermissionSet`, and `Profile` metadata queries/retrieval against `hackathon2026`; profile snapshot is under ignored `.sf/analysis/00Dbm000016scltEAA/20261113/`. | 2026-11-13 |
| The five-object model, access metadata, Apex sharing service, and triggers validate in `hackathon2026`; all eight selected Apex tests pass with no component failures or coverage warnings. | Latest manifest deployment and report for `RecruitingSharingServiceTest`; deploy ID `0Afbm00000o5YHBCA2`. | 2026-11-13 |

## Resolved Decisions

| Decision | Rationale / evidence | Date |
|---|---|---|
| Model the recruiting lifecycle, not only job listings. | User selected the core lifecycle data model after the README brief was surfaced. | 2026-11-13 |
| Include the secure backend: data model, invite-based record sharing, and least-privilege permissions. Defer candidate-facing pages, upload UI, and email automation. | User selected secure backend scope. | 2026-11-13 |
| Public users browse published postings; candidate application submission is not part of this MVP. | User selected public and internal listing audience; candidate-facing submission UI was deferred. | 2026-11-13 |
| Store salary as a confidential minimum/maximum currency range. | User selected range; visibility is limited to recruiters and the assigned hiring manager. | 2026-11-13 |
| Interviewer access is application-scoped. | User confirmed access to the assigned application, candidate documents, and feedback only, without salary or hiring-manager fields. | 2026-11-13 |
| Use a custom Candidate object rather than reusing Contact. | Candidate information has a distinct privacy boundary; no existing Contact usage or org architecture was available to validate reuse. | 2026-11-13 |
| Use Salesforce Files linked to Job Application records. | The brief requires resumes and cover letters; application-scoped links avoid accidental cross-application disclosure. | 2026-11-13 |
| Use `hackathon2026` Developer Edition for build and testing; production deployment is a later release activity. | User explicitly selected the developer org for working through bugs before a later production deployment. | 2026-11-13 |
| Use the initial controlled values: departments Engineering, Product, Sales, Marketing, Finance, People, and Operations; employment types Full-time, Part-time, Contract, Temporary, and Internship; application statuses Submitted, In Review, Interview, Offer, Hired, Rejected, and Withdrawn; interviewer recommendations Strong Yes, Yes, No, and Strong No. | User approved these values for the MVP. | 2026-11-13 |
| Enforce interviewer assignment presence with `Interviewer_Required` validation rule rather than field-level required metadata. | Salesforce rejects required User lookups with the delete behavior necessary for a required foreign key. | 2026-11-13 |
| Configure public listing access through the existing `Portal` guest group and its profile, not a guessed generic guest group. | Dev org identifies group `Portal` as `GuestUserGroup` and profile `Portal Profile` as `Guest User License`. | 2026-11-13 |
| Include an `InterviewTrigger` so moving an interview to another application recalculates both old and new access. | Initial tests revealed that without this trigger, prior application shares could remain after a move. User approved the scope expansion. | 2026-11-13 |
| Use rigorous Apex tests for row-level access, user-mode CRUD/FLS, reassignment, delete/undelete, and 200-record bulk behavior. | User approved the test plan and coverage-driven additions; all eight tests pass in the dev deployment. | 2026-11-13 |
| Work on `feature/orion-recruiting-backend`; preserve the pre-existing README modification and `MyClass.cls` deletion. | User approved carrying both changes onto a feature branch. | 2026-11-13 |

## Assumptions

| Assumption | Consequence if wrong | Verification / owner |
|---|---|---|
| Orion is the sole employer represented by this recruiting app, so a separate employer Account relationship is unnecessary. | Multi-employer hiring would require an employer relationship and additional sharing boundaries. | Confirm with product owner before implementation. |
| Candidate identity is stored in a private `Candidate__c` record and can be created by a future trusted application channel. | If candidates must authenticate or be matched to existing Contacts, identity and external-user design changes. | Resolve before building candidate submission UI. |
| Recruiters can access the recruiting pipeline broadly; hiring-manager access is limited to postings assigned to them. | A narrower recruiter team boundary or broader leadership access requires different sharing groups. | Confirm roster and intended access during permission assignment. |
| An invited interviewer may read existing feedback for the same application, but may edit only their own feedback record. | If feedback must be private between interviewers, the sharing design must be narrowed. | Confirm with recruiting leadership before implementation. |
| A posting is public while its status is `Published`; recruiters manually change status when it closes. | Without date-driven automation, an overdue posting could remain visible until status is updated. | Confirm; automated expiry is deferred. |
| Department, work mode, employment type, application status, and interview status values below are initial proposals. | Actual Orion terminology may require a metadata update. | Product owner to approve values before build. |
| Currency fields use the target org's configured currency behavior. | Salary display and conversion may differ if multi-currency is disabled or configured differently. | Verify in the approved Orion org before deployment. |

## Open Questions

| Question | Recommendation | Needed by |
|---|---|---|
| What is the approved Orion production org alias? | Keep production separate from `hackathon2026`; do not deploy until the alias and deployment decision are explicitly confirmed. | Before production deployment |
| Will production use a public Experience Cloud site and guest profile corresponding to `Portal` / `Portal Profile`? | Retrieve the production guest profile and adapt the site-specific sharing rule/profile permissions during release preparation. | Before production deployment |
| What currency behavior and allowed currencies should production use? | Build with Currency fields; verify multi-currency and salary display in production before release. | Before production deployment |
| What candidate authentication and upload channel will be used later? | Decide Experience Cloud/authentication and guest upload handling separately; do not grant guests access to candidate/application records in this MVP. | Before candidate-facing UI |
| Does sharing a Job Application to an interviewer provide the intended access to its linked Salesforce Files in the Orion org? | Verify inferred file sharing with a restricted-user test; explicitly share files only if required. | During security validation |

## Technical Notes

- Use custom objects because the local project contains no recruiting data model and no target-org metadata has been reviewed.
- Keep custom-object organization-wide defaults Private. Permission sets grant CRUD/FLS; record sharing separately controls which records a user can access.
- Use programmatic sharing for posting assignees, application owners, and interview participants. A bulkified Apex service should be called from one trigger per relevant object; shares must be recalculated when assignees or an interview's application change and revoked when an interviewer is removed.
- The interviewer permission set grants read access to candidate/application/interview data and edit access only to their feedback assignment. Compensation fields are omitted from this permission set.
- Use a separate compensation permission set for recruiters and hiring managers. Private record sharing still limits which postings they can see.
- Configure guest-user read sharing only for `Published` postings. The `Portal Profile` grants read access only to public posting fields; it grants no candidate, application, interview, file, salary, recruiter, or hiring-manager access.
- Link Files to `Job_Application__c` only. Do not set public file visibility. Validate how inferred file access behaves in the approved target org.
- Notification emails on new applications and UI/Experience Cloud components are explicitly out of scope.
- The user-approved build/test target is `hackathon2026` (Slalom Developer Edition), not Orion production. No production deployment is authorized by this design.

## Metadata to Create/Modify and the Order to Create Them

1. **Objects and fields**
   - `Job_Posting__c` (Private): `Title__c` (Text, required), `Public_Description__c` (Long Text Area), `Department__c` (picklist: Engineering, Product, Sales, Marketing, Finance, People, Operations), `Location__c` (Text), `Work_Mode__c` (picklist: Onsite, Hybrid, Remote), `Employment_Type__c` (picklist: Full-time, Part-time, Contract, Temporary, Internship), `Status__c` (picklist: Draft, Published, Closed; default Draft), `Posting_Date__c` (Date), `Closing_Date__c` (Date), `Target_Salary_Min__c` (Currency), `Target_Salary_Max__c` (Currency), `Recruiter__c` (Lookup to User), and `Hiring_Manager__c` (Lookup to User).
   - `Candidate__c` (Private): `First_Name__c` (Text, required), `Last_Name__c` (Text, required), `Email__c` (Email, required), and `Phone__c` (Phone).
   - `Job_Application__c` (Private): required lookups to `Candidate__c` and `Job_Posting__c`, `Status__c` (picklist: Submitted, In Review, Interview, Offer, Hired, Rejected, Withdrawn; default Submitted), and `Submitted_Date__c` (DateTime).
   - `Interview__c` (Private): required lookup to `Job_Application__c`, `Start_Date_Time__c` (DateTime), `End_Date_Time__c` (DateTime), `Location__c` (Text), and `Status__c` (picklist: Scheduled, Completed, Cancelled).
   - `Interviewer_Assignment__c` (Private): required lookup to `Interview__c`, `Interviewer__c` (Lookup to User; presence enforced by validation rule), `Feedback__c` (Long Text Area), `Recommendation__c` (picklist: Strong Yes, Yes, No, Strong No), and `Feedback_Submitted_Date__c` (Date).
   - Validation rule `Interviewer_Required` prevents assignments without an employee user.
   - Use Salesforce Files (`ContentDocument` / `ContentDocumentLink`) for resumes and cover letters; no custom file-storage object.
2. **Access metadata**
   - Permission sets for recruiter, hiring manager, and interviewer access, plus a compensation permission set limited to recruiters and assigned hiring managers.
   - `Portal Profile` read-only object and public-field permissions, plus a guest-user sharing rule targeting the `Portal` GuestUserGroup for `Job_Posting__c` records with `Status__c = Published`.
   - Add Apex sharing reasons and sharing logic for assigned recruiters/hiring managers and interview participants; preserve least privilege and support bulk changes/revocation.
3. **Apex sharing service, triggers, and tests**
   - One handler-style trigger each for posting assignment changes, application creation/assignment/delete/undelete, interview parent changes, and interviewer assignment changes, backed by a bulkified sharing service.
   - Apex tests for positive and negative sharing, posting-assignee changes, interviewer reassignment/revocation, interview reassignment/revocation, application reassignment/delete/undelete, FLS, and 200-record bulk input; restricted-user tests prove unrelated applications and confidential fields remain inaccessible.
4. **Feature manifest**
   - Add `manifest/orion-recruiting-backend-package.xml` containing only approved metadata created for this feature.

## Scope

| Acceptance criterion | Metadata / API name | Change | Dependency / order | Proposed verification | Manifest |
|---|---|---|---|---|---|
| Recruiters create and manage postings with public and confidential fields. | `Job_Posting__c` and fields | Create | First | Metadata deploy; recruiter and interviewer FLS checks | Yes |
| Candidates apply to multiple postings; applications have private status/date data. | `Candidate__c`, `Job_Application__c` | Create | After postings | Relationship/data tests; private OWD negative access test | Yes |
| Interview schedules and per-interviewer feedback are represented; each assignment must name an employee. | `Interview__c`, `Interviewer_Assignment__c`, `Interviewer_Required` validation rule | Create | After applications | Relationship tests; blank interviewer rejected; assigned interviewer access tests | Yes |
| Published listings are readable publicly without confidential data. | `Portal Profile`, `Job_Posting__c` guest sharing rule and FLS | Create/modify | After posting fields; target the existing Portal site guest group | Guest-user read of Published only; no salary/hiring-manager access | Yes |
| Assigned employees see only records for their interviews and can edit only their own feedback, including after an interview moves applications. | Apex sharing service, triggers, sharing reasons, permission sets | Create | After all objects | `runAs` tests for invite, unrelated record denial, interviewer/interview reassignment, revocation, and bulk behavior | Yes |
| Posting and application reassignment, deletion, and restoration update related shares without leaving stale grants. | `JobPostingTrigger`, `JobApplicationTrigger`, `RecruitingSharingService` | Create | After object and sharing metadata | Old assignee loses access; new assignee gains access; delete removes shares; undelete restores expected shares | Yes |
| Feature deployment is scoped to recruiting metadata. | `manifest/orion-recruiting-backend-package.xml` | Create | After all components | Validate manifest contents and dry-run in an approved non-production target | Deployment manifest |

## Configuration Surface

- **Department and employment types:** restricted picklists with the user-approved MVP values.
- **Application status and recommendation values:** restricted picklists with the user-approved MVP values.
- **Posting visibility:** governed by the `Status__c` value `Published`; records are closed by an authorized recruiter. Automated scheduled expiry is not part of this increment.
- **Compensation access:** permission-set assignment plus private record sharing; no salary value or role identifier is hard-coded in Apex.

## UI/UX Notes

No UI is included in this increment. The backend is intended to support a future public job-listing experience and recruiter workspace.

## Steps to Implement Features

- [ ] Step 1: Confirm candidate identity assumptions and inspect relevant metadata in `hackathon2026` before implementation; verify production currency behavior before release.
- [ ] Step 2: Create the lifecycle objects and fields in dependency order, preserving Private sharing defaults.
- [ ] Step 3: Add role permission sets, compensation field permissions, and published-listing guest read sharing.
- [ ] Step 4: Add bulkified record-sharing logic for recruiters, hiring managers, and interviewers, including posting/application reassignment, interview-parent changes, and revocation behavior.
- [ ] Step 5: Add and run Apex security tests; verify guest access, file access, and negative access cases in a non-production org. Eight focused Apex tests currently pass in `hackathon2026`.
- [ ] Step 6: Create the feature manifest, validate the package in `hackathon2026`, and present the scoped diff and test evidence. Do not deploy to production without a separately confirmed target and deployment decision.
