/**
 * @description Verifies recruiting record sharing, field access, revocation, and bulk behavior.
 * @author Slalom
 */
@isTest
private with sharing class RecruitingSharingServiceTest {
    private static final String TEST_LAST_NAME = 'Recruiting Test';

    @TestSetup
    static void createUsersAndPermissions() {
        Profile standardProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];
        String uniqueSuffix = String.valueOf(DateTime.now().getTime());
        List<User> testUsers = new List<User>{
            buildUser(standardProfile.Id, 'recruit', 'recruiter.' + uniqueSuffix),
            buildUser(standardProfile.Id, 'manager', 'manager.' + uniqueSuffix),
            buildUser(standardProfile.Id, 'intervA', 'interviewer.a.' + uniqueSuffix),
            buildUser(standardProfile.Id, 'intervB', 'interviewer.b.' + uniqueSuffix),
            buildUser(standardProfile.Id, 'outside', 'outside.' + uniqueSuffix)
        };
        insert testUsers;

        Set<String> permissionSetNames = new Set<String>{
            'Recruiting_Recruiter_Access',
            'Recruiting_Hiring_Manager_Access',
            'Recruiting_Interviewer_Access',
            'Recruiting_Confidential_Compensation'
        };
        Map<String, Id> permissionSetIds = new Map<String, Id>();
        for (PermissionSet permissionSet : [
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name IN :permissionSetNames
        ]) {
            permissionSetIds.put(permissionSet.Name, permissionSet.Id);
        }
        System.assertEquals(4, permissionSetIds.size(), 'All recruiting permission sets must be deployed with the tests.');

        Map<String, User> usersByAlias = new Map<String, User>();
        for (User testUser : testUsers) {
            usersByAlias.put(testUser.Alias, testUser);
        }
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        addPermissionSet(assignments, permissionSetIds, usersByAlias.get('recruit'), 'Recruiting_Recruiter_Access');
        addPermissionSet(assignments, permissionSetIds, usersByAlias.get('recruit'), 'Recruiting_Confidential_Compensation');
        addPermissionSet(assignments, permissionSetIds, usersByAlias.get('manager'), 'Recruiting_Hiring_Manager_Access');
        addPermissionSet(assignments, permissionSetIds, usersByAlias.get('manager'), 'Recruiting_Confidential_Compensation');
        addPermissionSet(assignments, permissionSetIds, usersByAlias.get('intervA'), 'Recruiting_Interviewer_Access');
        addPermissionSet(assignments, permissionSetIds, usersByAlias.get('intervB'), 'Recruiting_Interviewer_Access');
        insert assignments;
    }

    @isTest
    static void testRecruitingAndHiringManagerShares() {
        User recruiter = getUser('recruit');
        User hiringManager = getUser('manager');
        Candidate__c candidate = createCandidate('Candidate One');
        Job_Posting__c posting = createPosting(recruiter.Id, hiringManager.Id, 'Platform Engineer');
        Job_Application__c application = createApplication(candidate.Id, posting.Id);

        System.assertEquals('Edit', getShareAccess('Job_Posting', posting.Id, recruiter.Id));
        System.assertEquals('Read', getShareAccess('Job_Posting', posting.Id, hiringManager.Id));
        System.assertEquals('Edit', getShareAccess('Job_Application', application.Id, recruiter.Id));
        System.assertEquals('Read', getShareAccess('Job_Application', application.Id, hiringManager.Id));
        System.assertEquals('Edit', getShareAccess('Candidate', candidate.Id, recruiter.Id));
        System.assertEquals('Read', getShareAccess('Candidate', candidate.Id, hiringManager.Id));
    }

    @isTest
    static void testRecruiterAndHiringManagerUserModeAccess() {
        User recruiter = getUser('recruit');
        User hiringManager = getUser('manager');
        User outsideUser = getUser('outside');
        Candidate__c candidate = createCandidate('User Mode Candidate');
        Job_Posting__c posting = createPosting(recruiter.Id, hiringManager.Id, 'User Mode Role');
        createApplication(candidate.Id, posting.Id);

        System.runAs(recruiter) {
            Job_Posting__c createdPosting = new Job_Posting__c(
                Title__c = 'Recruiter Created Role',
                Department__c = 'Engineering',
                Work_Mode__c = 'Remote',
                Employment_Type__c = 'Full-time',
                Status__c = 'Draft',
                Recruiter__c = recruiter.Id,
                Hiring_Manager__c = hiringManager.Id
            );
            Database.insert(createdPosting, AccessLevel.USER_MODE);

            List<Job_Posting__c> visiblePostings = [
                SELECT Id, Title__c
                FROM Job_Posting__c
                WHERE Id = :posting.Id
                WITH USER_MODE
            ];
            System.assertEquals(1, visiblePostings.size(), 'Recruiters should read assigned postings.');
            visiblePostings[0].Title__c = 'Recruiter Updated Role';
            Database.update(visiblePostings[0], AccessLevel.USER_MODE);
        }

        System.runAs(hiringManager) {
            List<Job_Posting__c> visiblePostings = [
                SELECT Id, Title__c
                FROM Job_Posting__c
                WHERE Id = :posting.Id
                WITH USER_MODE
            ];
            System.assertEquals(1, visiblePostings.size(), 'Hiring managers should read assigned postings.');
            System.assertEquals(true,
                Schema.SObjectType.Job_Posting__c.fields.Target_Salary_Min__c.isAccessible());
            System.assertEquals(true,
                Schema.SObjectType.Job_Posting__c.fields.Target_Salary_Max__c.isAccessible());

            Boolean updateRejected = false;
            try {
                Database.update(
                    new Job_Posting__c(Id = posting.Id, Title__c = 'Manager Update'),
                    AccessLevel.USER_MODE
                );
            } catch (Exception exceptionValue) {
                updateRejected = true;
            }
            System.assertEquals(true, updateRejected, 'Hiring managers must not edit job postings.');
        }

        System.runAs(outsideUser) {
            Boolean queryRejected = false;
            try {
                List<Job_Posting__c> visiblePostings = [
                    SELECT Id
                    FROM Job_Posting__c
                    WHERE Id = :posting.Id
                    WITH USER_MODE
                ];
                System.assertEquals(0, visiblePostings.size(), 'Unprivileged users must not see recruiting records.');
            } catch (QueryException exceptionValue) {
                queryRejected = true;
            }
            System.assertEquals(true, queryRejected, 'Unprivileged users must not have Job Posting read access.');
        }
    }

    @isTest
    static void testPostingAssigneeChangesReconcileShares() {
        User previousRecruiter = getUser('recruit');
        User previousHiringManager = getUser('manager');
        User newRecruiter = getUser('intervA');
        User newHiringManager = getUser('intervB');
        Job_Posting__c posting = createPosting(previousRecruiter.Id, previousHiringManager.Id, 'Assignee Change Role');

        posting.Recruiter__c = newRecruiter.Id;
        posting.Hiring_Manager__c = newHiringManager.Id;
        update posting;

        System.assertEquals(null, getShareAccess('Job_Posting', posting.Id, previousRecruiter.Id));
        System.assertEquals(null, getShareAccess('Job_Posting', posting.Id, previousHiringManager.Id));
        System.assertEquals('Edit', getShareAccess('Job_Posting', posting.Id, newRecruiter.Id));
        System.assertEquals('Read', getShareAccess('Job_Posting', posting.Id, newHiringManager.Id));
    }

    @isTest
    static void testInterviewerAccessIsApplicationScoped() {
        User recruiter = getUser('recruit');
        User hiringManager = getUser('manager');
        User interviewer = getUser('intervA');
        User otherInterviewer = getUser('intervB');
        Candidate__c assignedCandidate = createCandidate('Assigned Candidate');
        Candidate__c otherCandidate = createCandidate('Other Candidate');
        Job_Posting__c firstPosting = createPosting(recruiter.Id, hiringManager.Id, 'Role One');
        Job_Posting__c secondPosting = createPosting(recruiter.Id, hiringManager.Id, 'Role Two');
        Job_Application__c assignedApplication = createApplication(assignedCandidate.Id, firstPosting.Id);
        Job_Application__c otherApplication = createApplication(otherCandidate.Id, secondPosting.Id);
        Interview__c assignedInterview = createInterview(assignedApplication.Id);
        Interview__c otherInterview = createInterview(otherApplication.Id);
        Interviewer_Assignment__c ownAssignment = createAssignment(assignedInterview.Id, interviewer.Id);
        Interviewer_Assignment__c otherAssignment = createAssignment(otherInterview.Id, otherInterviewer.Id);

        System.runAs(interviewer) {
            System.assertEquals(1, [SELECT Id FROM Job_Application__c WHERE Id = :assignedApplication.Id].size());
            System.assertEquals(0, [SELECT Id FROM Job_Application__c WHERE Id = :otherApplication.Id].size());
            System.assertEquals(1, [SELECT Id FROM Candidate__c WHERE Id = :assignedCandidate.Id].size());
            System.assertEquals(1, [SELECT Id FROM Interview__c WHERE Id = :assignedInterview.Id].size());
            System.assertEquals(1, [SELECT Id FROM Interviewer_Assignment__c WHERE Id = :ownAssignment.Id].size());
            System.assertEquals(0, [SELECT Id FROM Interviewer_Assignment__c WHERE Id = :otherAssignment.Id].size());
            System.assertEquals(false,
                Schema.SObjectType.Job_Posting__c.fields.Target_Salary_Min__c.isAccessible());
            System.assertEquals(false,
                Schema.SObjectType.Job_Posting__c.fields.Target_Salary_Max__c.isAccessible());
            System.assertEquals(false,
                Schema.SObjectType.Job_Posting__c.fields.Hiring_Manager__c.isAccessible());

            ownAssignment.Feedback__c = 'Strong platform fundamentals.';
            ownAssignment.Recommendation__c = 'Yes';
            ownAssignment.Feedback_Submitted_Date__c = Date.today();
            update ownAssignment;
        }

        System.runAs(recruiter) {
            System.assertEquals(true,
                Schema.SObjectType.Job_Posting__c.fields.Target_Salary_Min__c.isAccessible());
            System.assertEquals(true,
                Schema.SObjectType.Job_Posting__c.fields.Target_Salary_Max__c.isAccessible());
            System.assertEquals(true,
                Schema.SObjectType.Job_Posting__c.fields.Hiring_Manager__c.isAccessible());
            Interviewer_Assignment__c savedAssignment = [
                SELECT Feedback__c, Recommendation__c, Feedback_Submitted_Date__c
                FROM Interviewer_Assignment__c
                WHERE Id = :ownAssignment.Id
            ];
            System.assertEquals('Strong platform fundamentals.', savedAssignment.Feedback__c);
            System.assertEquals('Yes', savedAssignment.Recommendation__c);
            System.assertEquals(Date.today(), savedAssignment.Feedback_Submitted_Date__c);
        }
    }

    @isTest
    static void testReassignmentRevokesPreviousInterviewer() {
        User recruiter = getUser('recruit');
        User hiringManager = getUser('manager');
        User previousInterviewer = getUser('intervA');
        User newInterviewer = getUser('intervB');
        Candidate__c candidate = createCandidate('Reassignment Candidate');
        Job_Posting__c posting = createPosting(recruiter.Id, hiringManager.Id, 'Reassignment Role');
        Job_Application__c application = createApplication(candidate.Id, posting.Id);
        Interview__c interview = createInterview(application.Id);
        Interviewer_Assignment__c assignment = createAssignment(interview.Id, previousInterviewer.Id);

        assignment.Interviewer__c = newInterviewer.Id;
        update assignment;

        System.assertEquals(null, getShareAccess('Job_Application', application.Id, previousInterviewer.Id));
        System.assertEquals(null, getShareAccess('Candidate', candidate.Id, previousInterviewer.Id));
        System.assertEquals(null, getShareAccess('Interview', interview.Id, previousInterviewer.Id));
        System.assertEquals(null, getShareAccess('Interviewer_Assignment', assignment.Id, previousInterviewer.Id));
        System.assertEquals('Read', getShareAccess('Job_Application', application.Id, newInterviewer.Id));
        System.assertEquals('Edit', getShareAccess('Interviewer_Assignment', assignment.Id, newInterviewer.Id));
    }

    @isTest
    static void testInterviewMoveRevokesPriorApplicationAccess() {
        User recruiter = getUser('recruit');
        User hiringManager = getUser('manager');
        User interviewer = getUser('intervA');
        Candidate__c oldCandidate = createCandidate('Old Candidate');
        Candidate__c newCandidate = createCandidate('New Candidate');
        Job_Posting__c posting = createPosting(recruiter.Id, hiringManager.Id, 'Interview Move Role');
        Job_Application__c oldApplication = createApplication(oldCandidate.Id, posting.Id);
        Job_Application__c newApplication = createApplication(newCandidate.Id, posting.Id);
        Interview__c interview = createInterview(oldApplication.Id);
        Interviewer_Assignment__c assignment = createAssignment(interview.Id, interviewer.Id);

        interview.Job_Application__c = newApplication.Id;
        update interview;

        System.assertEquals(null, getShareAccess('Job_Application', oldApplication.Id, interviewer.Id));
        System.assertEquals(null, getShareAccess('Candidate', oldCandidate.Id, interviewer.Id));
        System.assertEquals('Read', getShareAccess('Job_Application', newApplication.Id, interviewer.Id));
        System.assertEquals('Read', getShareAccess('Candidate', newCandidate.Id, interviewer.Id));
        System.assertEquals('Read', getShareAccess('Interview', interview.Id, interviewer.Id));
        System.assertEquals('Edit', getShareAccess('Interviewer_Assignment', assignment.Id, interviewer.Id));
    }

    @isTest
    static void testBulkApplicationsCreateShares() {
        User recruiter = getUser('recruit');
        User hiringManager = getUser('manager');
        Job_Posting__c posting = createPosting(recruiter.Id, hiringManager.Id, 'Bulk Role');
        List<Candidate__c> candidates = new List<Candidate__c>();
        for (Integer index = 0; index < 200; index++) {
            candidates.add(new Candidate__c(
                First_Name__c = 'Candidate',
                Last_Name__c = 'Bulk ' + index,
                Email__c = 'bulk.' + index + '@example.invalid'
            ));
        }
        insert candidates;

        List<Job_Application__c> applications = new List<Job_Application__c>();
        Set<Id> candidateIds = new Set<Id>();
        for (Candidate__c candidate : candidates) {
            candidateIds.add(candidate.Id);
            applications.add(new Job_Application__c(
                Candidate__c = candidate.Id,
                Job_Posting__c = posting.Id,
                Status__c = 'Submitted'
            ));
        }

        Test.startTest();
        insert applications;
        Test.stopTest();

        List<Candidate__Share> candidateShares = [
            SELECT Id
            FROM Candidate__Share
            WHERE ParentId IN :candidateIds AND RowCause = 'Recruiting_Access__c'
        ];
        List<Job_Application__Share> applicationShares = [
            SELECT Id
            FROM Job_Application__Share
            WHERE ParentId IN :applications AND RowCause = 'Recruiting_Access__c'
        ];
        System.assertEquals(400, candidateShares.size(), 'Each candidate should be shared with recruiter and hiring manager.');
        System.assertEquals(400, applicationShares.size(), 'Each application should be shared with recruiter and hiring manager.');
    }

    @isTest
    static void testApplicationReassignmentAndDeleteUndeleteShares() {
        User previousRecruiter = getUser('recruit');
        User previousHiringManager = getUser('manager');
        User newRecruiter = getUser('intervA');
        User newHiringManager = getUser('intervB');
        Candidate__c previousCandidate = createCandidate('Previous Applicant');
        Candidate__c newCandidate = createCandidate('New Applicant');
        Job_Posting__c previousPosting = createPosting(previousRecruiter.Id, previousHiringManager.Id, 'Previous Posting');
        Job_Posting__c newPosting = createPosting(newRecruiter.Id, newHiringManager.Id, 'New Posting');
        Job_Application__c application = createApplication(previousCandidate.Id, previousPosting.Id);

        application.Candidate__c = newCandidate.Id;
        application.Job_Posting__c = newPosting.Id;
        update application;

        System.assertEquals(null, getShareAccess('Candidate', previousCandidate.Id, previousRecruiter.Id));
        System.assertEquals('Edit', getShareAccess('Candidate', newCandidate.Id, newRecruiter.Id));
        System.assertEquals(null, getShareAccess('Job_Application', application.Id, previousRecruiter.Id));
        System.assertEquals('Edit', getShareAccess('Job_Application', application.Id, newRecruiter.Id));

        delete application;
        System.assertEquals(null, getShareAccess('Candidate', newCandidate.Id, newRecruiter.Id));

        undelete application;
        System.assertEquals('Edit', getShareAccess('Candidate', newCandidate.Id, newRecruiter.Id));
        System.assertEquals('Edit', getShareAccess('Job_Application', application.Id, newRecruiter.Id));
    }

    private static User buildUser(Id profileId, String alias, String usernamePrefix) {
        String username = usernamePrefix + '@example.invalid';
        return new User(
            Alias = alias,
            Email = username,
            EmailEncodingKey = 'UTF-8',
            LastName = TEST_LAST_NAME,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileId,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = username
        );
    }

    private static void addPermissionSet(
        List<PermissionSetAssignment> assignments,
        Map<String, Id> permissionSetIds,
        User assignee,
        String permissionSetName
    ) {
        assignments.add(new PermissionSetAssignment(
            AssigneeId = assignee.Id,
            PermissionSetId = permissionSetIds.get(permissionSetName)
        ));
    }

    private static User getUser(String alias) {
        return [
            SELECT Id, Alias
            FROM User
            WHERE Alias = :alias AND LastName = :TEST_LAST_NAME
            LIMIT 1
        ];
    }

    private static Candidate__c createCandidate(String name) {
        List<String> nameParts = name.split(' ', 2);
        Candidate__c candidate = new Candidate__c(
            First_Name__c = nameParts[0],
            Last_Name__c = nameParts.size() > 1 ? nameParts[1] : 'Candidate',
            Email__c = name.toLowerCase().replace(' ', '.') + '@example.invalid'
        );
        insert candidate;
        return candidate;
    }

    private static Job_Posting__c createPosting(Id recruiterId, Id hiringManagerId, String title) {
        Job_Posting__c posting = new Job_Posting__c(
            Title__c = title,
            Department__c = 'Engineering',
            Work_Mode__c = 'Remote',
            Employment_Type__c = 'Full-time',
            Status__c = 'Draft',
            Recruiter__c = recruiterId,
            Hiring_Manager__c = hiringManagerId
        );
        insert posting;
        return posting;
    }

    private static Job_Application__c createApplication(Id candidateId, Id postingId) {
        Job_Application__c application = new Job_Application__c(
            Candidate__c = candidateId,
            Job_Posting__c = postingId,
            Status__c = 'Submitted'
        );
        insert application;
        return application;
    }

    private static Interview__c createInterview(Id applicationId) {
        Interview__c interview = new Interview__c(
            Job_Application__c = applicationId,
            Start_Date_Time__c = System.now().addDays(1),
            Status__c = 'Scheduled'
        );
        insert interview;
        return interview;
    }

    private static Interviewer_Assignment__c createAssignment(Id interviewId, Id interviewerId) {
        Interviewer_Assignment__c assignment = new Interviewer_Assignment__c(
            Interview__c = interviewId,
            Interviewer__c = interviewerId
        );
        insert assignment;
        return assignment;
    }

    private static String getShareAccess(String objectName, Id recordId, Id userId) {
        String shareQuery = 'SELECT AccessLevel FROM ' + objectName + '__Share' +
            ' WHERE ParentId = :recordId AND UserOrGroupId = :userId AND RowCause = \'Recruiting_Access__c\' LIMIT 1';
        List<SObject> shares = Database.query(shareQuery);
        return shares.isEmpty() ? null : (String)shares[0].get('AccessLevel');
    }
}