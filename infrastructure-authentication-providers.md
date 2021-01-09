# Authentication Providers with AD

<!-- TOC -->

- [Authentication Providers with AD](#authentication-providers-with-ad)
    - [Prerequisites](#prerequisites)
    - [OpenShift RBAC with AD](#openshift-rbac-with-ad)
        - [Background: LDAP Structure](#background-ldap-structure)
            - [Examine the OAuth configuration](#examine-the-oauth-configuration)
            - [Syncing LDAP Groups to OpenShift Groups](#syncing-ldap-groups-to-openshift-groups)
            - [Change Group Policy](#change-group-policy)
            - [Examine cluster-admin policy](#examine-cluster-admin-policy)
            - [Examine cluster-reader policy](#examine-cluster-reader-policy)
            - [Create Projects for Collaboration](#create-projects-for-collaboration)
            - [Map Groups to Projects](#map-groups-to-projects)
            - [Examine Group Access](#examine-group-access)
            - [Prometheus](#prometheus)

<!-- /TOC -->

## Prerequisites
- Microsoft AD (with LDAP protocol)
- Users and Groups
- Assigned Roles

## OpenShift RBAC with AD

Configuring External Authentication Providers

OpenShift supports a number of different authentication providers, and you can
find the complete list in the [understanding identity provider configuration](https://docs.openshift.com/container-platform/4.6/authentication/understanding-identity-provider.html). One of the most commonly used authentication
providers is LDAP, whether provided by Microsoft Active Directory or by other
sources.

OpenShift can perform user authentication against an LDAP server, and can also
configure group membership and certain RBAC attributes based on LDAP group
membership.

### Background: LDAP Structure

In this environment we are providing LDAP with the following user groups:

* `ocp-user`: Users with OpenShift access
  * Any users who should be able to log-in to OpenShift must be members of this
group
  * All of the below mentioned users are in this group
* `ocp-normal-dev`: Normal OpenShift users
  * Regular users of OpenShift without special permissions
  * Contains: `normaluser1`, `teamuser1`, `teamuser2`
* `ocp-fancy-dev`: Fancy OpenShift users
  * Users of OpenShift that are granted some special privileges
  * Contains: `fancyuser1`, `fancyuser2`
* `ocp-teamed-app`: Teamed app users
  * A group of users that will have access to the same OpenShift *Project*
  * Contains: `teamuser1`, `teamuser2`

#### Examine the OAuth configuration
Since this is a pure, vanilla OpenShift 4 installation, it has the default OAuth resource. You can examine that OAuth configuration with the following:

```bash
oc get oauth cluster -o yaml
```

You will see something like:

```YAML
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  annotations:
    release.openshift.io/create-only: "true"
  creationTimestamp: "2020-03-17T18:12:52Z"
  generation: 1
  name: cluster
  resourceVersion: "1563"
  selfLink: /apis/config.openshift.io/v1/oauths/cluster
  uid: ebb0582d-b0e4-4c40-a33f-12459593f8e2
spec: {}
```

There are a few things to note here. Firstly, there's basically nothing here!
How does the `kubeadmin` user work, then? The OpenShift OAuth system knows to
look for a `kubeadmin` *Secret* in the `kube-system` *Namespace*. You can
examine it with the following:

```bash
oc get secret -n kube-system kubeadmin -o yaml
```

You will see something like:

```YAML
apiVersion: v1
data:
  kubeadmin: JDJhJDEwJDdQNHZtbXMxdmpDa3FsNlJMLjJBcC5BSWdBazB6d09IWUdXZEdrRXBERGRwWXNmVVcxanpX
kind: Secret
metadata:
  creationTimestamp: "2019-04-29T17:30:51Z"
  name: kubeadmin
  namespace: kube-system
  resourceVersion: "2065"
  selfLink: /api/v1/namespaces/kube-system/secrets/kubeadmin
  uid: 892945dc-6aa4-11e9-9959-02774c6d6b2e
type: Opaque
```

That *Secret* contains the encoded hash of the `kubeadmin` password. This
account will continue to work even after we configure a new `OAuth`. If you
want to disable it, you would need to delete the secret.

In a real-world environment, you will likely want to integrate with your
existing identity management solution. For this lab we are configuring LDAP
as our `identityProvider`. Here's an example of the OAuth configuration. Look
for the element in `identityProviders` with `type: LDAP` like the following:

```bash
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: ldap
    challenge: false
    login: true
    mappingMethod: claim
    type: LDAP
    ldap:
      attributes:
        id:
        - distinguishedName
        email:
        - userPrincipalName
        name:
        - givenName
        preferredUsername:
        - sAMAccountName
      bindDN: "cn=ldapuser,cn=Users,dc=dcloud,dc=cisco,dc=com"
      bindPassword:
        name: ldapuser-secret
      insecure: true
      url: "ldap://ad1.dcloud.cisco.com:389/cn=Users,dc=dcloud,dc=cisco,dc=com?sAMAccountName?sub?(memberOf=cn=ocp-user,cn=Users,dc=dcloud,dc=cisco,dc=com)"
  tokenConfig:
    accessTokenMaxAgeSeconds: 86400
```

Some notable fields under `identityProviders:`:

1. `name`: The unique ID of the identity provider. It is possible to have
multiple authentication providers in an OpenShift environment, and OpenShift is
able to distinguish between them.

2. `mappingMethod: claim`: This section has to do with how usernames are
assigned within an OpenShift cluster when multiple providers are configured. See
the [Identity provider parameters](https://docs.openshift.com/container-platform/4.6/authentication/understanding-identity-provider.html#identity-provider-parameters-understanding-identity-provider) section for more information.

3. `attributes`: This section defines the LDAP fields to iterate over and
assign to the fields in the OpenShift user's "account". If any attributes are
not found / not populated when searching through the list, the entire
authentication fails. In this case we are creating an identity that is
associated with the AD `distinguishedName`, an email address from the LDAP `userPrincipalName`, a name from
the LDAP `givenName`, and a username from the AD `sAMAccountName`.

4. `bindDN`: When searching LDAP, bind to the server as this user.

5. `bindPassword`: Reference to the Secret that has the password to use when binding for searching.

6. `url`: Identifies the LDAP server and the search to perform.

For more information on the specific details of LDAP authentication in
OpenShift you can refer to the
[Configuring an LDAP identity provider](https://docs.openshift.com/container-platform/4.6/authentication/identity_providers/configuring-ldap-identity-provider.html) documentation.

To setup the LDAP identity provider we must:

1. Create a `Secret` with the bind password.
2. Update the `cluster` `OAuth` object with the LDAP identity provider.

As the `kubeadmin` user apply the OAuth configuration with `oc`.

```yaml
oc create secret generic ldapuser-secret --from-literal=bindPassword=b1ndP^ssword -n openshift-config

cat <<EOF | oc apply -f -
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: ldap
    challenge: false
    login: true
    mappingMethod: claim
    type: LDAP
    ldap:
      attributes:
        id:
        - distinguishedName
        email:
        - userPrincipalName
        name:
        - givenName
        preferredUsername:
        - sAMAccountName
      bindDN: "cn=ldapuser,cn=Users,dc=dcloud,dc=cisco,dc=com"
      bindPassword:
        name: ldapuser-secret
      insecure: true
      url: "ldap://ad1.dcloud.cisco.com:389/cn=Users,dc=dcloud,dc=cisco,dc=com?sAMAccountName?sub?(memberOf=cn=ocp-user,cn=Users,dc=dcloud,dc=cisco,dc=com)"
  tokenConfig:
    accessTokenMaxAgeSeconds: 86400
EOF
```

#### Syncing LDAP Groups to OpenShift Groups
In OpenShift, groups can be used to manage users and control permissions for
multiple users at once. There is a section in the documentation on how to
[sync groups with LDAP](https://docs.openshift.com/container-platform/3.11/install_config/syncing_groups_with_ldap.html). Syncing groups involves running a program called `groupsync`
when logged into OpenShift as a user with `cluster-admin` privileges, and using
a configuration file that tells OpenShift what to do with the users it finds in
the various groups.

We have provided a `groupsync` configuration file for you:

View configuration file
```yaml
kind: LDAPSyncConfig
apiVersion: v1
url: ldap://ad1.dcloud.cisco.com:389
insecure: true
bindDN: cn=ldapuser,cn=Users,dc=dcloud,dc=cisco,dc=com
bindPassword: b1ndP^ssword
rfc2307:
  groupsQuery:
    baseDN: cn=Users,dc=dcloud,dc=cisco,dc=com
    derefAliases: never
    filter: (cn=ocp-*)
    scope: sub
    pageSize: 0
  groupUIDAttribute: distinguishedName
  groupNameAttributes:
  - cn
  groupMembershipAttributes:
  - member
  usersQuery:
    baseDN: cn=Users,dc=dcloud,dc=cisco,dc=com
    derefAliases: never
    filter: (objectclass=user)
    scope: sub
    pageSize: 0
  userUIDAttribute: distinguishedName
  userNameAttributes:
  - sAMAccountName
```

Without going into too much detail (you can look at the documentation), the
`groupsync` config file does the following:

* searches LDAP using the specified bind user and password
* queries for any LDAP groups whocp name begins with `ocp-`
* creates OpenShift groups with a name from the `cn` of the LDAP group
* finds the members of the LDAP group and then puts them into the created
  OpenShift group
* uses the `dn` and `uid` as the UID and name attributes, respectively, in
  OpenShift

Execute the `groupsync`:

```yaml
cat <<EOF > groupsync.yaml
kind: LDAPSyncConfig
apiVersion: v1
url: ldap://ad1.dcloud.cisco.com:389
insecure: true
bindDN: cn=ldapuser,cn=Users,dc=dcloud,dc=cisco,dc=com
bindPassword: b1ndP^ssword
rfc2307:
  groupsQuery:
    baseDN: cn=Users,dc=dcloud,dc=cisco,dc=com
    derefAliases: never
    filter: (cn=ocp-*)
    scope: sub
    pageSize: 0
  groupUIDAttribute: distinguishedName
  groupNameAttributes:
  - cn
  groupMembershipAttributes:
  - member
  usersQuery:
    baseDN: cn=Users,dc=dcloud,dc=cisco,dc=com
    derefAliases: never
    filter: (objectclass=user)
    scope: sub
    pageSize: 0
  userUIDAttribute: distinguishedName
  userNameAttributes:
  - sAMAccountName
EOF
oc adm groups sync --sync-config=./groupsync.yaml --confirm
```

You will see output like the following:

```bash
group/ocp-fancy-dev
group/ocp-user
group/ocp-normal-dev
group/ocp-teamed-app
```

What you are seeing is the *Group* objects that have been created by the
`groupsync` command. If you are curious about the `--confirm` flag, check the
output of the help with `oc adm groups sync -h`.

If you want to see the *Groups* that were created, execute the following:

```bash
oc get groups
```

You will see output like the following:

```bash
NAME             USERS
ocp-admin        ldapuser
ocp-fancy-dev    fancyuser1, fancyuser2
ocp-normal-dev   normaluser1, teamuser1, teamuser2
ocp-teamed-app   teamuser1, teamuser2
ocp-user         fancyuser1, fancyuser2, normaluser1, teamuser1, teamuser2
```

Take a look at a specific group in YAML:

```bash
oc get group ocp-fancy-dev -o yaml
```

The YAML looks like:

```yaml
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  annotations:
    openshift.io/ldap.sync-time: 2020-03-11T10:57:03-0400
    openshift.io/ldap.uid: cn=ocp-fancy-dev,ou=Users,o=5e615ba46b812e7da02e93b5,dc=jumpcloud,dc=com
    openshift.io/ldap.url: ldap.jumpcloud.com:636
  creationTimestamp: "2020-03-11T14:57:03Z"
  labels:
    openshift.io/ldap.host: ldap.jumpcloud.com
  name: ocp-fancy-dev
  resourceVersion: "48481"
  selfLink: /apis/user.openshift.io/v1/groups/ocp-fancy-dev
  uid: 630a9d2b-b577-46bd-8294-6b26e7f9a6e1
users:
- fancyuser1
- fancyuser2
```

OpenShift has automatically associated some LDAP metadata with the *Group*, and
has listed the users who are in the group.

What happens if you list the *Users*?

```bash
oc get user
```

You will get:

```bash
No resources found.
```

Why would there be no *Users* found? They are clearly listed in the *Group*
definition.

*Users* are not actually created until the first time they try to log in. What
you are seeing in the *Group* definition is simply a placeholder telling
OpenShift that, if it encounters a *User* with that specific ID, that it should
be associated with the *Group*.

#### Change Group Policy
We will grant a cluster role `cluster-admin` to ldap group `ocp-admin`

Change the policy for the `ocp-admin` *Group*:

```bash
oc adm policy add-cluster-role-to-group cluster-admin ocp-admin
```

In your environment, there is a special group of super developers called
_ocp-fancy-dev_ who should have special `cluster-reader` privileges. This is a role
that allows a user to view administrative-level information about the cluster.
For example, they can see the list of all *Projects* in the cluster.

Change the policy for the `ocp-fancy-dev` *Group*:

```bash
oc adm policy add-cluster-role-to-group cluster-reader ocp-fancy-dev
```


**Note:** If you are interested in the different roles that come with OpenShift, you can
learn more about them in the
[role-based access control (RBAC)](https://docs.openshift.com/container-platform/4.6/authentication/using-rbac.html) documentation.

#### Examine `cluster-admin` policy
login as a `ldapuser`
```bash
oc login -u ldapuser -p b1ndP^ssword
```

Then, try to list *Projects*:

```bash
oc get projects
```

You will see a full list of projects.

#### Examine `cluster-reader` policy
Go ahead and login as a regular user:

```bash
oc login -u normaluser1 -p openshift
```

Then, try to list *Projects*:

```bash
oc get projects
```

You will see:

```bash
No resources found.
```

Now, login as a member of `ocp-fancy-dev`:

```bash
oc login -u fancyuser1 -p openshift
```

And then perform the same `oc get projects` and you will now see the list of all
of the projects in the cluster:

```bash
NAME                                                    DISPLAY NAME                        STATUS
    app-management
  * default
    kube-public
    kube-system
    labguide
    openshift
    openshift-apiserver
...
```

You should now be starting to understand how RBAC in OpenShift Container
Platform can work.

#### Create Projects for Collaboration
Make sure you login as the cluster administrator:

```bash
oc login -u ldapuser
```

Then, create several *Projects* for people to collaborate:

```bash
oc adm new-project app-dev --display-name="Application Development"
oc adm new-project app-test --display-name="Application Testing"
oc adm new-project app-prod --display-name="Application Production"
```

You have now created several *Projects* that represent a typical Software
Development Lifecycle setup. Next, you will configure *Groups* to grant
collaborative access to these projects.


**Note:** Creating projects with `oc adm new-project` does *not* use the project request
process or the project request template. These projects will not have quotas or
limitranges applied by default. A cluster administrator can "impersonate" other
users, so there are several options if you wanted these projects to get
quotas/limit ranges:

. use `--as` to specify impersonating a regular user with `oc new-project`
. use `oc process` and provide values for the project request template, piping
  into create (eg: `oc process ... | oc create -f -`). This will create all of
  the objects in the project request template, which would include the quota and
  limit range.
. manually create/define the quota and limit ranges after creating the projects.

For these exercises it is not important to have quotas or limit ranges on these
projects.

#### Map Groups to Projects
As you saw earlier, there are several roles within OpenShift that are
preconfigured. When it comes to *Projects*, you similarly can grant view, edit,
or administrative access. Let's give our `ocp-teamed-app` users access to edit the
development and testing projects:

```bash
oc adm policy add-role-to-group edit ocp-teamed-app -n app-dev
oc adm policy add-role-to-group edit ocp-teamed-app -n app-test
```

And then give them access to view production:

```bash
oc adm policy add-role-to-group view ocp-teamed-app -n app-prod
```

Now, give the `ocp-fancy-dev` group edit access to the production project:

```bash
oc adm policy add-role-to-group edit ocp-fancy-dev -n app-prod
```

#### Examine Group Access
Log in as `normaluser1` and see what *Projects* you can see:

```bash
oc login -u normaluser1 -p openshift
oc get projects
```

You should get:

```bash
No resources found.
```

Then, try `teamuser1` from the `ocp-teamed-app` group:

```bash
oc login -u teamuser1 -p openshift
oc get projects
```

You should get:

```bash
NAME       DISPLAY NAME              STATUS
app-dev    Application Development   Active
app-prod   Application Production    Active
app-test   Application Testing       Active
```

You did not grant the team users edit access to the production project. Go ahead
and try to create something in the production project as `teamuser1`:

```bash
oc project app-prod
oc new-app docker.io/siamaksade/mapit
```

You will see that it will not work:

```bash
error: can't lookup images: imagestreamimports.image.openshift.io is forbidden: User "teamuser1" cannot create resource "imagestreamimports" in API group "image.openshift.io" in the namespace "app-prod"
error:  local file access failed with: stat docker.io/siamaksade/mapit: no such file or directory
error: unable to locate any images in image streams, templates loaded in accessible projects, template files, local docker images with name "docker.io/siamaksade/mapit"

Argument 'docker.io/siamaksade/mapit' was classified as an image, image~source, or loaded template reference.

The 'oc new-app' command will match arguments to the following types:

  1. Images tagged into image streams in the current project or the 'openshift' project
     - if you don't specify a tag, we'll add ':latest'
  2. Images in the Docker Hub, on remote registries, or on the local Docker engine
  3. Templates in the current project or the 'openshift' project
  4. Git repository URLs or local paths that point to Git repositories

--allow-missing-images can be used to point to an image that does not exist yet.

See 'oc new-app -h' for examples.
```

This failure is exactly what we wanted to see.

#### Prometheus
Now that you have a user with `cluster-reader` privileges (one that can see
many administrative aspects of the cluster), we can revisit Prometheus and
attempt to log-in to it.

Login as a the user with `cluster-reader` privileges:

```bash
oc login -u fancyuser1 -p openshift
```

Find the `prometheus` `Route` with the following command:

```bash
oc get route prometheus-k8s -n openshift-monitoring
```

You will see something like the following:

```bash
NAME             HOST/PORT                                                                      PATH   SERVICES         PORT   TERMINATION          WILDCARD
prometheus-k8s   prometheus-k8s-openshift-monitoring.{{ ROUTE_SUBDOMAIN }}          prometheus-k8s   web    reencrypt/Redirect   None
```

**Warning:** Before continuing, make sure to go to the OpenShift web console and log out
by using the dropdown menu at the upper right where it says `kube:admin`.
Otherwise Prometheus will try to use your `kubeadmin` user to pass through
authentication. While it will work, it doesn't demonstrate the
`cluster-reader` role.

The installer configured a `Route` for Prometheus by default. Go ahead and
control+click the [Prometheus link](https://prometheus-k8s-openshift-monitoring.apps.ocp01.example.com) to open it in your browser. You'll be
greeted with a login screen. Click the *Log in with OpenShift* button, then
select the `ldap` auth mechanism, and use the `fancyuser1` user that you gave
`cluster-reader` privileges to earlier. More specifically, the
`ocp-fancy-dev` group has `cluster-reader` permissions, and `fancyuser1` is a
member. Remember that the password for all of these users is `openshift`. You
will probably get a certificate error because of the self-signed certificate.
Make sure to accept it.

After logging in, the first time you will be presented with an auth proxy
permissions acknowledgement.

There is actually an OAuth proxy that sits in the flow between you and the
Prometheus container. This proxy is used to validate your AuthenticatioN
(AuthN) as well as authorize (AuthZ) what is allowed to happen. Here you are
explicitly authorizing the permissions from your `fancyuser1` account to be
used as part of accessing Prometheus. Hit _Allow selected permissions_.

At this point you are viewing Prometheus. There are no alerts configured. If
you look at `Status` and then `Targets` you can see some interesting
information about the current state of the cluster.
