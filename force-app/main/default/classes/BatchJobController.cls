/**
 * Created by peterfriberg on 2025-03-06.
 */

public with sharing class BatchJobController {

    @AuraEnabled
    public static String startInvoiceImportBatchJob(Integer daysBack) {
        return PpcInvoiceImporterBatch.run(daysBack);
    }

    public static AsyncApexJob getAsyncApexJob(String jobId) {
        List<AsyncApexJob> jobs = new List<AsyncApexJob>([
            SELECT
                ApexClass.Name,
                JobType,
                Status,
                CreatedDate,
                CompletedDate,
                JobItemsProcessed,
                TotalJobItems,
                LastProcessed,
                LastProcessedOffset,
                NumberOfErrors,
                ParentJobId,
                Id
            FROM AsyncApexJob
            WHERE Id = :jobId
        ]);
        return jobs.isEmpty() ? null : jobs[0];
    }

    public static List<AsyncApexJob> getAsyncApexJobs() {
        return new List<AsyncApexJob>([
            SELECT
                ApexClass.Name,
                JobType,
                Status,
                CreatedDate,
                CompletedDate,
                JobItemsProcessed,
                TotalJobItems,
                LastProcessed,
                LastProcessedOffset,
                NumberOfErrors,
                ParentJobId,
                Id
            FROM AsyncApexJob
            WHERE JobType IN ('BatchApex','BatchApexWorker')
            AND CreatedDate = LAST_N_DAYS:2
            AND ApexClass.Name = 'PpcInvoiceImporterBatch'
            ORDER BY CreatedDate DESC
        ]);
    }

    @AuraEnabled
    public static List<ApexJob> getApexJobs() {
        List<AsyncApexJob> jobs = getAsyncApexJobs();
        Map<Id, ApexJob> jobMap = new Map<Id, ApexJob>();
        List<ApexJob> jobList = new List<ApexJob>();

        for (AsyncApexJob job : jobs) {
            ApexJob jobWrapper = new ApexJob();
            jobWrapper.ApexClassName = job.ApexClass.Name;
            jobWrapper.JobType = job.JobType;
            jobWrapper.Status = job.Status;
            jobWrapper.CreatedDate = job.CreatedDate;
            jobWrapper.CompletedDate = job.CompletedDate;
            jobWrapper.JobItemsProcessed = job.JobItemsProcessed;
            jobWrapper.TotalJobItems = job.TotalJobItems;
            jobWrapper.LastProcessed = job.LastProcessed;
            jobWrapper.LastProcessedOffset = job.LastProcessedOffset;
            jobWrapper.NumberOfErrors = job.NumberOfErrors;
            jobWrapper.JobId = job.Id;
            jobWrapper.JobId = jobWrapper.JobId?.left(15);
            jobMap.put(job.Id, jobWrapper);
        }

        for (AsyncApexJob job : jobs) {
            if (job.ParentJobId != null) {
                ApexJob parentJob = jobMap.get(job.ParentJobId);
                parentJob.ChildJobs.add(jobMap.get(job.Id));
            } else {
                jobList.add(jobMap.get(job.Id));
            }
        }

        return jobList;
    }

    public class ApexJob {
        @AuraEnabled public String ApexClassName;
        @AuraEnabled public String JobType;
        @AuraEnabled public String Status;
        @AuraEnabled public Datetime CreatedDate;
        @AuraEnabled public Datetime CompletedDate;
        @AuraEnabled public Integer JobItemsProcessed;
        @AuraEnabled public Integer TotalJobItems;
        @AuraEnabled public String LastProcessed;
        @AuraEnabled public Integer LastProcessedOffset;
        @AuraEnabled public Integer NumberOfErrors;
        @AuraEnabled public String JobId;
        @AuraEnabled public List<ApexJob> ChildJobs;

        public ApexJob() {
            this.ChildJobs = new List<ApexJob>();
        }
    }
}