from secret import Secret


class secret_keywords:

    def __init__(self):
        self.secret = Secret()

    def create_secret(self):
        self.secret.create()

    def cleanup_secrets(self):
        self.secret.cleanup()

    def create_registry_secret(self, name, original_secret_name=""):
        self.secret.create_registry_secret(name, original_secret_name)
