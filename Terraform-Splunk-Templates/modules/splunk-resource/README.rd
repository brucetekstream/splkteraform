This module creates the following components:

1. Lanch Template with the details for snapshot (see Snapshot Selection below) and instance type to be used 
2. ASG of 1
3. ALB
4. ALB Listeners TLS ones associated with ACM certificate passed as a variable
5. ALB Targets to the ASG 
6. Route 53 Record on the public hosted zone associated with the ALB
7. Security groups to be used for the instance and the ALB

The hostname is used for the name of the snapshots and template so they can be differenciated in the lambda functions

Snapshot selection:
***After creation the snapshot policy creates new snapshots of the root volume on the instance and tags it with a name that can be queried by TF or the Lambda function that updates the templates
1. We get the snapshot associated with the ami
2. TF creates a copy of the snapshot and gives it a tag name so it can be queried.  this copy is used to have an initial snapshot before the policy creates new ones and it is configured to ignore changes so no new snapshots are created after the initial one, conflicting with the template query which neeeds to have the lastest snapshot as the one from the policy.
3. TF queries the snapshots with the name of the one copied in step 2, and the name associated with the snapshot policy, then retrieves the ID of the most recent one
4. The template picks up the snapshot ID retrieved in step 3 and sets it for instance creation, it sets the tag so it can be picked from the snapshot policy
**** Lambda function regulary queries the snapshots using the tag added in the template and used for the policy and updates the template with the latest one

Search heads:
Single Root volume for both OS and Splunk installation
Regular snapshots taken 
Launch template updated either by Terraform or Lambda for new instances