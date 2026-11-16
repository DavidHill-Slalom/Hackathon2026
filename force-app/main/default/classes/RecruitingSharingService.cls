/**
 * @description Reconciles private recruiting record shares from posting assignments and interview invitations.
 * @author Slalom
 */
public without sharing class RecruitingSharingService {
    private static final String SHARE_REASON = 'Recruiting_Access__c';

    /**
     * @description Rebuilds shares for applications and related records affected by assignment changes.
     * @param applicationIds Applications whose access may have changed.
     * @param jobPostingIds Job postings whose assigned users may have changed.
     * @param candidateIds Candidates whose application access may have changed.
     */
    public static void refresh(Set<Id> applicationIds, Set<Id> jobPostingIds, Set<Id> candidateIds) {
        Set<Id> affectedApplicationIds = copyIds(applicationIds);
        Set<Id> targetJobPostingIds = copyIds(jobPostingIds);
        Set<Id> targetCandidateIds = copyIds(candidateIds);
        Map<Id, Job_Application__c> contextApplications = new Map<Id, Job_Application__c>();
        if (!affectedApplicationIds.isEmpty() || !targetJobPostingIds.isEmpty() || !targetCandidateIds.isEmpty()) {
            for (Job_Application__c application : [
                SELECT Id, Candidate__c, Job_Posting__c,
                    Job_Posting__r.Recruiter__c, Job_Posting__r.Hiring_Manager__c
                FROM Job_Application__c
                WHERE Id IN :affectedApplicationIds
                    OR Job_Posting__c IN :targetJobPostingIds
                    OR Candidate__c IN :targetCandidateIds
            ]) {
                contextApplications.put(application.Id, application);
            }
        }
        affectedApplicationIds.addAll(contextApplications.keySet());
        Set<Id> contextApplicationIds = new Set<Id>(contextApplications.keySet());
        for (Job_Application__c application : contextApplications.values()) {
            targetCandidateIds.add(application.Candidate__c);
            targetJobPostingIds.add(application.Job_Posting__c);
        }

        Map<Id, Job_Posting__c> jobPostings = new Map<Id, Job_Posting__c>();
        if (!targetJobPostingIds.isEmpty()) {
            jobPostings = new Map<Id, Job_Posting__c>([
                SELECT Id, OwnerId, Recruiter__c, Hiring_Manager__c
                FROM Job_Posting__c
                WHERE Id IN :targetJobPostingIds
            ]);
        }

        Map<Id, List<Interview__c>> interviewsByApplication = new Map<Id, List<Interview__c>>();
        Map<Id, Id> applicationByInterview = new Map<Id, Id>();
        Set<Id> contextInterviewIds = new Set<Id>();
        if (!contextApplicationIds.isEmpty()) {
            for (Interview__c interview : [
                SELECT Id, Job_Application__c
                FROM Interview__c
                WHERE Job_Application__c IN :contextApplicationIds
            ]) {
                contextInterviewIds.add(interview.Id);
                applicationByInterview.put(interview.Id, interview.Job_Application__c);
                addToListMap(interviewsByApplication, interview.Job_Application__c, interview);
            }
        }

        Map<Id, List<Interviewer_Assignment__c>> assignmentsByApplication = new Map<Id, List<Interviewer_Assignment__c>>();
        Map<Id, Set<Id>> interviewersByApplication = new Map<Id, Set<Id>>();
        Set<Id> affectedInterviewIds = new Set<Id>();
        Set<Id> affectedAssignmentIds = new Set<Id>();
        if (!contextInterviewIds.isEmpty()) {
            for (Interviewer_Assignment__c assignment : [
                SELECT Id, Interview__c, Interviewer__c
                FROM Interviewer_Assignment__c
                WHERE Interview__c IN :contextInterviewIds
            ]) {
                Id applicationId = applicationByInterview.get(assignment.Interview__c);
                if (applicationId == null) {
                    continue;
                }
                addToListMap(assignmentsByApplication, applicationId, assignment);
                addToSetMap(interviewersByApplication, applicationId, assignment.Interviewer__c);
                if (affectedApplicationIds.contains(applicationId)) {
                    affectedAssignmentIds.add(assignment.Id);
                }
            }
        }
        for (Id applicationId : affectedApplicationIds) {
            if (interviewsByApplication.containsKey(applicationId)) {
                for (Interview__c interview : interviewsByApplication.get(applicationId)) {
                    affectedInterviewIds.add(interview.Id);
                }
            }
        }

        Map<Id, Map<Id, String>> jobPostingAccess = new Map<Id, Map<Id, String>>();
        Map<Id, Map<Id, String>> candidateAccess = new Map<Id, Map<Id, String>>();
        Map<Id, Map<Id, String>> applicationAccess = new Map<Id, Map<Id, String>>();
        Map<Id, Map<Id, String>> interviewAccess = new Map<Id, Map<Id, String>>();
        Map<Id, Map<Id, String>> assignmentAccess = new Map<Id, Map<Id, String>>();
        initializeAccess(jobPostingAccess, targetJobPostingIds);
        initializeAccess(candidateAccess, targetCandidateIds);
        initializeAccess(applicationAccess, affectedApplicationIds);
        initializeAccess(interviewAccess, affectedInterviewIds);
        initializeAccess(assignmentAccess, affectedAssignmentIds);

        for (Job_Posting__c posting : jobPostings.values()) {
            addRecordAccess(jobPostingAccess, posting.Id, posting.Recruiter__c, 'Edit');
            addRecordAccess(jobPostingAccess, posting.Id, posting.Hiring_Manager__c, 'Read');
        }

        for (Job_Application__c application : contextApplications.values()) {
            Map<Id, String> applicationUsers = new Map<Id, String>();
            addApplicationTeamAccess(applicationUsers, application);
            addInterviewers(applicationUsers, interviewersByApplication.get(application.Id), 'Read');

            if (targetCandidateIds.contains(application.Candidate__c)) {
                addRecordAccess(candidateAccess, application.Candidate__c, applicationUsers);
            }
            if (targetJobPostingIds.contains(application.Job_Posting__c)) {
                addRecordAccess(jobPostingAccess, application.Job_Posting__c, applicationUsers);
            }
            if (!affectedApplicationIds.contains(application.Id)) {
                continue;
            }

            addRecordAccess(applicationAccess, application.Id, applicationUsers);
            if (interviewsByApplication.containsKey(application.Id)) {
                for (Interview__c interview : interviewsByApplication.get(application.Id)) {
                    addRecordAccess(interviewAccess, interview.Id, applicationUsers);
                }
            }
            if (assignmentsByApplication.containsKey(application.Id)) {
                for (Interviewer_Assignment__c assignment : assignmentsByApplication.get(application.Id)) {
                    addRecordAccess(assignmentAccess, assignment.Id, applicationUsers);
                    addRecordAccess(assignmentAccess, assignment.Id, assignment.Interviewer__c, 'Edit');
                }
            }
        }

        syncShares('Job_Posting__c', targetJobPostingIds, jobPostingAccess);
        syncShares('Candidate__c', targetCandidateIds, candidateAccess);
        syncShares('Job_Application__c', affectedApplicationIds, applicationAccess);
        syncShares('Interview__c', affectedInterviewIds, interviewAccess);
        syncShares('Interviewer_Assignment__c', affectedAssignmentIds, assignmentAccess);
    }

    /**
     * @description Rebuilds sharing for applications associated with changed interviews.
     * @param interviewIds Interviews whose participants may have changed.
     */
    public static void refreshForInterviews(Set<Id> interviewIds) {
        Set<Id> applicationIds = new Set<Id>();
        Set<Id> safeInterviewIds = copyIds(interviewIds);
        if (!safeInterviewIds.isEmpty()) {
            for (Interview__c interview : [
                SELECT Job_Application__c
                FROM Interview__c
                WHERE Id IN :safeInterviewIds
            ]) {
                applicationIds.add(interview.Job_Application__c);
            }
        }
        refresh(applicationIds, new Set<Id>(), new Set<Id>());
    }

    private static Set<Id> copyIds(Set<Id> ids) {
        return ids == null ? new Set<Id>() : new Set<Id>(ids);
    }

    private static void addApplicationTeamAccess(Map<Id, String> accessByUser, Job_Application__c application) {
        if (application.Job_Posting__r != null) {
            addAccess(accessByUser, application.Job_Posting__r.Recruiter__c, 'Edit');
            addAccess(accessByUser, application.Job_Posting__r.Hiring_Manager__c, 'Read');
        }
    }

    private static void addInterviewers(Map<Id, String> accessByUser, Set<Id> interviewerIds, String accessLevel) {
        if (interviewerIds == null) {
            return;
        }
        for (Id interviewerId : interviewerIds) {
            addAccess(accessByUser, interviewerId, accessLevel);
        }
    }

    private static void addAccess(Map<Id, String> accessByUser, Id userId, String accessLevel) {
        if (userId == null) {
            return;
        }
        if (!accessByUser.containsKey(userId) || accessLevel == 'Edit') {
            accessByUser.put(userId, accessLevel);
        }
    }

    private static void addRecordAccess(
        Map<Id, Map<Id, String>> accessByRecord,
        Id recordId,
        Id userId,
        String accessLevel
    ) {
        if (recordId == null || userId == null) {
            return;
        }
        if (!accessByRecord.containsKey(recordId)) {
            accessByRecord.put(recordId, new Map<Id, String>());
        }
        addAccess(accessByRecord.get(recordId), userId, accessLevel);
    }

    private static void addRecordAccess(
        Map<Id, Map<Id, String>> accessByRecord,
        Id recordId,
        Map<Id, String> accessByUser
    ) {
        if (recordId == null || accessByUser == null) {
            return;
        }
        for (Id userId : accessByUser.keySet()) {
            addRecordAccess(accessByRecord, recordId, userId, accessByUser.get(userId));
        }
    }

    private static void initializeAccess(Map<Id, Map<Id, String>> accessByRecord, Set<Id> recordIds) {
        for (Id recordId : recordIds) {
            accessByRecord.put(recordId, new Map<Id, String>());
        }
    }

    private static void addToListMap(Map<Id, List<Interview__c>> recordsByApplication, Id applicationId, Interview__c interview) {
        if (!recordsByApplication.containsKey(applicationId)) {
            recordsByApplication.put(applicationId, new List<Interview__c>());
        }
        recordsByApplication.get(applicationId).add(interview);
    }

    private static void addToListMap(
        Map<Id, List<Interviewer_Assignment__c>> recordsByApplication,
        Id applicationId,
        Interviewer_Assignment__c assignment
    ) {
        if (!recordsByApplication.containsKey(applicationId)) {
            recordsByApplication.put(applicationId, new List<Interviewer_Assignment__c>());
        }
        recordsByApplication.get(applicationId).add(assignment);
    }

    private static void addToSetMap(Map<Id, Set<Id>> valuesByApplication, Id applicationId, Id userId) {
        if (userId == null) {
            return;
        }
        if (!valuesByApplication.containsKey(applicationId)) {
            valuesByApplication.put(applicationId, new Set<Id>());
        }
        valuesByApplication.get(applicationId).add(userId);
    }

    private static void syncShares(
        String objectApiName,
        Set<Id> recordIds,
        Map<Id, Map<Id, String>> desiredAccess
    ) {
        if (recordIds.isEmpty()) {
            return;
        }
        for (Id recordId : recordIds) {
            if (!desiredAccess.containsKey(recordId)) {
                desiredAccess.put(recordId, new Map<Id, String>());
            }
        }

        Map<Id, Id> ownerByRecord = new Map<Id, Id>();
        String ownerQuery = 'SELECT Id, OwnerId FROM ' + objectApiName + ' WHERE Id IN :recordIds';
        for (SObject record : Database.query(ownerQuery)) {
            ownerByRecord.put((Id)record.get('Id'), (Id)record.get('OwnerId'));
        }

        String shareObjectName = objectApiName.substring(0, objectApiName.length() - 3) + '__Share';
        String shareQuery = 'SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause FROM ' + shareObjectName +
            ' WHERE ParentId IN :recordIds AND RowCause = \'' + SHARE_REASON + '\'';
        Map<String, SObject> existingByKey = new Map<String, SObject>();
        for (SObject shareRecord : Database.query(shareQuery)) {
            existingByKey.put(shareKey((Id)shareRecord.get('ParentId'), (Id)shareRecord.get('UserOrGroupId')), shareRecord);
        }

        Schema.SObjectType shareType = Schema.getGlobalDescribe().get(shareObjectName);
        if (shareType == null) {
            throw new IllegalArgumentException('Missing share object ' + shareObjectName);
        }
        List<SObject> sharesToInsert = new List<SObject>();
        List<SObject> sharesToUpdate = new List<SObject>();
        for (Id recordId : recordIds) {
            for (Id userId : desiredAccess.get(recordId).keySet()) {
                if (ownerByRecord.get(recordId) == userId) {
                    continue;
                }
                String key = shareKey(recordId, userId);
                String desiredLevel = desiredAccess.get(recordId).get(userId);
                SObject existingShare = existingByKey.remove(key);
                if (existingShare == null) {
                    SObject newShare = shareType.newSObject();
                    newShare.put('ParentId', recordId);
                    newShare.put('UserOrGroupId', userId);
                    newShare.put('AccessLevel', desiredLevel);
                    newShare.put('RowCause', SHARE_REASON);
                    sharesToInsert.add(newShare);
                } else if ((String)existingShare.get('AccessLevel') != desiredLevel) {
                    existingShare.put('AccessLevel', desiredLevel);
                    sharesToUpdate.add(existingShare);
                }
            }
        }

        List<SObject> sharesToDelete = existingByKey.values();
        if (!sharesToDelete.isEmpty()) {
            delete sharesToDelete;
        }
        if (!sharesToUpdate.isEmpty()) {
            update sharesToUpdate;
        }
        if (!sharesToInsert.isEmpty()) {
            insert sharesToInsert;
        }
    }

    private static String shareKey(Id recordId, Id userId) {
        return String.valueOf(recordId) + ':' + String.valueOf(userId);
    }
}