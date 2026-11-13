trigger JobPostingTrigger on Job_Posting__c (after insert, after update) {
    Set<Id> jobPostingIds = new Set<Id>();
    for (Job_Posting__c posting : Trigger.new) {
        if (Trigger.isInsert) {
            jobPostingIds.add(posting.Id);
            continue;
        }
        Job_Posting__c oldPosting = Trigger.oldMap.get(posting.Id);
        if (posting.Recruiter__c != oldPosting.Recruiter__c ||
            posting.Hiring_Manager__c != oldPosting.Hiring_Manager__c) {
            jobPostingIds.add(posting.Id);
        }
    }
    if (!jobPostingIds.isEmpty()) {
        RecruitingSharingService.refresh(new Set<Id>(), jobPostingIds, new Set<Id>());
    }
}