trigger InterviewTrigger on Interview__c (after insert, after update, after delete, after undelete) {
    Set<Id> applicationIds = new Set<Id>();

    if (Trigger.isDelete) {
        for (Interview__c interview : Trigger.old) {
            applicationIds.add(interview.Job_Application__c);
        }
    } else if (Trigger.isUpdate) {
        for (Interview__c interview : Trigger.new) {
            Interview__c oldInterview = Trigger.oldMap.get(interview.Id);
            if (interview.Job_Application__c != oldInterview.Job_Application__c) {
                applicationIds.add(oldInterview.Job_Application__c);
                applicationIds.add(interview.Job_Application__c);
            }
        }
    } else {
        for (Interview__c interview : Trigger.new) {
            applicationIds.add(interview.Job_Application__c);
        }
    }

    if (!applicationIds.isEmpty()) {
        RecruitingSharingService.refresh(applicationIds, new Set<Id>(), new Set<Id>());
    }
}