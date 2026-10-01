from kubernetes import client
from kubernetes.client.rest import ApiException

import utility.constant as constant
from system_backup.base import Base
from system_backup.crd import CRD
from utility.utility import logging
from utility.utility import get_longhorn_client
from utility.utility import get_retry_count_and_interval
from utility.utility import generate_name_random
import time

class Rest(Base):

    def __init__(self):
        self.retry_count, self.retry_interval = get_retry_count_and_interval()

    def create(self, backup_name, backup_policy):
        logging(f"Creating system backup {backup_name}")
        get_longhorn_client().create_system_backup(Name=backup_name, VolumeBackupPolicy=backup_policy)
        ready = False
        for i in range(self.retry_count):
            logging(f"Waiting for system backup {backup_name} to be ready ... ({i})")
            try:
                system_backup = get_longhorn_client().by_id_system_backup(backup_name)
                if system_backup.state == "Ready":
                    ready = True
                    break
            except Exception as e:
                logging(f"Waiting for system backup {backup_name} to be ready failed: {e}")
            time.sleep(self.retry_interval)
        assert ready, f"Waiting for system backup {backup_name} to be ready failed: {system_backup}"

    def restore(self, backup_name):
        restore_name = self.start_restore(backup_name)
        self.wait_for_system_restore_completed(restore_name)

    def start_restore(self, backup_name):
        restore_name = generate_name_random("system-restore-")
        logging(f"Creating system restore {restore_name} from system backup {backup_name}")
        get_longhorn_client().create_system_restore(Name=restore_name, SystemBackup=backup_name)
        return restore_name

    def wait_for_system_restore_completed(self, restore_name):
        system_restore = None
        completed = False
        for i in range(self.retry_count):
            logging(f"Waiting for system restore {restore_name} to be completed ... ({i})")
            try:
                system_restore = get_longhorn_client().by_id_system_restore(restore_name)
                if system_restore.state == "Completed":
                    completed = True
                    break
            except Exception as e:
                logging(f"Waiting for system restore {restore_name} to be completed failed: {e}")
            time.sleep(self.retry_interval)
        assert completed, f"Waiting for system restore {restore_name} to be completed failed: {system_restore}"

    def check_system_restore_job_registry_secret(self, restore_name, secret_name):
        job_name = f"longhorn-system-rollout-{restore_name}"
        api = client.BatchV1Api()
        for i in range(self.retry_count):
            logging(f"Waiting for system restore job {job_name} ... ({i})")
            try:
                job = api.read_namespaced_job(
                    name=job_name, namespace=constant.LONGHORN_NAMESPACE)
            except ApiException as e:
                if e.status != 404:
                    raise
                time.sleep(self.retry_interval)
                continue
            secrets = [secret.name for secret in
                       (job.spec.template.spec.image_pull_secrets or [])]
            assert secret_name in secrets, (
                f"System restore job {job_name} imagePullSecrets {secrets} "
                f"does not contain {secret_name}")
            return
        assert False, f"Timed out waiting for system restore job {job_name}"

    def delete_system_backup(self, backup_name):
        logging(f"Deleting system backup {backup_name}")
        system_backups = get_longhorn_client().list_system_backup()
        for system_backup in system_backups:
            if system_backup['name'] == backup_name:
                try:
                    get_longhorn_client().delete(system_backup)
                except Exception as e:
                    logging(f"Deleting system backup {system_backup['name']} failed: {e}")

        for i in range(self.retry_count):
            logging(f"Waiting for system backup {backup_name} to be deleted ... ({i})")
            system_backups = get_longhorn_client().list_system_backup()
            if backup_name in [s['name'] for s in system_backups]:
                time.sleep(self.retry_interval)
                continue
            return

        assert False, f"Deleting system backup {backup_name} failed: {system_backups}"

    def wait_for_system_backup_ready(self, backup_name):
        return CRD().wait_for_system_backup_ready(backup_name)

    def cleanup_system_backups(self):
        system_backups = get_longhorn_client().list_system_backup()
        for system_backup in system_backups:
            logging(f"Deleting system backup {system_backup['name']}")
            try:
                get_longhorn_client().delete(system_backup)
            except Exception as e:
                logging(f"Deleting system backup {system_backup['name']} failed: {e}")

        deleted = False
        for i in range(self.retry_count):
            system_backups = get_longhorn_client().list_system_backup()
            if len(system_backups) == 0:
                deleted = True
                break
            time.sleep(self.retry_interval)
        assert deleted, f"Cleaning up system backups failed: {system_backups}"

    def cleanup_system_restores(self):
        system_restores = get_longhorn_client().list_system_restore()
        for system_restore in system_restores:
            logging(f"Deleting system restore {system_restore['name']}")
            try:
                get_longhorn_client().delete(system_restore)
            except Exception as e:
                logging(f"Deleting system restore {system_restore['name']} failed: {e}")

        deleted = False
        for i in range(self.retry_count):
            system_restores = get_longhorn_client().list_system_restore()
            if len(system_restores) == 0:
                deleted = True
                break
            time.sleep(self.retry_interval)
        assert deleted, f"Cleaning up system restores failed: {system_restores}"
