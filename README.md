## Box Admin Mass Actions

### Resource Links

- [Create Box Group](https://developer.box.com/reference/post-groups)
- [List Box Enterprise Users](https://developer.box.com/reference/get-users)
- [Create Box User](https://developer.box.com/reference/post-users)
- [Add Box User to Group](https://developer.box.com/reference/post-group-memberships)

---


### Collaboration Contingency Plan

1. Using one of Box admin accounts, create a Box app with the following settings:
    - ***App Type***: Client Credentials Grant
    - ***App Access Level***: App + Enterprise Access
    - ***Application Scopes***: Managed User and Groups
1. Under the App Details section, get the ***client ID***, ***client secret***, and ***enterprise ID*** values
1. Get course and registered student information from SIS team
1. Create groups based information listed in CSV file. Remember, to add term code suffix to group names
1. Pull current Box users listing from admin console
1. Create Box accounts for required users that don't already have an account
1. Pull another listing of current Box users and create CSV file of Box group and user IDs for membership requests
1. Submit group membership adds

