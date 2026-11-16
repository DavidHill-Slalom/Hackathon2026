trigger InterviewerAssignmentTrigger on Interviewer_Assignment__c (after insert, after update, after delete, after undelete) {
    Set<Id> interviewIds = new Set<Id>();

    if (Trigger.isDelete) {
        for (Interviewer_Assignment__c assignment : Trigger.old) {
            interviewIds.add(assignment.Interview__c);
        }
    } else if (Trigger.isUpdate) {
        for (Interviewer_Assignment__c assignment : Trigger.new) {
            Interviewer_Assignment__c oldAssignment = Trigger.oldMap.get(assignment.Id);
            if (assignment.Interview__c != oldAssignment.Interview__c ||
                assignment.Interviewer__c != oldAssignment.Interviewer__c) {
                interviewIds.add(oldAssignment.Interview__c);
                interviewIds.add(assignment.Interview__c);
            }
        }
    } else {
        for (Interviewer_Assignment__c assignment : Trigger.new) {
            interviewIds.add(assignment.Interview__c);
        }
    }

    if (!interviewIds.isEmpty()) {
        RecruitingSharingService.refreshForInterviews(interviewIds);
    }
}