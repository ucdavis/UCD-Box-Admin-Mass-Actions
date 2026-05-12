<#
    Script: box-admin-mass-actions.ps1
    Authors: Justin Earley and Dean Bunn
#>

#Var for Mass Action
$global:MassAction = "Empty-Groups-Membership";

#Custom Object for Box App Information
$global:BoxAppInfo = new-object PSObject -Property (@{ client_id=""; client_secret=""; subject_id="";});

#Custom Object for Box Token Information
$global:BoxAPITokenInfo = new-object PSObject -Property (@{ box_api_token=""; expires_in_ticks=0;});

#Retrieve App Secret Information
$BoxAppInfo.client_id = Get-Secret -Name "Box-ClientID" -AsPlainText -Vault UCD-Identities;
$BoxAppInfo.client_secret = Get-Secret -Name "Box-ClientSecret" -AsPlainText -Vault UCD-Identities;
$BoxAppInfo.subject_id = Get-Secret -Name "Box-SubjectID" -AsPlainText -Vault UCD-Identities;

#Function for Initializing and Updating Box API Token
function Get-BoxAPIToken()
{

    #Check to See if a New Token Needs to Requested
    if([Int64](Get-Date).AddMinutes(15).Ticks -gt $BoxAPITokenInfo.expires_in_ticks)
    {

        #Var for Base Box OAuth URL
        [string]$box_oauth2_url = "https://api.box.com/oauth2/token";

        #Custom Dictionary for Box Required Items
        $boxRequest = @{client_id = "";
                        client_secret = "";
                        grant_type = "client_credentials";
                        box_subject_type = "enterprise";
                        box_subject_id = "";};

        #Load Secrets for API Call
        $boxRequest.client_id = $BoxAppInfo.client_id;
        $boxRequest.client_secret = $BoxAppInfo.client_secret;
        $boxRequest.box_subject_id = $BoxAppInfo.subject_id;

        #Var for Headers Used in API Call 
        $headers = @{"Content-Type"="application/x-www-form-urlencoded"};

        #API Call to Box OAuth2 URL
        $rtnTokenInfo = Invoke-RestMethod -Uri $box_oauth2_url -Method Post -Headers $headers -Body $boxRequest;

        #Null\Empty Check on Returned API Token
        if([string]::IsNullOrEmpty($rtnTokenInfo.access_token) -eq $false)
        {
            $BoxAPITokenInfo.box_api_token = $rtnTokenInfo.access_token;
            $BoxAPITokenInfo.expires_in_ticks = (Get-Date).AddSeconds($rtnTokenInfo.expires_in).Ticks;
        }
        else 
        {

            #Stop the Script Due to API Token Not Being Returned
            Write-Output "Script stopped due to no API token returned";
            exit;

        }#End of Access Token Null\Empty Checks

    }#End of Expires Checks
   
}#End of Get-BoxAPIToken Function

#Var for Box API Base URL
[string]$boxAPIBaseURL = "https://api.box.com/2.0/";

#Var for Progress Indicator
$nProgress = 0;

#################################################
# Mass Group Membership Adds
#################################################

if($MassAction -eq "Add-Memberships")
{
    #Var for Membership URL
    $boxMembershipURL = $boxAPIBaseURL + "group_memberships";

    #Import Membership Assignments CSV
    $csvMembershipAssignments = Import-CSV -Path "testing_memberships.csv";

    #Loop Through Each Membership Assignment
    foreach($boxMbrRqst in $csvMembershipAssignments)
    {

        #Get\Check OAuth API Access Token from Box
        Get-BoxAPIToken;

        #Var for Header Authorization Bearer Key to Box
        $headersBox = @{"Authorization"="Bearer " + $BoxAPITokenInfo.box_api_token};

        #Var for Custom Post Body
        $cstPostBody = [PSCustomObject]@{ 
                                          user = [PSCustomObject]@{ id = ""}
                                          group = [PSCustomObject]@{ id = ""}
                                        }

        #Assign Values to Custom Post Body
        $cstPostBody.user.id = $boxMbrRqst."box-user-id";
        $cstPostBody.group.id = $boxMbrRqst."box-group-id";
        
        #Convert Post Body to Json Object
        $jsonPostBody = $cstPostBody | ConvertTo-Json -Compress;

        #Make Post API call to Add Group Membership
        Invoke-RestMethod -Uri $boxMembershipURL -Method Post -Headers $headersBox -Body $jsonPostBody -ContentType "application/json";


    }#End of $csvMembershipAssignments Foreach

}#End of Add-Memberships Mass Action


#################################################
# Mass Student Group Membership Adds
#################################################

if($MassAction -eq "Add-Student-Group-Memberships")
{

    #Var for Membership URL
    $boxMembershipURL = $boxAPIBaseURL + "group_memberships";

    #Hash Table for UCD Enterprise Box Users 
    $htUEBU = @{};

    #Array of Non-Enterprise Box Accounts
    $arrNonEnterpriseBoxAcnts = @();

    #Import UCD Box Users CSV
    $csvUCDBoxUsrs = Import-CSV -Path "box_users_20260509.csv";

    #Import Student Registration 
    $csvUCDRegistration = Import-CSV -Path "box_group_ids_all_students.csv";

    #Var for Report Name
    [string]$rptName = "Non_Enterprise_Accounts_" + (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss") + ".csv"; 

    #Load Box User HashTable
    foreach($ubu in $csvUCDBoxUsrs)
    {

        if([string]::IsNullOrEmpty($ubu.Box_Login) -eq $false -and [string]::IsNullOrEmpty($ubu.Box_ID) -eq $false -and $htUEBU.ContainsKey($ubu.Box_Login.ToLower()) -eq $false)
        {
            $htUEBU.Add($ubu.Box_Login.ToLower(),$ubu.Box_ID)
        }

    }#End of Box User HashTable Load


    foreach($ucdReg in $csvUCDRegistration)
    {

        #Null Empty Checks on Required Values
        if([string]::IsNullOrEmpty($ucdReg.email) -eq $false -and [string]::IsNullOrEmpty($ucdReg.boxgroupid) -eq $false)
        {
            
            if($htUEBU.ContainsKey($ucdReg.email.ToString().ToLower()) -eq $true)
            {

                #Get\Check OAuth API Access Token from Box
                Get-BoxAPIToken;

                #Var for Header Authorization Bearer Key to Box
                $headersBox = @{"Authorization"="Bearer " + $BoxAPITokenInfo.box_api_token};

                $bxUsrID = $htUEBU[$ucdReg.email.ToString().ToLower()].ToString();
                $bxGrpID = $ucdReg.boxgroupid.ToString();
                $jsonPostBody = "{""user"":{""id"":""$bxUsrID""},""group"":{""id"":""$bxGrpID""}}";

                #Make Post API call to Add Group Membership
                Invoke-RestMethod -Uri $boxMembershipURL -Method Post -Headers $headersBox -Body $jsonPostBody -ContentType "application/json";
    
            }
            else
            {
                $arrNonEnterpriseBoxAcnts += $ucdReg
            }

        }#End of Null\Empty Checks on Required Membership Creation Values

    }#End of $csvUCDRegistration Foreach

    #Export Reporting Array to CSV
    $arrNonEnterpriseBoxAcnts | Export-Csv -Path $rptName -NoTypeInformation;

}#End of Add-Student-Group-Memberships


##################################################
# Mass Empty Group Membership
##################################################

if($MassAction -eq "Empty-Groups-Membership")
{
    
    #Import Group CSV
    $csvBoxGrps = Import-CSV -Path "testing_groups.csv";

    #Var for Box Limit
    [int]$nBoxLimit = 100;

    #Loop Through All the Groups
    foreach($boxGrp in $csvBoxGrps)
    {

        #Var for Box Offset
        [int]$nBoxOffSet = 0;

        #Var for Get More Memberships from Box
        $bGetMore = $true;

        #Array for Membership IDs
        $arrMbrShpIDs = @();

        #Do\While Loop to Pull Full Group Membership
        do
        {

            #Get\Check OAuth API Access Token from Box
            Get-BoxAPIToken;

            #Var for Header Authorization Bearer Key to Box
            $headersBox = @{"Authorization"="Bearer " + $BoxAPITokenInfo.box_api_token};

            #Var for Dynamic Groups Membership URL
            $boxGrpMbrspURL = $boxAPIBaseURL + "groups/" + $boxGrp.id + "/memberships?offset=" + $nBoxOffSet.ToString() + "&limit=" + $nBoxLimit.ToString();
        
            $boxGrpMbrspRslts = Invoke-RestMethod -Uri $boxGrpMbrspURL -Method Get -Headers $headersBox;

            if($boxGrpMbrspRslts.total_count -gt 0 -and $null -ne $boxGrpMbrspRslts.entries)
            {
                #Loop Through Membership Results
                foreach($bgmrEntry in $boxGrpMbrspRslts.entries)
                {
                    $arrMbrShpIDs += $bgmrEntry.id.ToString();
                }

                #Increment Offset
                $nBoxOffSet += $boxGrpMbrspRslts.limit;

                #Check Offset to Total Count
                if($nBoxOffSet -ge $boxGrpMbrspRslts.total_count)
                {
                    $bGetMore = $false;
                }

            }
            else
            {

                $bGetMore = $false;

            }#End of $boxGrpMbrspRslts Checks
            
        }
        while($bGetMore -eq $true)

        #Loop Through Each Group Membership ID
        foreach($mbrShpID in $arrMbrShpIDs)
        {

            #Get\Check OAuth API Access Token from Box
            Get-BoxAPIToken;

            #Var for Header Authorization Bearer Key to Box
            $headersBox = @{"Authorization"="Bearer " + $BoxAPITokenInfo.box_api_token};

            #Var for Group Membership Deletion URL
            $boxGrpMbrspDltURL = $boxAPIBaseURL + "group_memberships/" + $mbrShpID.ToString();

            #Make Deletion Request
            $boxMbrDltRslts = Invoke-RestMethod -Uri $boxGrpMbrspDltURL -Method Delete -Headers $headersBox;
            
        }#End of $arrMbrShpIDs Foreach

    }#End of $csvBoxGrps Foreach

}


#################################################
# Mass Group Creation
#################################################

if($MassAction -eq "Add-Groups")
{

    #Import Unique UCD Group CSV
    $csvUCDGroups = Import-CSV -Path "testing_groups.csv";

    #Var for Groups URL
    $boxGroupsURL = $boxAPIBaseURL + "groups";

    #Loop Through Each Group Listing and Create the Group
    foreach($ucdGrp in $csvUCDGroups)
    {

        #Increment Progress Indicator
        $nProgress++;

        #Display Progress
        Write-Output $nProgress;

        #Var for Existing Group with Same Name
        $bExistingGrp = $false;

        #Get\Check OAuth API Access Token from Box
        Get-BoxAPIToken;

        #Var for Header Authorization Bearer Key to Box
        $headersBox = @{"Authorization"="Bearer " + $BoxAPITokenInfo.box_api_token};

        #Var for Group Query URL by Group Name
        $grpQueryURL = $boxAPIBaseURL + "groups?filter_term=" + $ucdGrp.name;

        #Query Box API for Group by Name
        $grpQueryResult = Invoke-RestMethod -Uri $grpQueryURL -Method Get -Headers $headersBox;

        #Check Returned Query Result Count Check
        if($grpQueryResult.total_count -gt 0)
        {
            #Loop Through Query Results Looking for Exis Group Name
            foreach($grpQryRslt in $grpQueryResult.entries)
            {

                #Existing Group Name
                if($grpQryRslt.name.ToString().ToLower() -eq $ucdGrp.name.ToString().ToLower())
                {
                    $bExistingGrp = $true;
                }

            }#End of Group Query Results Foreach

        }#End of Group Query Results Count Check

        #Create the New Unique Group
        if($bExistingGrp -eq $false)
        {
            #Var for Custom Post Body
            $cstPostBody = [PSCustomObject]@{ 
                                                name    = ""
                                            }

            #Load Post Body
            $cstPostBody.name = $ucdGrp.name.ToString().Trim();
            
            #Convert Post Body to Json Object
            $jsonPostBody = $cstPostBody | ConvertTo-Json -Compress;

            #Make Post API call to Create Box Group
            Invoke-RestMethod -Uri $boxGroupsURL -Method Post -Headers $headersBox -Body $jsonPostBody -ContentType "application/json";

        }#End of $bMakeGrp Check

    }#End of $csvUCDGroups Foreach

}#End of Add-Groups Action

#################################################
# Mass User Creation
#################################################

if($MassAction -eq "Add-Users")
{

    #Import Unique UCD User CSV
    $csvUCDUsrs = Import-CSV -Path "testing_users.csv";

    foreach($ucdUsr in $csvUCDUsrs)
    {
        #Increment Progress Indicator
        $nProgress++;

        #Display Progress
        Write-Output $nProgress;
        
        #Var for User Query URL by Email Address
        $usrQueryURL = $boxAPIBaseURL + "users?filter_term=" + $ucdUsr.email;

        #Var for Users URL
        $boxUsersURL = $boxAPIBaseURL + "users";

        #Get\Check OAuth API Access Token from Box
        Get-BoxAPIToken;

        #Var for Header Authorization Bearer Key to Box
        $headersBox = @{"Authorization"="Bearer " + $BoxAPITokenInfo.box_api_token};

        #Query Box API for User by Email Address
        $usrQueryResult = Invoke-RestMethod -Uri $usrQueryURL -Method Get -Headers $headersBox;

        #Check Returned Query Result Count Check
        if($usrQueryResult.total_count -eq 0)
        {   

            #Var for Custom Post Body
            $cstPostBody = [PSCustomObject]@{ 
                                            name    = ""
                                            login   = ""
                                            space_amount = -1
                                            }

            #Create That User
            $cstPostBody.name = $ucdUsr.name;
            $cstPostBody.login = $ucdUsr.email;

            #Convert Post Body to Json Object
            $jsonPostBody = $cstPostBody | ConvertTo-Json -Compress;

            #Make Post API call to Create Box User
            Invoke-RestMethod -Uri $boxUsersURL -Method Post -Headers $headersBox -Body $jsonPostBody -ContentType "application/json";

        }#End of User Query Results Count Check

    }#End of $csvUCDUsrs Foreach

}






