*** Settings ***
Documentation    System Backup Keywords

Library    ../libs/keywords/common_keywords.py
Library    ../libs/keywords/system_backup_keywords.py

*** Keywords ***
Create system backup ${system_backup_id}
    ${backup_name} =    generate_name_with_suffix    system-backup    ${system_backup_id}
    create_system_backup    ${backup_name}

Restore system backup ${system_backup_id}
    ${backup_name} =    generate_name_with_suffix    system-backup    ${system_backup_id}
    create_system_restore    ${backup_name}

Start restoring system backup ${system_backup_id}
    ${backup_name} =    generate_name_with_suffix    system-backup    ${system_backup_id}
    ${restore_name} =    start_system_restore    ${backup_name}
    RETURN    ${restore_name}

Wait for system restore ${restore_name} completed
    wait_for_system_restore_completed    ${restore_name}

Delete system backup ${system_backup_id}
    ${backup_name} =    generate_name_with_suffix    system-backup    ${system_backup_id}
    delete_system_backup    ${backup_name}

Wait for system backup ${system_backup_name} ready
    wait_for_system_backup_ready    ${system_backup_name}

System restore ${restore_name} job should use registry secret ${secret_name}
    check_system_restore_job_registry_secret    ${restore_name}    ${secret_name}
