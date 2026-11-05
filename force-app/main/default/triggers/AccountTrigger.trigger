trigger AccountTrigger on Account (before insert) {
    for (Account acc : Trigger.new) {
        if (String.isBlank(acc.Name)) {
            acc.addError('Account Name is required.');
        }
    }
}
