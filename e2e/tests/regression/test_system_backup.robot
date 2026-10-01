*** Settings ***
Documentation    System Backup Test Cases

Test Tags    regression    system_backup

Resource    ../keywords/variables.resource
Resource    ../keywords/common.resource
Resource    ../keywords/setting.resource
Resource    ../keywords/secret.resource
Resource    ../keywords/volume.resource
Resource    ../keywords/system_backup.resource
Resource    ../keywords/longhorn.resource
Resource    ../keywords/backup.resource

Test Setup    Set up test environment
Test Teardown    Cleanup test resources

*** Test Cases ***
Test System Backup And Restore
    [Tags]    coretest
    [Documentation]    Test system backup and restore
    Given Create volume 0 with    dataEngine=${DATA_ENGINE}
    And Attach volume 0
    And Wait for volume 0 healthy
    And Write data to volume 0
    And Create system backup 0
    And Detach volume 0
    And Wait for volume 0 detached
    And Delete volume 0
    And Wait for volume 0 deleted

    When Restore system backup 0

    Then Wait for volume 0 to be created
    And Wait for volume 0 restoration to complete
    And Attach volume 0
    And Wait for volume 0 healthy
    And Check volume 0 data is intact

Test Uninstallation With System Backup
    [Tags]    uninstall
    [Documentation]    Test uninstall Longhorn with system backup
    Given Create volume 0 with    dataEngine=${DATA_ENGINE}
    And Attach volume 0
    And Wait for volume 0 healthy
    And Write data 0 to volume 0

    And Create system backup 0

    When Setting deleting-confirmation-flag is set to true
    And Uninstall Longhorn
    And Check Longhorn CRD removed

    Then Install Longhorn

Test Create System Backup With DR Volume
    [Tags]    dr-volume
    [Documentation]    Test create system backup with DR volume
    ...                Issue: https://github.com/longhorn/longhorn/issues/10239
    Given Create volume 0 with    dataEngine=${DATA_ENGINE}
    And Attach volume 0
    And Wait for volume 0 healthy
    And Write data to volume 0
    And Create backup 0 for volume 0
    And Check snapshot for backup 0 of volume 0 exists

    When Create DR volume 1 from backup 0    dataEngine=${DATA_ENGINE}
    And Create system backup 0
    And Assert volume 1 remains attached for at least 60 seconds

Test System Restore Job Uses Registry Secret
    [Documentation]    Issue: https://github.com/longhorn/longhorn/issues/13968
    ...    Backport: https://github.com/longhorn/longhorn/issues/13969
    ...    Verify the SystemRestore rollout Job uses the configured registry-secret.
    [Tags]    registry-secret
    ${original_registry_secret} =    Given Get setting registry-secret value
    TRY
        And Create test registry secret test-registry-secret    ${original_registry_secret}
        And Setting registry-secret is set to test-registry-secret
        And Setting registry-secret should be test-registry-secret
        And Create system backup 0

        ${restore_name} =    When Start restoring system backup 0
        Then System restore ${restore_name} job should use registry secret test-registry-secret
        And Wait for system restore ${restore_name} completed
    FINALLY
        Setting registry-secret is set to ${original_registry_secret}
    END
