public with sharing class AmplitudeHelper {
    
    @AuraEnabled(cacheable=true)
    public static map<Id,orgWrapper> getAllOrg(Id accId){
        try {
            // yearly dates
            Date startDate = Date.today();
            Date endDate = Date.today().addYears(-1);
            // Querying all org s under the account
            list<Amplitude_Org__c> orgs = [SELECT Id, Name, 
                                                    (SELECT Id,Metric_Type__c,Metric_Value__c,Period_Start_Date__c,Period_End_Date__c 
                                                    FROM Amplitude_Org_Metrics__r
                                                    WHERE Period_Start_Date__c <= :startDate
                                                    AND Period_End_Date__c > :endDate
                                                    AND Metric_Type__c != null 
                                                    AND Metric_Value__c != null)
                                            FROM Amplitude_Org__c 
                                            WHERE Account__c =:accId];

            map<id,orgWrapper> dataMap = new map<Id,orgWrapper>();
            // creating toatal user map under an org using aggregrate query
            map<Id, Integer> totalUserMapByOrg = new map<Id, Integer>();
            list<AggregateResult> orgUserCount = [
                SELECT count(Id)users, Amplitude_Org__c
                FROM Amplitude_Org_Permission__c
                WHERE Amplitude_Org__c In :orgs
                Group By Amplitude_Org__c
            ];
            // filling user count map
            for(AggregateResult ar : orgUserCount){
                totalUserMapByOrg.put((Id)ar.get('Amplitude_Org__c'), (Integer) ar.get('users'));
            }

            // building org wrapper
            for(Amplitude_Org__c org : orgs){
                orgWrapper wrapper = new orgWrapper();
                wrapper.org = new  Amplitude_Org__c(Id=org.Id,Name=org.Name);
                wrapper.totalUsers = totalUserMapByOrg.containsKey(org.Id) ? totalUserMapByOrg.get(org.Id) : 0;

                // aggregating metrics by type for org
                if(org.Amplitude_Org_Metrics__r != null && !org.Amplitude_Org_Metrics__r.isEmpty()){
                    map<String,Integer> metrics = new map<String,Integer>();
                    for(Amplitude_Org_Metrics__c met : org.Amplitude_Org_Metrics__r){
                        Integer val = metrics.containsKey(met.Metric_Type__c) ? metrics.get(met.Metric_Type__c) + met.Metric_Value__c.intValue() : met.Metric_Value__c.intValue();
                        metrics.put(met.Metric_Type__c, val);
                    }
                    wrapper.metrics = metrics;
                }
                // putting org wrapper into data map
                dataMap.put(org.Id, wrapper);
            }
            return dataMap;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // wrapper class
    public class orgWrapper {
        @AuraEnabled
        public Amplitude_Org__c org;

        @AuraEnabled
        public map<String,Integer> metrics;//Metric Type
  
        @AuraEnabled
        public Integer totalUsers;//Amplitude login object
    
}
