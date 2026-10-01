*** Settings ***
Documentation    Secret Keywords

Library    Collections
Library    ../libs/keywords/common_keywords.py
Library    ../libs/keywords/secret_keywords.py

*** Keywords ***
Create crypto secret
    create_secret

Create test registry secret ${secret_name}
    [Arguments]    ${original_secret_name}=${EMPTY}
    create_registry_secret    ${secret_name}    ${original_secret_name}
