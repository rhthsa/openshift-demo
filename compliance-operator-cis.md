# OpenShift CIS Compliance with Compliance Operator

- [OpenShift CIS Compliance with Compliance Operator](#openshift-cis-compliance-with-compliance-operator)
  - [Prerequisites](#prerequisites)
  - [CIS Compliance](#cis-compliance)
  - [Compliance Operator](#compliance-operator)

## Prerequisites
- OpenShift 4.6 or 4.7
- Cluster-admin user access

## CIS Compliance



## Compliance Operator

After install Compliance Operator from Operator
<!-- - Create Compliance Operator source and subscription -->
- **[Optional]** Verify Compliance Operator
  - Check compliance profile
    
    ```bash
    oc get profiles.compliance -n openshift-compliance
    ```

    Sample output

    ```bash
    NAME              AGE
    ocp4-cis          4h52m
    ocp4-cis-node     4h52m
    ocp4-e8           4h52m
    ocp4-moderate     4h52m
    rhcos4-e8         4h52m
    rhcos4-moderate   4h52m
    ```
  - Check detail of profile
    
    ```bash
    oc get -o yaml profiles.compliance ocp4-cis  -n openshift-compliance
    ```

   Sample output

   ```yaml
   ...
   rules:
    - ocp4-accounts-restrict-service-account-tokens
    - ocp4-accounts-unique-service-account
    - ocp4-api-server-admission-control-plugin-alwaysadmit
    - ocp4-api-server-admission-control-plugin-alwayspullimages
    - ocp4-api-server-admission-control-plugin-namespacelifecycle
    - ocp4-api-server-admission-control-plugin-noderestriction
   ...
   ```
  - Check details of rule
    
    ```bash
    oc get -o yaml rules.compliance ocp4-accounts-unique-service-account  -n openshift-compliance
    ```
- Define scan settings
  
  ```bash
  oc get scansettings default -o yaml -n openshift-compliance 
  ```

- Run scan
  - Create ScanSettingBinding 
  ```yaml
  apiVersion: compliance.openshift.io/v1alpha1
  kind: ScanSettingBinding
  metadata:
    name: sample-compliance-requirements
  profiles:
    - name: rhcos4-moderate
      kind: Profile
      apiGroup: compliance.openshift.io/v1alpha1
    - name: ocp4-cis
      kind: Profile
      apiGroup: compliance.openshift.io/v1alpha1
  settingsRef:
    name: default
    kind: ScanSetting
    apiGroup: compliance.openshift.io/v1alpha1
  ```
  - Check compliance suites created by scan.
  ```bash
  oc get compliancesuites -n openshift-compliance 
  ```
  
  Sample output
  ```bash
  NAME       PHASE     RESULT
  xyz-scan   RUNNING   NOT-AVAILABLE
  ```

  - Check complaince scan
  ```bash
  oc get compliancescans -n openshift-compliance 
  ```

   Sample output
  ```bash
  NAME       PHASE     RESULT
  ocp4-cis   RUNNING   NOT-AVAILABLE
  ```

  - Check pods
  ```bash
  oc get pods -n openshift-compliance
  ```
- Check result
  - Compliance result
  ```bash
  oc get ComplianceCheckResult -n openshift-compliance
  ```
  - Remidiation
  ```bash
  oc get ComplianceRemediation -n openshift-compliance
  ```