import threading
from main import check_required_env_vars, update_certs, verify_cert, watch_acme_file

bind = "0.0.0.0:80"
workers = 1


def on_starting(server):
    check_required_env_vars()
    update_certs()
    verify_cert()
    watcher_thread = threading.Thread(target=watch_acme_file, daemon=True)
    watcher_thread.start()
