trigger JobApplicationTrigger on Job_Application__c (after insert, after update, after delete, after undelete) {
    Set<Id> applicationIds = new Set<Id>();
    Set<Id> jobPostingIds = new Set<Id>();
    Set<Id> candidateIds = new Set<Id>();

    if (Trigger.isDelete) {
        for (Job_Application__c application : Trigger.old) {
            applicationIds.add(application.Id);
            jobPostingIds.add(application.Job_Posting__c);
            candidateIds.add(application.Candidate__c);
        }
    } else if (Trigger.isUpdate) {
        for (Job_Application__c application : Trigger.new) {
            Job_Application__c oldApplication = Trigger.oldMap.get(application.Id);
            if (application.Job_Posting__c != oldApplication.Job_Posting__c ||
                application.Candidate__c != oldApplication.Candidate__c) {
                applicationIds.add(application.Id);
                jobPostingIds.add(oldApplication.Job_Posting__c);
                jobPostingIds.add(application.Job_Posting__c);
                candidateIds.add(oldApplication.Candidate__c);
                candidateIds.add(application.Candidate__c);
            }
        }
    } else {
        for (Job_Application__c application : Trigger.new) {
            applicationIds.add(application.Id);
            jobPostingIds.add(application.Job_Posting__c);
            candidateIds.add(application.Candidate__c);
        }
    }

    if (!applicationIds.isEmpty()) {
        RecruitingSharingService.refresh(applicationIds, jobPostingIds, candidateIds);
    }
}